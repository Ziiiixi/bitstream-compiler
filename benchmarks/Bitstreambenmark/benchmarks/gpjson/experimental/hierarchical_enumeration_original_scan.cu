// Original-scan hierarchical enumeration: select the correct escape-state quote
// parity with a coalesced pass, then use GPJSON's original three-kernel XOR
// scan unchanged.  The existing enumeration implementation is included only
// to reuse its F1 candidate construction, final selection, driver helpers,
// and validation; its main is renamed and is not called.
#define main gpHierarchyEnumerationReferenceMain
#include "hierarchical_enumeration_literal.cu"
#undef main

// One logical GPJSON segment owns one byte in each candidate array.  This
// launch uses the original GPJSON logical grid, so adjacent lanes select
// adjacent segments and all three reads plus the write are coalesced.
__global__ void gpHierarchyEnumerationSelectQuoteParityKernel(
    const uint8_t* escape_out_if_zero,
    uint8_t* quote_parity_if_zero_or_selected,
    const uint8_t* quote_parity_if_one) {
    const uint32_t segment_id = blockIdx.x * blockDim.x + threadIdx.x;
    const uint8_t incoming_escape = segment_id == 0u
        ? 0u : escape_out_if_zero[segment_id - 1u];
    const uint8_t parity_if_zero = quote_parity_if_zero_or_selected[segment_id];
    const uint8_t parity_if_one = quote_parity_if_one[segment_id];
    quote_parity_if_zero_or_selected[segment_id] = static_cast<uint8_t>(
        parity_if_zero ^ (incoming_escape & (parity_if_zero ^ parity_if_one)));
}

static void gpLaunchHierarchyEnumerationOriginalScan(
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

    gpHierarchyEnumerationSelectQuoteParityKernel<<<GP4_ORIGINAL_GRID,
        GP4_ORIGINAL_BLOCK, 0, stream>>>(buffers.escape_out_if_zero,
        buffers.quote_parity_if_zero_or_prefix,
        buffers.quote_parity_if_one);
    gp4OriginalXorPreScanKernel<<<GP4_SCAN_GRID, GP4_SCAN_BLOCK, 0, stream>>>(
        buffers.quote_parity_if_zero_or_prefix, GP4_ORIGINAL_THREADS);
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
        gpLaunchHierarchyEnumerationOriginalScan(problem.device_input,
            problem.input.size(), problem.device_output, buffers);
    }, runs);
    const GpSingleValidation validation = gpSingleValidate(problem);
    gpSinglePrint("gpjson_hierarchical_enumeration_original_scan", problem, runs,
        average_ms, validation);

    cudaFree(buffers.raw_structural);
    cudaFree(buffers.structural_if_escape_one);
    cudaFree(buffers.escape_out_if_zero);
    cudaFree(buffers.quote_parity_if_zero_or_prefix);
    cudaFree(buffers.quote_parity_if_one);
    cudaFree(buffers.xor_bases);
    return validation.correct ? 0 : 2;
}
