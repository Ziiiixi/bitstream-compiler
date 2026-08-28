#include "gpjson_single_input_common.cuh"
#include "hierarchical_common.cuh"

#include <cstddef>
#include <cstdint>

constexpr uint32_t GP_COMPACT_NO_AFFECTED_QUOTE = 0xffffffffu;

struct GpCompactEnumerationBuffers {
    uint64_t* raw_structural = nullptr;
    uint8_t* escape_out_if_zero = nullptr;
    uint8_t* quote_parity_if_zero_or_prefix = nullptr;
    uint32_t* first_affected_quote = nullptr;
    uint8_t* xor_bases = nullptr;
};

// Incoming E can change only the first non-backslash byte. If that byte is a
// quote, toggling it complements in-string state from that quote onward. Thus
// the exact E=1 candidate is E=0 XOR raw_structural[suffix]; no second bitmap
// is needed. This helper stores only the suffix start within the segment.
__device__ __forceinline__ void gpCompactEnumerateRange(
    const uint8_t* input, std::size_t input_size, std::size_t byte_start,
    std::size_t byte_end, uint64_t* raw_structural,
    uint64_t* structural_if_escape_zero, uint8_t& escape_out_if_zero,
    uint8_t& quote_parity_if_zero, uint32_t& first_affected_quote) {
    uint8_t escape = 0u;
    uint8_t string_state = GP_HIERARCHY_PREDICT_STRING;
    bool before_first_non_slash = true;
    quote_parity_if_zero = 0u;
    first_affected_quote = GP_COMPACT_NO_AFFECTED_QUOTE;

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
            const uint64_t bit = 1ull << static_cast<uint32_t>(position & 63u);
            if (gp4IsStructural(value)) raw_word |= bit;
            if (value == '"' && escape == 0u) real_quotes |= bit;
            if (before_first_non_slash && value != '\\') {
                if (value == '"') first_affected_quote = static_cast<uint32_t>(position - byte_start);
                before_first_non_slash = false;
            }
            escape = value == '\\' ? static_cast<uint8_t>(escape ^ 1u) : 0u;
        }

        const uint8_t word_parity = static_cast<uint8_t>(__popcll(real_quotes) & 1u);
        raw_structural[word_id] = raw_word;
        structural_if_escape_zero[word_id] = gpHierarchyStructuralFromQuotes(
            raw_word, real_quotes, string_state);
        quote_parity_if_zero ^= word_parity;
        string_state ^= word_parity;
    }
    escape_out_if_zero = escape;
}

// Same coalesced F1 geometry as the current hierarchical implementation. A
// two-word segment is handled by adjacent lanes; the odd lane composes the two
// word summaries and writes one compact delta position for the segment.
__global__ void gpCompactEnumerationFirstKernel(
    const uint8_t* input, std::size_t input_size, std::size_t word_count,
    int words_per_segment, uint64_t* raw_structural,
    uint64_t* structural_if_escape_zero, uint8_t* escape_out_if_zero,
    uint8_t* quote_parity_if_zero, uint32_t* first_affected_quote) {
    const std::size_t thread_id = static_cast<std::size_t>(blockIdx.x) * blockDim.x + threadIdx.x;

    if (words_per_segment == 1) {
        const std::size_t word_id = thread_id;
        GpHierarchyCoalescedWord word;
        if (word_id < word_count) word = gpHierarchyClassifyCoalescedWord(input, input_size, word_id);
        if (word_id < word_count) {
            raw_structural[word_id] = word.raw_structural;
            structural_if_escape_zero[word_id] = gpHierarchyStructuralFromQuotes(
                word.raw_structural, word.predicted_quotes, GP_HIERARCHY_PREDICT_STRING);
        }
        escape_out_if_zero[thread_id] = word.outgoing_escape;
        quote_parity_if_zero[thread_id] = word.quote_parity;
        first_affected_quote[thread_id] = word.first_non_slash_quote == 0ull
            ? GP_COMPACT_NO_AFFECTED_QUOTE
            : static_cast<uint32_t>(__ffsll(static_cast<long long>(word.first_non_slash_quote)) - 1);
        return;
    }

    const uint32_t lane = threadIdx.x & 31u;
    const std::size_t warp_id = thread_id >> 5u;
    const std::size_t warp_word_start = warp_id * 64u;
    for (uint32_t pass = 0u; pass < 2u; ++pass) {
        const std::size_t word_id = warp_word_start + pass * 32u + lane;
        GpHierarchyCoalescedWord word;
        if (word_id < word_count) word = gpHierarchyClassifyCoalescedWord(input, input_size, word_id);

        const uint32_t quote_plus_one = word.first_non_slash_quote == 0ull
            ? 0u : static_cast<uint32_t>(__ffsll(static_cast<long long>(word.first_non_slash_quote)));
        const uint32_t summary = static_cast<uint32_t>(word.outgoing_escape) |
            (static_cast<uint32_t>(word.quote_parity) << 1u) |
            (static_cast<uint32_t>(word.all_slashes) << 2u) | (quote_plus_one << 3u);
        const uint32_t first_summary = __shfl_up_sync(0xffffffffu, summary, 1);
        const bool second_word = (lane & 1u) != 0u;
        const uint8_t first_escape_out = static_cast<uint8_t>(first_summary & 1u);
        const uint8_t first_parity = static_cast<uint8_t>((first_summary >> 1u) & 1u);
        const uint8_t first_all_slashes = static_cast<uint8_t>((first_summary >> 2u) & 1u);
        const uint32_t first_quote_plus_one = first_summary >> 3u;
        const uint8_t incoming_escape = second_word ? first_escape_out : 0u;
        const uint8_t incoming_string = second_word
            ? static_cast<uint8_t>(GP_HIERARCHY_PREDICT_STRING ^ first_parity)
            : GP_HIERARCHY_PREDICT_STRING;
        const uint64_t real_quotes = word.predicted_quotes ^
            (incoming_escape != 0u ? word.first_non_slash_quote : 0ull);
        const uint8_t word_parity = static_cast<uint8_t>(word.quote_parity ^
            (incoming_escape != 0u && word.first_non_slash_quote != 0ull));

        if (word_id < word_count) {
            raw_structural[word_id] = word.raw_structural;
            structural_if_escape_zero[word_id] = gpHierarchyStructuralFromQuotes(
                word.raw_structural, real_quotes, incoming_string);
        }

        if (second_word) {
            const std::size_t segment_id = word_id >> 1u;
            escape_out_if_zero[segment_id] = static_cast<uint8_t>(
                word.outgoing_escape ^ (first_escape_out & word.all_slashes));
            quote_parity_if_zero[segment_id] = static_cast<uint8_t>(first_parity ^ word_parity);
            uint32_t affected = GP_COMPACT_NO_AFFECTED_QUOTE;
            if (first_quote_plus_one != 0u) affected = first_quote_plus_one - 1u;
            else if (first_all_slashes != 0u && quote_plus_one != 0u) affected = 64u + quote_plus_one - 1u;
            first_affected_quote[segment_id] = affected;
        }
    }
}

__global__ void gpCompactEnumerationGeneralFirstKernel(
    const uint8_t* input, std::size_t input_size, uint64_t* raw_structural,
    uint64_t* structural_if_escape_zero, uint8_t* escape_out_if_zero,
    uint8_t* quote_parity_if_zero, uint32_t* first_affected_quote) {
    const uint32_t segment_id = blockIdx.x * blockDim.x + threadIdx.x;
    std::size_t byte_start, byte_end;
    gp4OriginalSegment(input_size, static_cast<int>(segment_id), byte_start, byte_end);
    uint8_t outgoing = 0u;
    uint8_t parity = 0u;
    uint32_t affected = GP_COMPACT_NO_AFFECTED_QUOTE;
    if (byte_start < input_size) gpCompactEnumerateRange(input, input_size, byte_start, byte_end,
        raw_structural, structural_if_escape_zero, outgoing, parity, affected);
    escape_out_if_zero[segment_id] = outgoing;
    quote_parity_if_zero[segment_id] = parity;
    first_affected_quote[segment_id] = affected;
}

// Select the E-dependent parity before running GPJSON's original three-kernel
// quote scan. This is selection, not recovery: no input bytes are reread.
__global__ void gpCompactEnumerationQuotePreScanKernel(
    const uint8_t* escape_out_if_zero, const uint32_t* first_affected_quote,
    uint8_t* quote_parity_if_zero_or_prefix, int count) {
    const int thread_index = blockIdx.x * blockDim.x + threadIdx.x;
    const int stride = blockDim.x * gridDim.x;
    const int values_per_thread = (count + stride - 1) / stride;
    const int start = thread_index * values_per_thread;
    const int end = start + values_per_thread;
    uint8_t prefix = 0u;
    for (int segment_id = start; segment_id < end && segment_id < count; ++segment_id) {
        const uint8_t incoming_escape = segment_id == 0 ? 0u : escape_out_if_zero[segment_id - 1];
        const uint8_t changes_quote = first_affected_quote[segment_id] != GP_COMPACT_NO_AFFECTED_QUOTE;
        prefix ^= static_cast<uint8_t>(quote_parity_if_zero_or_prefix[segment_id] ^
            (incoming_escape & changes_quote));
        quote_parity_if_zero_or_prefix[segment_id] = prefix;
    }
}

// Select E=1 by applying the compact suffix delta, then select the actual
// incoming I with the same exact algebraic correction as hierarchy.
__global__ void gpCompactEnumerationFinalSelectKernel(
    std::size_t input_size, const uint8_t* escape_out_if_zero,
    const uint8_t* inclusive_quote_prefix, const uint32_t* first_affected_quote,
    const uint64_t* raw_structural, uint64_t* structural_if_escape_zero_or_output) {
    const uint32_t segment_id = blockIdx.x * blockDim.x + threadIdx.x;
    std::size_t byte_start, byte_end;
    gp4OriginalSegment(input_size, static_cast<int>(segment_id), byte_start, byte_end);
    if (byte_start >= input_size) return;
    const uint8_t incoming_escape = segment_id == 0u ? 0u : escape_out_if_zero[segment_id - 1u];
    const uint8_t incoming_string = segment_id == 0u ? 0u : inclusive_quote_prefix[segment_id - 1u];
    const uint64_t string_correction = 0ull - static_cast<uint64_t>(
        incoming_string ^ GP_HIERARCHY_PREDICT_STRING);
    const uint32_t affected_offset = first_affected_quote[segment_id];
    const std::size_t affected_position = affected_offset == GP_COMPACT_NO_AFFECTED_QUOTE
        ? static_cast<std::size_t>(-1) : byte_start + affected_offset;
    const std::size_t first_word = byte_start >> 6u;
    std::size_t final_word = (byte_end + GP4_WORD_BYTES - 1u) >> 6u;
    const std::size_t word_count = gpHierarchyWordCount(input_size);
    if (final_word > word_count) final_word = word_count;

    for (std::size_t word_id = first_word; word_id < final_word; ++word_id) {
        const uint64_t raw = raw_structural[word_id];
        uint64_t selected = structural_if_escape_zero_or_output[word_id];
        if (incoming_escape != 0u && affected_offset != GP_COMPACT_NO_AFFECTED_QUOTE) {
            const std::size_t word_start = word_id << 6u;
            uint64_t suffix = 0ull;
            if (word_start >= affected_position) suffix = ~0ull;
            else if (word_start + GP4_WORD_BYTES > affected_position)
                suffix = ~0ull << static_cast<uint32_t>(affected_position - word_start);
            selected ^= raw & suffix;
        }
        selected ^= raw & string_correction;
        structural_if_escape_zero_or_output[word_id] = selected;
    }
}

static void gpLaunchCompactEnumeration(
    const uint8_t* input, std::size_t input_size, uint64_t* output,
    GpCompactEnumerationBuffers buffers, cudaStream_t stream = nullptr) {
    const std::size_t word_count = gpHierarchyWordCount(input_size);
    const int words_per_segment = static_cast<int>(
        gpHierarchyOriginalAlignedBytes(input_size) / GP4_WORD_BYTES);
    if (words_per_segment <= 2) {
        gpCompactEnumerationFirstKernel<<<GP4_ORIGINAL_GRID, GP4_ORIGINAL_BLOCK, 0, stream>>>(
            input, input_size, word_count, words_per_segment, buffers.raw_structural,
            output, buffers.escape_out_if_zero, buffers.quote_parity_if_zero_or_prefix,
            buffers.first_affected_quote);
    } else {
        gpCompactEnumerationGeneralFirstKernel<<<GP4_ORIGINAL_GRID, GP4_ORIGINAL_BLOCK, 0, stream>>>(
            input, input_size, buffers.raw_structural, output, buffers.escape_out_if_zero,
            buffers.quote_parity_if_zero_or_prefix, buffers.first_affected_quote);
    }
    gpCompactEnumerationQuotePreScanKernel<<<GP4_SCAN_GRID, GP4_SCAN_BLOCK, 0, stream>>>(
        buffers.escape_out_if_zero, buffers.first_affected_quote,
        buffers.quote_parity_if_zero_or_prefix, GP4_ORIGINAL_THREADS);
    gp4OriginalXorPostScanKernel<<<1, 1, 0, stream>>>(buffers.quote_parity_if_zero_or_prefix,
        GP4_ORIGINAL_THREADS, GP4_SCAN_THREADS, buffers.xor_bases);
    gp4OriginalXorRebaseKernel<<<GP4_SCAN_GRID, GP4_SCAN_BLOCK, 0, stream>>>(
        buffers.quote_parity_if_zero_or_prefix, GP4_ORIGINAL_THREADS, buffers.xor_bases);
    gpCompactEnumerationFinalSelectKernel<<<GP4_ORIGINAL_GRID, GP4_ORIGINAL_BLOCK, 0, stream>>>(
        input_size, buffers.escape_out_if_zero, buffers.quote_parity_if_zero_or_prefix,
        buffers.first_affected_quote, buffers.raw_structural, output);
}

int main(int argc, char** argv) {
    const int runs = gpSingleRuns(argc, argv);
    if (runs == 0) return 1;
    GpSingleProblem problem(argv[1]);
    const std::size_t word_count = problem.expected.size();

    GpCompactEnumerationBuffers buffers;
    buffers.raw_structural = gpSingleAllocate<uint64_t>(word_count);
    buffers.escape_out_if_zero = gpSingleAllocate<uint8_t>(GP4_ORIGINAL_THREADS);
    buffers.quote_parity_if_zero_or_prefix = gpSingleAllocate<uint8_t>(GP4_ORIGINAL_THREADS);
    buffers.first_affected_quote = gpSingleAllocate<uint32_t>(GP4_ORIGINAL_THREADS);
    buffers.xor_bases = gpSingleAllocate<uint8_t>(GP4_SCAN_THREADS);

    const double average_ms = gpSingleBenchmark([&] {
        gpLaunchCompactEnumeration(problem.device_input, problem.input.size(),
            problem.device_output, buffers);
    }, runs);
    const GpSingleValidation validation = gpSingleValidate(problem);
    gpSinglePrint("gpjson_hierarchical_enumeration_compact_delta", problem, runs,
        average_ms, validation);

    cudaFree(buffers.raw_structural);
    cudaFree(buffers.escape_out_if_zero);
    cudaFree(buffers.quote_parity_if_zero_or_prefix);
    cudaFree(buffers.first_affected_quote);
    cudaFree(buffers.xor_bases);
    return validation.correct ? 0 : 2;
}
