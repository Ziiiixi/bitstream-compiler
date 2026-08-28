#include "gpjson_single_input_common.cuh"
#include "hierarchical_common.cuh"

#include <cstdint>

int main(int argc, char** argv) {
    const int runs = gpSingleRuns(argc, argv);
    if (runs == 0) return 1;
    GpSingleProblem problem(argv[1]);

    const std::size_t word_count = problem.expected.size();
    const std::size_t active_segments = gpHierarchyOriginalActiveSegments(problem.input.size());
    GpHierarchyOriginalBuffers buffers;
    buffers.raw_structural = gpSingleAllocate<uint64_t>(word_count);
    buffers.escape_carry = gpSingleAllocate<uint8_t>(GP4_ORIGINAL_THREADS);
    buffers.quote_parity_or_prefix = gpSingleAllocate<uint8_t>(GP4_ORIGINAL_THREADS);
    buffers.escape_changes_quote = gpSingleAllocate<uint8_t>(GP4_ORIGINAL_THREADS);
    buffers.recovery_segments = gpSingleAllocate<uint32_t>(active_segments);
    buffers.recovery_count = gpSingleAllocate<uint32_t>(1u);
    buffers.xor_bases = gpSingleAllocate<uint8_t>(GP4_SCAN_THREADS);

    const double average_ms = gpSingleBenchmark([&] {
        gpLaunchCorrectedHierarchyCoalescedFirst(problem.device_input, problem.input.size(),
                                                  problem.device_output, buffers);
    }, runs);
    const GpSingleValidation validation = gpSingleValidate(problem);
    gpSinglePrint("gpjson_hierarchical_speculation", problem, runs, average_ms, validation);

    cudaFree(buffers.raw_structural);
    cudaFree(buffers.escape_carry);
    cudaFree(buffers.quote_parity_or_prefix);
    cudaFree(buffers.escape_changes_quote);
    cudaFree(buffers.recovery_segments);
    cudaFree(buffers.recovery_count);
    cudaFree(buffers.xor_bases);
    return validation.correct ? 0 : 2;
}
