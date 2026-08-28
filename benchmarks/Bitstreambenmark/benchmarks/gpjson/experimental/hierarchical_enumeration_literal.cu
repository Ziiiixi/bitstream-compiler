#include "gpjson_single_input_common.cuh"
#include "hierarchical_common.cuh"

#include <cstddef>
#include <cstdint>

struct GpHierarchyEnumerationBuffers {
    uint64_t* raw_structural = nullptr;
    uint64_t* structural_if_escape_one = nullptr;
    uint8_t* escape_out_if_zero = nullptr;
    uint8_t* quote_parity_if_zero_or_prefix = nullptr;
    uint8_t* quote_parity_if_one = nullptr;
    uint8_t* xor_bases = nullptr;
};

// Classify a general logical segment once while carrying both possible
// incoming escape states. Both structural candidates assume incoming I=1;
// the final kernel selects the actual I state algebraically.
__device__ __forceinline__ void gpHierarchyEnumerateRange(
    const uint8_t* input, std::size_t input_size, std::size_t byte_start,
    std::size_t byte_end, uint64_t* raw_structural,
    uint64_t* structural_if_escape_zero,
    uint64_t* structural_if_escape_one, uint8_t& escape_out_if_zero,
    uint8_t& quote_parity_if_zero, uint8_t& quote_parity_if_one) {
    uint8_t escape_if_zero = 0u;
    uint8_t escape_if_one = 1u;
    uint8_t string_if_zero = GP_HIERARCHY_PREDICT_STRING;
    uint8_t string_if_one = GP_HIERARCHY_PREDICT_STRING;
    quote_parity_if_zero = 0u;
    quote_parity_if_one = 0u;

    const std::size_t first_word = byte_start >> 6u;
    std::size_t final_word = (byte_end + GP4_WORD_BYTES - 1u) >> 6u;
    const std::size_t word_count = gpHierarchyWordCount(input_size);
    if (final_word > word_count) final_word = word_count;

    for (std::size_t word_id = first_word; word_id < final_word; ++word_id) {
        const std::size_t word_start = word_id << 6u;
        const std::size_t word_end = min(word_start + GP4_WORD_BYTES, input_size);
        uint64_t raw_word = 0ull;
        uint64_t quotes_if_zero = 0ull;
        uint64_t quotes_if_one = 0ull;
        for (std::size_t position = word_start; position < word_end; ++position) {
            const uint8_t value = input[position];
            const uint64_t bit = 1ull << static_cast<uint32_t>(position & 63u);
            if (gp4IsStructural(value)) raw_word |= bit;
            if (value == '"' && escape_if_zero == 0u) quotes_if_zero |= bit;
            if (value == '"' && escape_if_one == 0u) quotes_if_one |= bit;
            escape_if_zero = value == '\\' ? static_cast<uint8_t>(escape_if_zero ^ 1u) : 0u;
            escape_if_one = value == '\\' ? static_cast<uint8_t>(escape_if_one ^ 1u) : 0u;
        }

        const uint8_t parity_if_zero = static_cast<uint8_t>(__popcll(quotes_if_zero) & 1u);
        const uint8_t parity_if_one = static_cast<uint8_t>(__popcll(quotes_if_one) & 1u);
        raw_structural[word_id] = raw_word;
        structural_if_escape_zero[word_id] = gpHierarchyStructuralFromQuotes(
            raw_word, quotes_if_zero, string_if_zero);
        structural_if_escape_one[word_id] = gpHierarchyStructuralFromQuotes(
            raw_word, quotes_if_one, string_if_one);
        quote_parity_if_zero ^= parity_if_zero;
        quote_parity_if_one ^= parity_if_one;
        string_if_zero ^= parity_if_zero;
        string_if_one ^= parity_if_one;
    }
    escape_out_if_zero = escape_if_zero;
}

// This is the same coalesced F1 mapping as hierarchical speculation. For a
// two-word segment, adjacent lanes independently classify consecutive words;
// the odd lane receives the first word's summary and composes both E paths.
__global__ void gpHierarchyEnumerationFirstKernel(
    const uint8_t* input, std::size_t input_size, std::size_t word_count,
    int words_per_segment, uint64_t* raw_structural,
    uint64_t* structural_if_escape_zero,
    uint64_t* structural_if_escape_one, uint8_t* escape_out_if_zero,
    uint8_t* quote_parity_if_zero, uint8_t* quote_parity_if_one) {
    const std::size_t thread_id =
        static_cast<std::size_t>(blockIdx.x) * blockDim.x + threadIdx.x;

    if (words_per_segment == 1) {
        const std::size_t word_id = thread_id;
        GpHierarchyCoalescedWord word;
        if (word_id < word_count)
            word = gpHierarchyClassifyCoalescedWord(input, input_size, word_id);
        const uint64_t quotes_if_zero = word.predicted_quotes;
        const uint64_t quotes_if_one = word.predicted_quotes ^ word.first_non_slash_quote;
        if (word_id < word_count) {
            raw_structural[word_id] = word.raw_structural;
            structural_if_escape_zero[word_id] = gpHierarchyStructuralFromQuotes(
                word.raw_structural, quotes_if_zero, GP_HIERARCHY_PREDICT_STRING);
            structural_if_escape_one[word_id] = gpHierarchyStructuralFromQuotes(
                word.raw_structural, quotes_if_one, GP_HIERARCHY_PREDICT_STRING);
        }
        escape_out_if_zero[thread_id] = word.outgoing_escape;
        quote_parity_if_zero[thread_id] = word.quote_parity;
        quote_parity_if_one[thread_id] = static_cast<uint8_t>(
            word.quote_parity ^ (word.first_non_slash_quote != 0ull));
        return;
    }

    const uint32_t lane = threadIdx.x & 31u;
    const std::size_t warp_id = thread_id >> 5u;
    const std::size_t warp_word_start = warp_id * 64u;
    for (uint32_t pass = 0u; pass < 2u; ++pass) {
        const std::size_t word_id = warp_word_start + pass * 32u + lane;
        GpHierarchyCoalescedWord word;
        if (word_id < word_count)
            word = gpHierarchyClassifyCoalescedWord(input, input_size, word_id);

        const uint32_t summary = static_cast<uint32_t>(word.outgoing_escape) |
            (static_cast<uint32_t>(word.quote_parity) << 1u) |
            (static_cast<uint32_t>(word.all_slashes) << 2u) |
            (static_cast<uint32_t>(word.first_non_slash_quote != 0ull) << 3u);
        const uint32_t first_summary = __shfl_up_sync(0xffffffffu, summary, 1);
        const bool second_word = (lane & 1u) != 0u;
        const uint8_t first_escape_out_if_zero =
            static_cast<uint8_t>(first_summary & 1u);
        const uint8_t first_parity_if_zero =
            static_cast<uint8_t>((first_summary >> 1u) & 1u);
        const uint8_t first_all_slashes =
            static_cast<uint8_t>((first_summary >> 2u) & 1u);
        const uint8_t first_quote_changes =
            static_cast<uint8_t>((first_summary >> 3u) & 1u);
        const uint8_t first_escape_out_if_one = static_cast<uint8_t>(
            first_escape_out_if_zero ^ first_all_slashes);
        const uint8_t first_parity_if_one = static_cast<uint8_t>(
            first_parity_if_zero ^ first_quote_changes);

        const uint8_t incoming_escape_if_zero = second_word
            ? first_escape_out_if_zero : 0u;
        const uint8_t incoming_escape_if_one = second_word
            ? first_escape_out_if_one : 1u;
        const uint8_t incoming_string_if_zero = second_word
            ? static_cast<uint8_t>(GP_HIERARCHY_PREDICT_STRING ^ first_parity_if_zero)
            : GP_HIERARCHY_PREDICT_STRING;
        const uint8_t incoming_string_if_one = second_word
            ? static_cast<uint8_t>(GP_HIERARCHY_PREDICT_STRING ^ first_parity_if_one)
            : GP_HIERARCHY_PREDICT_STRING;
        const uint64_t quotes_if_zero = word.predicted_quotes ^
            (incoming_escape_if_zero != 0u ? word.first_non_slash_quote : 0ull);
        const uint64_t quotes_if_one = word.predicted_quotes ^
            (incoming_escape_if_one != 0u ? word.first_non_slash_quote : 0ull);
        const uint8_t word_parity_if_zero = static_cast<uint8_t>(word.quote_parity ^
            (incoming_escape_if_zero != 0u && word.first_non_slash_quote != 0ull));
        const uint8_t word_parity_if_one = static_cast<uint8_t>(word.quote_parity ^
            (incoming_escape_if_one != 0u && word.first_non_slash_quote != 0ull));

        if (word_id < word_count) {
            raw_structural[word_id] = word.raw_structural;
            structural_if_escape_zero[word_id] = gpHierarchyStructuralFromQuotes(
                word.raw_structural, quotes_if_zero, incoming_string_if_zero);
            structural_if_escape_one[word_id] = gpHierarchyStructuralFromQuotes(
                word.raw_structural, quotes_if_one, incoming_string_if_one);
        }

        if (second_word) {
            const std::size_t segment_id = word_id >> 1u;
            escape_out_if_zero[segment_id] = static_cast<uint8_t>(
                word.outgoing_escape ^ (incoming_escape_if_zero & word.all_slashes));
            quote_parity_if_zero[segment_id] = static_cast<uint8_t>(
                first_parity_if_zero ^ word_parity_if_zero);
            quote_parity_if_one[segment_id] = static_cast<uint8_t>(
                first_parity_if_one ^ word_parity_if_one);
        }
    }
}

__global__ void gpHierarchyEnumerationGeneralFirstKernel(
    const uint8_t* input, std::size_t input_size,
    uint64_t* raw_structural, uint64_t* structural_if_escape_zero,
    uint64_t* structural_if_escape_one, uint8_t* escape_out_if_zero,
    uint8_t* quote_parity_if_zero, uint8_t* quote_parity_if_one) {
    const uint32_t segment_id = blockIdx.x * blockDim.x + threadIdx.x;
    std::size_t byte_start, byte_end;
    gp4OriginalSegment(input_size, static_cast<int>(segment_id), byte_start, byte_end);
    uint8_t outgoing = 0u;
    uint8_t parity_if_zero = 0u;
    uint8_t parity_if_one = 0u;
    if (byte_start < input_size)
        gpHierarchyEnumerateRange(input, input_size, byte_start, byte_end,
            raw_structural, structural_if_escape_zero,
            structural_if_escape_one, outgoing, parity_if_zero,
            parity_if_one);
    escape_out_if_zero[segment_id] = outgoing;
    quote_parity_if_zero[segment_id] = parity_if_zero;
    quote_parity_if_one[segment_id] = parity_if_one;
}

// Select each segment's E candidate while performing the original local quote
// prefix scan. This uses GPJSON's current immediate-predecessor carry rule, so
// no readiness flags or atomics are needed between the separate kernels. As in
// the existing baseline and hierarchy, it assumes a logical segment is not
// entirely backslashes; otherwise escape_out_if_zero is not an actual prefix.
__global__ void gpHierarchyEnumerationQuotePreScanKernel(
    const uint8_t* escape_out_if_zero, uint8_t* quote_parity_if_zero_or_prefix,
    const uint8_t* quote_parity_if_one, int count) {
    const int thread_index = blockIdx.x * blockDim.x + threadIdx.x;
    const int stride = blockDim.x * gridDim.x;
    const int values_per_thread = (count + stride - 1) / stride;
    const int start = thread_index * values_per_thread;
    const int end = start + values_per_thread;
    uint8_t prefix = 0u;
    for (int segment_id = start; segment_id < end && segment_id < count;
         ++segment_id) {
        const uint8_t incoming_escape = segment_id == 0
            ? 0u : escape_out_if_zero[segment_id - 1];
        const uint8_t parity = incoming_escape == 0u
            ? quote_parity_if_zero_or_prefix[segment_id]
            : quote_parity_if_one[segment_id];
        prefix ^= parity;
        quote_parity_if_zero_or_prefix[segment_id] = prefix;
    }
}

// The quote scan has now resolved incoming I. Select the precomputed E result,
// then select I by applying the exact complement relation with raw structural.
__global__ void gpHierarchyEnumerationFinalSelectKernel(
    std::size_t input_size, const uint8_t* escape_out_if_zero,
    const uint8_t* inclusive_quote_prefix, const uint64_t* raw_structural,
    const uint64_t* structural_if_escape_one,
    uint64_t* structural_if_escape_zero_or_output) {
    const uint32_t segment_id = blockIdx.x * blockDim.x + threadIdx.x;
    std::size_t byte_start, byte_end;
    gp4OriginalSegment(input_size, static_cast<int>(segment_id), byte_start, byte_end);
    if (byte_start >= input_size) return;
    const uint8_t incoming_escape = segment_id == 0u
        ? 0u : escape_out_if_zero[segment_id - 1u];
    const uint8_t incoming_string = segment_id == 0u
        ? 0u : inclusive_quote_prefix[segment_id - 1u];
    const uint64_t string_correction = 0ull - static_cast<uint64_t>(
        incoming_string ^ GP_HIERARCHY_PREDICT_STRING);
    const std::size_t first_word = byte_start >> 6u;
    std::size_t final_word = (byte_end + GP4_WORD_BYTES - 1u) >> 6u;
    const std::size_t word_count = gpHierarchyWordCount(input_size);
    if (final_word > word_count) final_word = word_count;
    for (std::size_t word_id = first_word; word_id < final_word; ++word_id) {
        uint64_t selected = incoming_escape == 0u
            ? structural_if_escape_zero_or_output[word_id]
            : structural_if_escape_one[word_id];
        selected ^= raw_structural[word_id] & string_correction;
        structural_if_escape_zero_or_output[word_id] = selected;
    }
}

static void gpLaunchHierarchyEnumeration(
    const uint8_t* input, std::size_t input_size, uint64_t* output,
    GpHierarchyEnumerationBuffers buffers, cudaStream_t stream = nullptr) {
    const std::size_t word_count = gpHierarchyWordCount(input_size);
    const int words_per_segment = static_cast<int>(
        gpHierarchyOriginalAlignedBytes(input_size) / GP4_WORD_BYTES);
    if (words_per_segment <= 2) {
        gpHierarchyEnumerationFirstKernel<<<GP4_ORIGINAL_GRID, GP4_ORIGINAL_BLOCK, 0, stream>>>(
            input, input_size, word_count, words_per_segment,
            buffers.raw_structural, output,
            buffers.structural_if_escape_one, buffers.escape_out_if_zero,
            buffers.quote_parity_if_zero_or_prefix,
            buffers.quote_parity_if_one);
    } else {
        gpHierarchyEnumerationGeneralFirstKernel<<<GP4_ORIGINAL_GRID,
            GP4_ORIGINAL_BLOCK, 0, stream>>>(input, input_size,
            buffers.raw_structural, output,
            buffers.structural_if_escape_one, buffers.escape_out_if_zero,
            buffers.quote_parity_if_zero_or_prefix,
            buffers.quote_parity_if_one);
    }
    gpHierarchyEnumerationQuotePreScanKernel<<<GP4_SCAN_GRID,
        GP4_SCAN_BLOCK, 0, stream>>>(buffers.escape_out_if_zero,
        buffers.quote_parity_if_zero_or_prefix,
        buffers.quote_parity_if_one, GP4_ORIGINAL_THREADS);
    gp4OriginalXorPostScanKernel<<<1, 1, 0, stream>>>(
        buffers.quote_parity_if_zero_or_prefix, GP4_ORIGINAL_THREADS,
        GP4_SCAN_THREADS, buffers.xor_bases);
    gp4OriginalXorRebaseKernel<<<GP4_SCAN_GRID, GP4_SCAN_BLOCK, 0, stream>>>(
        buffers.quote_parity_if_zero_or_prefix, GP4_ORIGINAL_THREADS,
        buffers.xor_bases);
    gpHierarchyEnumerationFinalSelectKernel<<<GP4_ORIGINAL_GRID,
        GP4_ORIGINAL_BLOCK, 0, stream>>>(input_size,
        buffers.escape_out_if_zero,
        buffers.quote_parity_if_zero_or_prefix,
        buffers.raw_structural, buffers.structural_if_escape_one, output);
}

int main(int argc, char** argv) {
    const int runs = gpSingleRuns(argc, argv);
    if (runs == 0) return 1;
    GpSingleProblem problem(argv[1]);
    const std::size_t word_count = problem.expected.size();

    GpHierarchyEnumerationBuffers buffers;
    buffers.raw_structural = gpSingleAllocate<uint64_t>(word_count);
    buffers.structural_if_escape_one = gpSingleAllocate<uint64_t>(word_count);
    buffers.escape_out_if_zero = gpSingleAllocate<uint8_t>(GP4_ORIGINAL_THREADS);
    buffers.quote_parity_if_zero_or_prefix =
        gpSingleAllocate<uint8_t>(GP4_ORIGINAL_THREADS);
    buffers.quote_parity_if_one = gpSingleAllocate<uint8_t>(GP4_ORIGINAL_THREADS);
    buffers.xor_bases = gpSingleAllocate<uint8_t>(GP4_SCAN_THREADS);

    const double average_ms = gpSingleBenchmark([&] {
        gpLaunchHierarchyEnumeration(problem.device_input, problem.input.size(),
            problem.device_output, buffers);
    }, runs);
    const GpSingleValidation validation = gpSingleValidate(problem);
    gpSinglePrint("gpjson_hierarchical_enumeration_literal", problem, runs, average_ms,
        validation);

    cudaFree(buffers.raw_structural);
    cudaFree(buffers.structural_if_escape_one);
    cudaFree(buffers.escape_out_if_zero);
    cudaFree(buffers.quote_parity_if_zero_or_prefix);
    cudaFree(buffers.quote_parity_if_one);
    cudaFree(buffers.xor_bases);
    return validation.correct ? 0 : 2;
}
