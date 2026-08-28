#pragma once

#include "original_gpjson.cuh"

#include <cuda_runtime.h>

#include <algorithm>
#include <cstddef>
#include <cstdint>

constexpr uint8_t GP_HIERARCHY_PREDICT_ESCAPE = 0u;
constexpr uint8_t GP_HIERARCHY_PREDICT_STRING = 1u;
constexpr int GP_HIERARCHY_WORD_BLOCK = 256;
constexpr int GP_HIERARCHY_RECOVERY_BLOCK = 256;

struct GpHierarchyOriginalBuffers {
    uint64_t* raw_structural = nullptr;
    uint8_t* escape_carry = nullptr;
    uint8_t* quote_parity_or_prefix = nullptr;
    uint8_t* escape_changes_quote = nullptr;
    uint32_t* recovery_segments = nullptr;
    uint32_t* recovery_count = nullptr;
    uint8_t* xor_bases = nullptr;
};

struct GpHierarchyWordBuffers {
    uint64_t* raw_structural = nullptr;
    uint8_t* escape_carry = nullptr;
    uint8_t* quote_parity_or_prefix = nullptr;
    uint8_t* escape_changes_quote = nullptr;
    uint32_t* recovery_words = nullptr;
    uint32_t* recovery_count = nullptr;
    uint8_t* xor_bases = nullptr;
};

struct GpHierarchyCoalescedWord {
    uint64_t predicted_quotes = 0ull;
    uint64_t raw_structural = 0ull;
    uint64_t first_non_slash_quote = 0ull;
    uint8_t outgoing_escape = 0u;
    uint8_t quote_parity = 0u;
    uint8_t all_slashes = 1u;
};

__host__ __device__ __forceinline__ std::size_t gpHierarchyWordCount(
    std::size_t input_size) {
    return (input_size + GP4_WORD_BYTES - 1u) / GP4_WORD_BYTES;
}

inline std::size_t gpHierarchyOriginalAlignedBytes(std::size_t input_size) {
    if (input_size == 0u) return GP4_WORD_BYTES;
    const std::size_t bytes_per_thread =
        (input_size + GP4_ORIGINAL_THREADS - 1u) / GP4_ORIGINAL_THREADS;
    return ((bytes_per_thread + GP4_WORD_BYTES - 1u) / GP4_WORD_BYTES) * GP4_WORD_BYTES;
}

inline std::size_t gpHierarchyOriginalActiveSegments(std::size_t input_size) {
    if (input_size == 0u) return 0u;
    const std::size_t aligned_bytes = gpHierarchyOriginalAlignedBytes(input_size);
    return (input_size + aligned_bytes - 1u) / aligned_bytes;
}

inline std::size_t gpHierarchyPaddedScanCount(std::size_t count) {
    if (count == 0u) return 0u;
    return ((count + GP4_SCAN_THREADS - 1u) / GP4_SCAN_THREADS) * GP4_SCAN_THREADS;
}

// F1 reads every byte exactly once. During that single pass it constructs the
// raw structural bitmap, filters escaped quotes for E=0, and computes the I=1
// candidate. The first non-backslash byte tells validation whether E=1 can
// actually change a quote; an E-state mismatch alone is not a recovery miss.
__device__ __forceinline__ void gpHierarchySpeculateRange(
    const uint8_t* input, std::size_t input_size, std::size_t byte_start,
    std::size_t byte_end, uint64_t* raw_structural, uint64_t* structural_out,
    uint8_t& outgoing_escape, uint8_t& quote_parity,
    uint8_t& escape_changes_quote) {
    uint8_t escape = GP_HIERARCHY_PREDICT_ESCAPE;
    uint8_t string_state = GP_HIERARCHY_PREDICT_STRING;
    bool before_first_non_slash = true;
    quote_parity = 0u;
    escape_changes_quote = 0u;

    const std::size_t first_word = byte_start >> 6u;
    std::size_t final_word = (byte_end + GP4_WORD_BYTES - 1u) >> 6u;
    const std::size_t word_count = gpHierarchyWordCount(input_size);
    if (final_word > word_count) final_word = word_count;

    for (std::size_t word_id = first_word; word_id < final_word; ++word_id) {
        const std::size_t word_start = word_id << 6u;
        const std::size_t word_end = min(word_start + GP4_WORD_BYTES, input_size);
        uint64_t raw_word = 0ull;
        uint64_t real_quotes = 0ull;

        for (std::size_t position = word_start; position < word_end; ++position) {
            const uint8_t value = input[position];
            const uint32_t bit_id = static_cast<uint32_t>(position & 63u);
            const uint64_t bit = 1ull << bit_id;

            if (gp4IsStructural(value)) raw_word |= bit;
            if (value == '"' && escape == 0u) real_quotes |= bit;
            if (before_first_non_slash && value != '\\') {
                escape_changes_quote = value == '"' ? 1u : 0u;
                before_first_non_slash = false;
            }
            escape = value == '\\' ? static_cast<uint8_t>(escape ^ 1u) : 0u;
        }

        const uint8_t word_quote_parity = static_cast<uint8_t>(__popcll(real_quotes) & 1u);
        uint64_t in_string = gp4PrefixXor64(real_quotes);
        if (string_state != 0u) in_string = ~in_string;
        raw_structural[word_id] = raw_word;
        structural_out[word_id] = raw_word & ~in_string;
        quote_parity ^= word_quote_parity;
        string_state ^= word_quote_parity;
    }
    outgoing_escape = escape;
}

// Sparse recovery rereads only a queued miss. It never rebuilds raw structural
// bits: those were cached by F1 and are also needed by the final algebraic I
// correction. The candidate still assumes incoming I=1.
__device__ __forceinline__ uint8_t gpHierarchyRecoverRange(
    const uint8_t* input, std::size_t input_size, std::size_t byte_start,
    std::size_t byte_end, const uint64_t* raw_structural,
    uint64_t* structural_out) {
    uint8_t escape = 1u;
    uint8_t string_state = GP_HIERARCHY_PREDICT_STRING;
    uint8_t quote_parity = 0u;
    const std::size_t first_word = byte_start >> 6u;
    std::size_t final_word = (byte_end + GP4_WORD_BYTES - 1u) >> 6u;
    const std::size_t word_count = gpHierarchyWordCount(input_size);
    if (final_word > word_count) final_word = word_count;

    for (std::size_t word_id = first_word; word_id < final_word; ++word_id) {
        const std::size_t word_start = word_id << 6u;
        const std::size_t word_end = min(word_start + GP4_WORD_BYTES, input_size);
        uint64_t real_quotes = 0ull;
        for (std::size_t position = word_start; position < word_end; ++position) {
            const uint8_t value = input[position];
            const uint32_t bit_id = static_cast<uint32_t>(position & 63u);
            if (value == '"' && escape == 0u) real_quotes |= 1ull << bit_id;
            escape = value == '\\' ? static_cast<uint8_t>(escape ^ 1u) : 0u;
        }

        const uint8_t word_quote_parity = static_cast<uint8_t>(__popcll(real_quotes) & 1u);
        uint64_t in_string = gp4PrefixXor64(real_quotes);
        if (string_state != 0u) in_string = ~in_string;
        structural_out[word_id] = raw_structural[word_id] & ~in_string;
        quote_parity ^= word_quote_parity;
        string_state ^= word_quote_parity;
    }
    return quote_parity;
}

__device__ __forceinline__ void gpHierarchyAppendRecovery(
    bool needs_recovery, uint32_t item_id, uint32_t* recovery_items,
    uint32_t* recovery_count) {
    const uint32_t lane = threadIdx.x & 31u;
    const uint32_t mask = __ballot_sync(0xffffffffu, needs_recovery);
    if (mask == 0u) return;
    const uint32_t leader = static_cast<uint32_t>(__ffs(mask) - 1);
    uint32_t base = lane == leader
        ? atomicAdd(recovery_count, static_cast<uint32_t>(__popc(mask)))
        : 0u;
    base = __shfl_sync(0xffffffffu, base, leader);
    if (needs_recovery) {
        const uint32_t lower_lanes = lane == 0u ? 0u : ((1u << lane) - 1u);
        recovery_items[base + static_cast<uint32_t>(__popc(mask & lower_lanes))] = item_id;
    }
}

// Classify one 64-byte word while predicting incoming escape state E=0.  The
// first-non-slash quote bit is enough to turn this result into the E=1 result:
// only that quote can change when the incoming escape state changes.
__device__ __forceinline__ GpHierarchyCoalescedWord gpHierarchyClassifyCoalescedWord(
    const uint8_t* input, std::size_t input_size, std::size_t word_id) {
    GpHierarchyCoalescedWord word;
    const std::size_t byte_start = word_id * GP4_WORD_BYTES;
    const std::size_t byte_end = min(byte_start + GP4_WORD_BYTES, input_size);
    uint8_t escape = GP_HIERARCHY_PREDICT_ESCAPE;
    bool before_first_non_slash = true;

    for (std::size_t position = byte_start; position < byte_end; ++position) {
        const uint8_t value = input[position];
        const uint64_t bit = 1ull << static_cast<uint32_t>(position & 63u);
        if (gp4IsStructural(value)) word.raw_structural |= bit;
        if (value == '"' && escape == 0u) word.predicted_quotes |= bit;
        if (before_first_non_slash && value != '\\') {
            if (value == '"') word.first_non_slash_quote = bit;
            before_first_non_slash = false;
        }
        escape = value == '\\' ? static_cast<uint8_t>(escape ^ 1u) : 0u;
    }

    word.outgoing_escape = escape;
    word.quote_parity = static_cast<uint8_t>(__popcll(word.predicted_quotes) & 1u);
    word.all_slashes = before_first_non_slash ? 1u : 0u;
    return word;
}

__device__ __forceinline__ uint64_t gpHierarchyStructuralFromQuotes(
    uint64_t raw_structural, uint64_t real_quotes, uint8_t incoming_string) {
    uint64_t in_string = gp4PrefixXor64(real_quotes);
    if (incoming_string != 0u) in_string = ~in_string;
    return raw_structural & ~in_string;
}

// F1 keeps GPJSON's logical 64/128-byte segments, but schedules their words in
// warp-striped order.  For a 128-byte segment, adjacent lanes process its two
// words and the odd lane composes their boundary summaries with one shuffle.
// Thus every pass touches consecutive words without changing validation,
// recovery, quote-scan, or final-apply granularity.
__global__ void gpHierarchyCoalescedSegmentFirstKernel(
    const uint8_t* input, std::size_t input_size, std::size_t word_count,
    int words_per_segment, uint64_t* raw_structural, uint64_t* structural_out,
    uint8_t* escape_carry, uint8_t* quote_parity,
    uint8_t* escape_changes_quote) {
    const std::size_t thread_id = static_cast<std::size_t>(blockIdx.x) * blockDim.x + threadIdx.x;

    if (words_per_segment == 1) {
        const std::size_t word_id = thread_id;
        uint8_t outgoing = 0u;
        uint8_t parity = 0u;
        uint8_t changes_quote = 0u;
        if (word_id < word_count) {
            const std::size_t byte_start = word_id * GP4_WORD_BYTES;
            gpHierarchySpeculateRange(input, input_size, byte_start,
                min(byte_start + GP4_WORD_BYTES, input_size), raw_structural,
                structural_out, outgoing, parity, changes_quote);
        }
        escape_carry[thread_id] = outgoing;
        quote_parity[thread_id] = parity;
        escape_changes_quote[thread_id] = changes_quote;
        return;
    }

    const uint32_t lane = threadIdx.x & 31u;
    const std::size_t warp_id = thread_id >> 5u;
    const std::size_t warp_word_start = warp_id * 64u;
    for (uint32_t pass = 0u; pass < 2u; ++pass) {
        const std::size_t word_id = warp_word_start + pass * 32u + lane;
        GpHierarchyCoalescedWord word;
        if (word_id < word_count) word = gpHierarchyClassifyCoalescedWord(input, input_size, word_id);

        const uint32_t summary = static_cast<uint32_t>(word.outgoing_escape) |
            (static_cast<uint32_t>(word.quote_parity) << 1u) |
            (static_cast<uint32_t>(word.all_slashes) << 2u) |
            (static_cast<uint32_t>(word.first_non_slash_quote != 0ull) << 3u);
        const uint32_t first_summary = __shfl_up_sync(0xffffffffu, summary, 1);
        const bool second_word = (lane & 1u) != 0u;
        const uint8_t incoming_escape = second_word
            ? static_cast<uint8_t>(first_summary & 1u) : GP_HIERARCHY_PREDICT_ESCAPE;
        const uint8_t incoming_string = second_word
            ? static_cast<uint8_t>(GP_HIERARCHY_PREDICT_STRING ^ ((first_summary >> 1u) & 1u))
            : GP_HIERARCHY_PREDICT_STRING;
        const uint64_t real_quotes = word.predicted_quotes ^
            (incoming_escape != 0u ? word.first_non_slash_quote : 0ull);
        const uint8_t quote_was_toggled = static_cast<uint8_t>(
            incoming_escape != 0u && word.first_non_slash_quote != 0ull);
        const uint8_t actual_parity = static_cast<uint8_t>(word.quote_parity ^ quote_was_toggled);

        if (word_id < word_count) {
            raw_structural[word_id] = word.raw_structural;
            structural_out[word_id] = gpHierarchyStructuralFromQuotes(
                word.raw_structural, real_quotes, incoming_string);
        }

        if (second_word) {
            const std::size_t segment_id = word_id >> 1u;
            const uint8_t first_outgoing = static_cast<uint8_t>(first_summary & 1u);
            const uint8_t first_parity = static_cast<uint8_t>((first_summary >> 1u) & 1u);
            const uint8_t first_all_slashes = static_cast<uint8_t>((first_summary >> 2u) & 1u);
            const uint8_t first_changes_quote = static_cast<uint8_t>((first_summary >> 3u) & 1u);
            escape_carry[segment_id] = static_cast<uint8_t>(
                word.outgoing_escape ^ (first_outgoing & word.all_slashes));
            quote_parity[segment_id] = static_cast<uint8_t>(first_parity ^ actual_parity);
            escape_changes_quote[segment_id] = first_all_slashes
                ? static_cast<uint8_t>(word.first_non_slash_quote != 0ull)
                : first_changes_quote;
        }
    }
}

__global__ void gpHierarchyOriginalFirstKernel(
    const uint8_t* input, std::size_t input_size, uint64_t* raw_structural,
    uint64_t* structural_out, uint8_t* escape_carry, uint8_t* quote_parity,
    uint8_t* escape_changes_quote) {
    const uint32_t segment_id = blockIdx.x * blockDim.x + threadIdx.x;
    std::size_t byte_start, byte_end;
    gp4OriginalSegment(input_size, static_cast<int>(segment_id), byte_start, byte_end);
    uint8_t outgoing = 0u;
    uint8_t parity = 0u;
    uint8_t changes_quote = 0u;
    if (byte_start < input_size)
        gpHierarchySpeculateRange(input, input_size, byte_start, byte_end,
                                  raw_structural, structural_out, outgoing,
                                  parity, changes_quote);
    escape_carry[segment_id] = outgoing;
    quote_parity[segment_id] = parity;
    escape_changes_quote[segment_id] = changes_quote;
}

__global__ void gpHierarchyOriginalCollectKernel(
    std::size_t active_segments, const uint8_t* escape_carry,
    const uint8_t* escape_changes_quote, uint32_t* recovery_segments,
    uint32_t* recovery_count) {
    const uint32_t segment_id = blockIdx.x * blockDim.x + threadIdx.x;
    bool needs_recovery = false;
    if (segment_id < active_segments) {
        const uint8_t incoming_escape = segment_id == 0u ? 0u : escape_carry[segment_id - 1u];
        needs_recovery = incoming_escape != GP_HIERARCHY_PREDICT_ESCAPE &&
                         escape_changes_quote[segment_id] != 0u;
    }
    gpHierarchyAppendRecovery(needs_recovery, segment_id, recovery_segments, recovery_count);
}

// Recovery owns a compact queue, not GPJSON's full logical segment space.
// A small persistent grid walks only queued segments and performs the same
// per-segment input reread and E=1 recomputation as GPJSON's second pass.
__global__ void gpHierarchyOriginalCompactRecoveryKernel(
    const uint8_t* input, std::size_t input_size, std::size_t segment_bytes,
    const uint32_t* recovery_segments, const uint32_t* recovery_count,
    const uint64_t* raw_structural, uint64_t* structural_out,
    uint8_t* quote_parity) {
    std::size_t position = static_cast<std::size_t>(blockIdx.x) * blockDim.x + threadIdx.x;
    const std::size_t stride = static_cast<std::size_t>(blockDim.x) * gridDim.x;
    const uint32_t count = *recovery_count;
    for (; position < count; position += stride) {
        const uint32_t segment_id = recovery_segments[position];
        const std::size_t byte_start = static_cast<std::size_t>(segment_id) * segment_bytes;
        const std::size_t byte_end = byte_start + segment_bytes;
        quote_parity[segment_id] = gpHierarchyRecoverRange(
            input, input_size, byte_start, byte_end, raw_structural, structural_out);
    }
}

__global__ void gpHierarchyOriginalApplyStringKernel(
    std::size_t input_size, const uint8_t* inclusive_quote_prefix,
    const uint64_t* raw_structural, uint64_t* structural_out) {
    const uint32_t segment_id = blockIdx.x * blockDim.x + threadIdx.x;
    std::size_t byte_start, byte_end;
    gp4OriginalSegment(input_size, static_cast<int>(segment_id), byte_start, byte_end);
    if (byte_start >= input_size) return;
    const uint8_t incoming_string = segment_id == 0u ? 0u : inclusive_quote_prefix[segment_id - 1u];
    const uint64_t correction_mask = 0ull - static_cast<uint64_t>(
        incoming_string ^ GP_HIERARCHY_PREDICT_STRING);
    const std::size_t first_word = byte_start >> 6u;
    std::size_t final_word = (byte_end + GP4_WORD_BYTES - 1u) >> 6u;
    const std::size_t word_count = gpHierarchyWordCount(input_size);
    if (final_word > word_count) final_word = word_count;
    for (std::size_t word_id = first_word; word_id < final_word; ++word_id)
        structural_out[word_id] ^= raw_structural[word_id] & correction_mask;
}

__global__ void gpHierarchyWordFirstKernel(
    const uint8_t* input, std::size_t input_size, std::size_t word_count,
    std::size_t chunk_count, uint64_t* raw_structural, uint64_t* structural_out,
    uint8_t* escape_carry, uint8_t* quote_parity,
    uint8_t* escape_changes_quote) {
    for (std::size_t chunk = blockIdx.x; chunk < chunk_count; chunk += gridDim.x) {
        const std::size_t word_id = chunk * GP_HIERARCHY_WORD_BLOCK + threadIdx.x;
        if (word_id >= word_count) continue;
        uint8_t outgoing = 0u;
        uint8_t parity = 0u;
        uint8_t changes_quote = 0u;
        const std::size_t byte_start = word_id << 6u;
        gpHierarchySpeculateRange(input, input_size, byte_start,
                                  min(byte_start + GP4_WORD_BYTES, input_size),
                                  raw_structural, structural_out, outgoing,
                                  parity, changes_quote);
        escape_carry[word_id] = outgoing;
        quote_parity[word_id] = parity;
        escape_changes_quote[word_id] = changes_quote;
    }
}

__global__ void gpHierarchyWordCollectKernel(
    std::size_t word_count, std::size_t chunk_count,
    const uint8_t* escape_carry, const uint8_t* escape_changes_quote,
    uint32_t* recovery_words, uint32_t* recovery_count) {
    for (std::size_t chunk = blockIdx.x; chunk < chunk_count; chunk += gridDim.x) {
        const std::size_t word_id = chunk * GP_HIERARCHY_WORD_BLOCK + threadIdx.x;
        bool needs_recovery = false;
        if (word_id < word_count) {
            const uint8_t incoming_escape = word_id == 0u ? 0u : escape_carry[word_id - 1u];
            needs_recovery = incoming_escape != GP_HIERARCHY_PREDICT_ESCAPE &&
                             escape_changes_quote[word_id] != 0u;
        }
        gpHierarchyAppendRecovery(needs_recovery, static_cast<uint32_t>(word_id),
                                  recovery_words, recovery_count);
    }
}

__global__ void gpHierarchyWordRecoveryKernel(
    const uint8_t* input, std::size_t input_size,
    const uint32_t* recovery_words, const uint32_t* recovery_count,
    const uint64_t* raw_structural, uint64_t* structural_out,
    uint8_t* quote_parity) {
    std::size_t position = static_cast<std::size_t>(blockIdx.x) * blockDim.x + threadIdx.x;
    const std::size_t stride = static_cast<std::size_t>(blockDim.x) * gridDim.x;
    const uint32_t count = *recovery_count;
    for (; position < count; position += stride) {
        const uint32_t word_id = recovery_words[position];
        const std::size_t byte_start = static_cast<std::size_t>(word_id) << 6u;
        quote_parity[word_id] = gpHierarchyRecoverRange(
            input, input_size, byte_start, min(byte_start + GP4_WORD_BYTES, input_size),
            raw_structural, structural_out);
    }
}

__global__ void gpHierarchyWordApplyStringKernel(
    std::size_t word_count, std::size_t chunk_count,
    const uint8_t* inclusive_quote_prefix, const uint64_t* raw_structural,
    uint64_t* structural_out) {
    for (std::size_t chunk = blockIdx.x; chunk < chunk_count; chunk += gridDim.x) {
        const std::size_t word_id = chunk * GP_HIERARCHY_WORD_BLOCK + threadIdx.x;
        if (word_id >= word_count) continue;
        const uint8_t incoming_string = word_id == 0u ? 0u : inclusive_quote_prefix[word_id - 1u];
        const uint64_t correction_mask = 0ull - static_cast<uint64_t>(
            incoming_string ^ GP_HIERARCHY_PREDICT_STRING);
        structural_out[word_id] ^= raw_structural[word_id] & correction_mask;
    }
}

inline int gpHierarchyWordPersistentBlocks() {
    int device = 0;
    int blocks_per_sm = 0;
    cudaDeviceProp properties{};
    GP4_CUDA_CHECK(cudaGetDevice(&device));
    GP4_CUDA_CHECK(cudaGetDeviceProperties(&properties, device));
    GP4_CUDA_CHECK(cudaOccupancyMaxActiveBlocksPerMultiprocessor(
        &blocks_per_sm, gpHierarchyWordFirstKernel,
        GP_HIERARCHY_WORD_BLOCK, 0));
    return std::max(1, blocks_per_sm * properties.multiProcessorCount);
}

inline int gpHierarchyOriginalRecoveryPersistentBlocks() {
    static const int persistent_blocks = [] {
        int device = 0;
        int blocks_per_sm = 0;
        cudaDeviceProp properties{};
        GP4_CUDA_CHECK(cudaGetDevice(&device));
        GP4_CUDA_CHECK(cudaGetDeviceProperties(&properties, device));
        GP4_CUDA_CHECK(cudaOccupancyMaxActiveBlocksPerMultiprocessor(
            &blocks_per_sm, gpHierarchyOriginalCompactRecoveryKernel,
            GP_HIERARCHY_RECOVERY_BLOCK, 0));
        return std::max(1, blocks_per_sm * properties.multiProcessorCount);
    }();
    return persistent_blocks;
}

inline void gpLaunchCorrectedHierarchyOriginalMapping(
    const uint8_t* input, std::size_t input_size, uint64_t* structural_out,
    GpHierarchyOriginalBuffers buffers, cudaStream_t stream = nullptr) {
    const std::size_t active_segments = gpHierarchyOriginalActiveSegments(input_size);
    GP4_CUDA_CHECK(cudaMemsetAsync(buffers.recovery_count, 0, sizeof(uint32_t), stream));
    gpHierarchyOriginalFirstKernel<<<GP4_ORIGINAL_GRID, GP4_ORIGINAL_BLOCK, 0, stream>>>(
        input, input_size, buffers.raw_structural, structural_out,
        buffers.escape_carry, buffers.quote_parity_or_prefix,
        buffers.escape_changes_quote);
    gpHierarchyOriginalCollectKernel<<<GP4_ORIGINAL_GRID, GP4_ORIGINAL_BLOCK, 0, stream>>>(
        active_segments, buffers.escape_carry, buffers.escape_changes_quote,
        buffers.recovery_segments, buffers.recovery_count);
    gpHierarchyOriginalCompactRecoveryKernel<<<gpHierarchyOriginalRecoveryPersistentBlocks(),
        GP_HIERARCHY_RECOVERY_BLOCK, 0, stream>>>(
        input, input_size, gpHierarchyOriginalAlignedBytes(input_size),
        buffers.recovery_segments, buffers.recovery_count,
        buffers.raw_structural, structural_out, buffers.quote_parity_or_prefix);
    gp4OriginalXorPreScanKernel<<<GP4_SCAN_GRID, GP4_SCAN_BLOCK, 0, stream>>>(
        buffers.quote_parity_or_prefix, GP4_ORIGINAL_THREADS);
    gp4OriginalXorPostScanKernel<<<1, 1, 0, stream>>>(
        buffers.quote_parity_or_prefix, GP4_ORIGINAL_THREADS,
        GP4_SCAN_THREADS, buffers.xor_bases);
    gp4OriginalXorRebaseKernel<<<GP4_SCAN_GRID, GP4_SCAN_BLOCK, 0, stream>>>(
        buffers.quote_parity_or_prefix, GP4_ORIGINAL_THREADS,
        buffers.xor_bases);
    gpHierarchyOriginalApplyStringKernel<<<GP4_ORIGINAL_GRID, GP4_ORIGINAL_BLOCK, 0, stream>>>(
        input_size, buffers.quote_parity_or_prefix,
        buffers.raw_structural, structural_out);
}

inline void gpLaunchCorrectedHierarchyCoalescedFirst(
    const uint8_t* input, std::size_t input_size, uint64_t* structural_out,
    GpHierarchyOriginalBuffers buffers, cudaStream_t stream = nullptr) {
    const std::size_t active_segments = gpHierarchyOriginalActiveSegments(input_size);
    const std::size_t segment_bytes = gpHierarchyOriginalAlignedBytes(input_size);
    const std::size_t word_count = gpHierarchyWordCount(input_size);
    const int words_per_segment = static_cast<int>(segment_bytes / GP4_WORD_BYTES);
    GP4_CUDA_CHECK(cudaMemsetAsync(buffers.recovery_count, 0, sizeof(uint32_t), stream));
    if (words_per_segment <= 2) {
        gpHierarchyCoalescedSegmentFirstKernel<<<GP4_ORIGINAL_GRID, GP4_ORIGINAL_BLOCK, 0, stream>>>(
            input, input_size, word_count, words_per_segment,
            buffers.raw_structural, structural_out, buffers.escape_carry,
            buffers.quote_parity_or_prefix, buffers.escape_changes_quote);
    } else {
        gpHierarchyOriginalFirstKernel<<<GP4_ORIGINAL_GRID, GP4_ORIGINAL_BLOCK, 0, stream>>>(
            input, input_size, buffers.raw_structural, structural_out,
            buffers.escape_carry, buffers.quote_parity_or_prefix,
            buffers.escape_changes_quote);
    }
    gpHierarchyOriginalCollectKernel<<<GP4_ORIGINAL_GRID, GP4_ORIGINAL_BLOCK, 0, stream>>>(
        active_segments, buffers.escape_carry, buffers.escape_changes_quote,
        buffers.recovery_segments, buffers.recovery_count);
    gpHierarchyOriginalCompactRecoveryKernel<<<gpHierarchyOriginalRecoveryPersistentBlocks(),
        GP_HIERARCHY_RECOVERY_BLOCK, 0, stream>>>(
        input, input_size, segment_bytes, buffers.recovery_segments,
        buffers.recovery_count, buffers.raw_structural, structural_out,
        buffers.quote_parity_or_prefix);
    gp4OriginalXorPreScanKernel<<<GP4_SCAN_GRID, GP4_SCAN_BLOCK, 0, stream>>>(
        buffers.quote_parity_or_prefix, GP4_ORIGINAL_THREADS);
    gp4OriginalXorPostScanKernel<<<1, 1, 0, stream>>>(
        buffers.quote_parity_or_prefix, GP4_ORIGINAL_THREADS,
        GP4_SCAN_THREADS, buffers.xor_bases);
    gp4OriginalXorRebaseKernel<<<GP4_SCAN_GRID, GP4_SCAN_BLOCK, 0, stream>>>(
        buffers.quote_parity_or_prefix, GP4_ORIGINAL_THREADS,
        buffers.xor_bases);
    gpHierarchyOriginalApplyStringKernel<<<GP4_ORIGINAL_GRID, GP4_ORIGINAL_BLOCK, 0, stream>>>(
        input_size, buffers.quote_parity_or_prefix,
        buffers.raw_structural, structural_out);
}

inline void gpLaunchCorrectedHierarchyWordMapping(
    const uint8_t* input, std::size_t input_size, uint64_t* structural_out,
    GpHierarchyWordBuffers buffers, int persistent_blocks,
    cudaStream_t stream = nullptr) {
    const std::size_t word_count = gpHierarchyWordCount(input_size);
    const std::size_t chunk_count =
        (word_count + GP_HIERARCHY_WORD_BLOCK - 1u) / GP_HIERARCHY_WORD_BLOCK;
    const std::size_t scan_count = gpHierarchyPaddedScanCount(word_count);
    if (word_count == 0u) return;
    const int grid = std::max(1, std::min(persistent_blocks, static_cast<int>(chunk_count)));
    GP4_CUDA_CHECK(cudaMemsetAsync(buffers.recovery_count, 0, sizeof(uint32_t), stream));
    if (scan_count > word_count)
        GP4_CUDA_CHECK(cudaMemsetAsync(buffers.quote_parity_or_prefix + word_count, 0,
                                      scan_count - word_count, stream));
    gpHierarchyWordFirstKernel<<<grid, GP_HIERARCHY_WORD_BLOCK, 0, stream>>>(
        input, input_size, word_count, chunk_count, buffers.raw_structural,
        structural_out, buffers.escape_carry, buffers.quote_parity_or_prefix,
        buffers.escape_changes_quote);
    gpHierarchyWordCollectKernel<<<grid, GP_HIERARCHY_WORD_BLOCK, 0, stream>>>(
        word_count, chunk_count, buffers.escape_carry,
        buffers.escape_changes_quote, buffers.recovery_words,
        buffers.recovery_count);
    gpHierarchyWordRecoveryKernel<<<grid, GP_HIERARCHY_WORD_BLOCK, 0, stream>>>(
        input, input_size, buffers.recovery_words, buffers.recovery_count,
        buffers.raw_structural, structural_out,
        buffers.quote_parity_or_prefix);
    gp4OriginalXorPreScanKernel<<<GP4_SCAN_GRID, GP4_SCAN_BLOCK, 0, stream>>>(
        buffers.quote_parity_or_prefix, static_cast<int>(scan_count));
    gp4OriginalXorPostScanKernel<<<1, 1, 0, stream>>>(
        buffers.quote_parity_or_prefix, static_cast<int>(scan_count),
        GP4_SCAN_THREADS, buffers.xor_bases);
    gp4OriginalXorRebaseKernel<<<GP4_SCAN_GRID, GP4_SCAN_BLOCK, 0, stream>>>(
        buffers.quote_parity_or_prefix, static_cast<int>(scan_count),
        buffers.xor_bases);
    gpHierarchyWordApplyStringKernel<<<grid, GP_HIERARCHY_WORD_BLOCK, 0, stream>>>(
        word_count, chunk_count, buffers.quote_parity_or_prefix,
        buffers.raw_structural, structural_out);
}
