#pragma once

#include <cuda_runtime.h>

#include <algorithm>
#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <string>
#include <vector>

constexpr uint32_t GP_THREADS = 1024u;
constexpr uint32_t GP_WORDS_PER_TILE = GP_THREADS;
constexpr uint32_t GP_WARPS_PER_TILE = GP_THREADS / 32u;
constexpr uint32_t GP_BYTES_PER_WORD = 64u;
constexpr uint64_t GP_FNV_OFFSET = 1469598103934665603ull;
constexpr uint64_t GP_FNV_PRIME = 1099511628211ull;

struct GpInputDescriptor {
    uint64_t byte_offset;
    uint64_t byte_size;
    uint64_t word_offset;
    uint64_t padded_word_count;
};

struct GpHostInput {
    std::string path;
    uint64_t byte_size = 0u;
    uint64_t word_offset = 0u;
    uint64_t word_count = 0u;
    uint64_t padded_word_count = 0u;
};

struct GpHostBatch {
    std::vector<GpHostInput> inputs;
    std::vector<GpInputDescriptor> descriptors;
    std::vector<uint8_t> bytes;
    uint64_t total_bytes = 0u;
    uint64_t total_padded_words = 0u;
};

#define GP_CUDA_CHECK(call) do { cudaError_t gp_error_ = (call); if (gp_error_ != cudaSuccess) { \
    std::cerr << "CUDA error at " << __FILE__ << ':' << __LINE__ << ": " \
              << cudaGetErrorString(gp_error_) << '\n'; std::exit(EXIT_FAILURE); } } while (0)

__host__ __device__ __forceinline__ bool gpIsStructural(uint8_t byte) {
    return byte == '{' || byte == '}' || byte == '[' || byte == ']' || byte == ':' || byte == ',';
}

__host__ __device__ __forceinline__ uint64_t gpPrefixXor64(uint64_t quotes) {
    quotes ^= quotes << 1u;
    quotes ^= quotes << 2u;
    quotes ^= quotes << 4u;
    quotes ^= quotes << 8u;
    quotes ^= quotes << 16u;
    quotes ^= quotes << 32u;
    return quotes;
}

__device__ __forceinline__ void gpClassifyWord(const uint8_t* input, uint64_t input_size,
    uint64_t word_id, uint64_t& slash_word, uint64_t& quote_word, uint64_t& structural_word) {
    slash_word = 0ull;
    quote_word = 0ull;
    structural_word = 0ull;
    uint64_t byte_start = word_id * GP_BYTES_PER_WORD;
    uint64_t byte_end = min(byte_start + GP_BYTES_PER_WORD, input_size);
    for (uint64_t position = byte_start; position < byte_end; ++position) {
        uint64_t bit = 1ull << (position - byte_start);
        uint8_t byte = input[position];
        if (byte == '\\') slash_word |= bit;
        if (byte == '"') quote_word |= bit;
        if (gpIsStructural(byte)) structural_word |= bit;
    }
}

__device__ __forceinline__ uint64_t gpFilterEscapedQuotes64(
    uint64_t quote_word, uint64_t slash_word, uint32_t incoming_escape) {
    constexpr uint64_t even_bits = 0x5555555555555555ull;
    constexpr uint64_t odd_bits = ~even_bits;
    slash_word &= ~static_cast<uint64_t>(incoming_escape);
    uint64_t possible_escaped = (slash_word << 1u) | incoming_escape;
    uint64_t odd_sequence = slash_word & odd_bits & ~possible_escaped;
    uint64_t sequence_start_even = odd_sequence + slash_word;
    uint64_t escaped = (even_bits ^ (sequence_start_even << 1u)) & possible_escaped;
    return quote_word & ~escaped;
}

__device__ __forceinline__ uint32_t gpIncomingEscape(
    const uint64_t* shared_slashes, uint32_t previous_tile_escape) {
    uint32_t incoming = previous_tile_escape;
    for (int previous = static_cast<int>(threadIdx.x) - 1; previous >= 0; --previous) {
        uint32_t trailing = static_cast<uint32_t>(__clzll(~shared_slashes[previous]));
        if (trailing != 64u) {
            incoming = trailing & 1u;
            break;
        }
    }
    return incoming;
}

__device__ __forceinline__ uint32_t gpOutgoingEscape(
    uint64_t slash_word, uint32_t incoming_escape) {
    uint32_t trailing = static_cast<uint32_t>(__clzll(~slash_word));
    return trailing == 64u ? incoming_escape : trailing & 1u;
}

// Retained for the stage-major control, which materializes all 1,024 prefixes.
__device__ __forceinline__ void gpInclusiveXorScan1024(
    uint32_t value, uint32_t* shared_parity) {
    uint32_t lane = threadIdx.x;
    shared_parity[lane] = value;
    __syncthreads();
    for (uint32_t offset = 1u; offset < GP_THREADS; offset <<= 1u) {
        uint32_t current = shared_parity[lane];
        uint32_t previous = lane >= offset ? shared_parity[lane - offset] : 0u;
        __syncthreads();
        if (lane >= offset) shared_parity[lane] = current ^ previous;
        __syncthreads();
    }
}

// The fused kernel only needs the prefix returned to each thread, so it can
// scan within warps in registers and exchange only the 32 warp totals.
__device__ __forceinline__ uint32_t gpWarpInclusiveXorScan1024(
    uint32_t value, uint32_t* shared_warp_parity) {
    constexpr uint32_t full_warp = 0xffffffffu;
    uint32_t lane = threadIdx.x & 31u;
    uint32_t warp = threadIdx.x >> 5u;

    // Each warp first scans its 32 values entirely in registers.
    uint32_t inclusive = value;
    for (uint32_t offset = 1u; offset < 32u; offset <<= 1u) {
        uint32_t previous = __shfl_up_sync(full_warp, inclusive, offset);
        if (lane >= offset) inclusive ^= previous;
    }
    if (lane == 31u) shared_warp_parity[warp] = inclusive;
    __syncthreads();

    // Warp 0 scans the 32 warp totals, then publishes those prefixes.
    if (warp == 0u) {
        uint32_t warp_prefix = shared_warp_parity[lane];
        for (uint32_t offset = 1u; offset < GP_WARPS_PER_TILE; offset <<= 1u) {
            uint32_t previous = __shfl_up_sync(full_warp, warp_prefix, offset);
            if (lane >= offset) warp_prefix ^= previous;
        }
        shared_warp_parity[lane] = warp_prefix;
    }
    __syncthreads();

    uint32_t previous_warps = warp == 0u ? 0u : shared_warp_parity[warp - 1u];
    return previous_warps ^ inclusive;
}

inline bool gpParsePositiveInt(const char* text, int& value) {
    char* end = nullptr;
    long parsed = std::strtol(text, &end, 10);
    if (end == text || *end != '\0' || parsed <= 0 || parsed > std::numeric_limits<int>::max()) return false;
    value = static_cast<int>(parsed);
    return true;
}

inline GpHostBatch gpLoadBatch(const std::vector<std::string>& paths) {
    GpHostBatch batch;
    batch.inputs.resize(paths.size());
    batch.descriptors.resize(paths.size());
    for (size_t input_id = 0u; input_id < paths.size(); ++input_id) {
        GpHostInput& input = batch.inputs[input_id];
        input.path = paths[input_id];
        std::ifstream file(input.path, std::ios::binary | std::ios::ate);
        if (!file) throw std::runtime_error("cannot open input: " + input.path);
        std::streamoff end = file.tellg();
        if (end < 0) throw std::runtime_error("cannot measure input: " + input.path);
        input.byte_size = static_cast<uint64_t>(end);
        input.word_count = (input.byte_size + GP_BYTES_PER_WORD - 1u) / GP_BYTES_PER_WORD;
        input.padded_word_count = input.word_count == 0u ? 0u :
            ((input.word_count + GP_WORDS_PER_TILE - 1u) / GP_WORDS_PER_TILE) * GP_WORDS_PER_TILE;
        input.word_offset = batch.total_padded_words;
        if (input.padded_word_count > std::numeric_limits<uint64_t>::max() - batch.total_padded_words)
            throw std::runtime_error("combined bitmap size overflows uint64_t");
        batch.total_padded_words += input.padded_word_count;
        batch.total_bytes += input.byte_size;
    }

    if (batch.total_padded_words > std::numeric_limits<size_t>::max() / GP_BYTES_PER_WORD)
        throw std::runtime_error("combined input exceeds host address space");
    size_t storage_bytes = std::max<size_t>(
        static_cast<size_t>(batch.total_padded_words) * GP_BYTES_PER_WORD, GP_BYTES_PER_WORD);
    batch.bytes.assign(storage_bytes, 0u);
    for (size_t input_id = 0u; input_id < batch.inputs.size(); ++input_id) {
        GpHostInput& input = batch.inputs[input_id];
        uint64_t byte_offset = input.word_offset * GP_BYTES_PER_WORD;
        std::ifstream file(input.path, std::ios::binary);
        if (input.byte_size != 0u &&
            !file.read(reinterpret_cast<char*>(batch.bytes.data() + static_cast<size_t>(byte_offset)),
                       static_cast<std::streamsize>(input.byte_size)))
            throw std::runtime_error("cannot read input: " + input.path);
        batch.descriptors[input_id] = {
            byte_offset, input.byte_size, input.word_offset, input.padded_word_count};
    }
    return batch;
}

inline std::vector<uint64_t> gpCpuStructuralBitmap(const uint8_t* input, uint64_t input_size) {
    std::vector<uint64_t> structural((input_size + GP_BYTES_PER_WORD - 1u) / GP_BYTES_PER_WORD, 0ull);
    bool in_string = false;
    uint64_t slash_count = 0u;
    for (uint64_t position = 0u; position < input_size; ++position) {
        uint8_t byte = input[position];
        bool real_quote = byte == '"' && (slash_count & 1u) == 0u;
        if (real_quote) in_string = !in_string;
        if (!in_string && gpIsStructural(byte))
            structural[position / GP_BYTES_PER_WORD] |= 1ull << (position % GP_BYTES_PER_WORD);
        slash_count = byte == '\\' ? slash_count + 1u : 0u;
    }
    return structural;
}

inline uint64_t gpAppendHash(uint64_t hash, uint64_t value) {
    hash ^= value;
    return hash * GP_FNV_PRIME;
}

inline bool gpCheckOutput(const GpHostBatch& batch, const std::vector<uint64_t>& output,
    uint64_t& checksum) {
    bool correct = true;
    checksum = GP_FNV_OFFSET;
    for (const GpHostInput& input : batch.inputs) {
        const uint8_t* bytes = batch.bytes.data() + static_cast<size_t>(input.word_offset * GP_BYTES_PER_WORD);
        std::vector<uint64_t> expected = gpCpuStructuralBitmap(bytes, input.byte_size);
        for (uint64_t word = 0u; word < input.word_count; ++word) {
            uint64_t actual = output[static_cast<size_t>(input.word_offset + word)];
            correct &= actual == expected[static_cast<size_t>(word)];
            checksum = gpAppendHash(checksum, actual);
        }
    }
    return correct;
}

inline void gpPrintResult(const char* method, const GpHostBatch& batch, int runs,
    double average_ms, bool correct, uint64_t checksum) {
    std::cout << std::fixed << std::setprecision(3)
              << "method=" << method << " inputs=" << batch.inputs.size()
              << " bytes=" << batch.total_bytes << " runs=" << runs
              << " avg_us=" << average_ms * 1000.0
              << " outputs_correct=" << (correct ? "PASS" : "FAIL")
              << " checksum=" << checksum << '\n';
}
