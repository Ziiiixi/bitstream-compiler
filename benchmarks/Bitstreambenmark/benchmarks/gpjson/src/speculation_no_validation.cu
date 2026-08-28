#include "gpjson_single_input_common.cuh"
#include "hierarchical_common.cuh"

#include <cstdint>

int main(int argc, char** argv) {
    const int runs = gpSingleRuns(argc, argv);
    if (runs == 0) return 1;
    GpSingleProblem problem(argv[1]);

    const std::size_t word_count = problem.expected.size();
    const int words_per_segment = static_cast<int>(
        gpHierarchyOriginalAlignedBytes(problem.input.size()) / GP4_WORD_BYTES);
    uint64_t* raw_structural = gpSingleAllocate<uint64_t>(word_count);
    uint8_t* escape_carry = gpSingleAllocate<uint8_t>(GP4_ORIGINAL_THREADS);
    uint8_t* quote_parity = gpSingleAllocate<uint8_t>(GP4_ORIGINAL_THREADS);
    uint8_t* escape_changes_quote = gpSingleAllocate<uint8_t>(GP4_ORIGINAL_THREADS);

    const double average_ms = gpSingleBenchmark([&] {
        if (words_per_segment <= 2)
            gpHierarchyCoalescedSegmentFirstKernel<<<GP4_ORIGINAL_GRID, GP4_ORIGINAL_BLOCK>>>(
                problem.device_input, problem.input.size(), word_count,
                words_per_segment, raw_structural, problem.device_output,
                escape_carry, quote_parity, escape_changes_quote);
        else
            gpHierarchyOriginalFirstKernel<<<GP4_ORIGINAL_GRID, GP4_ORIGINAL_BLOCK>>>(
                problem.device_input, problem.input.size(), raw_structural,
                problem.device_output, escape_carry, quote_parity,
                escape_changes_quote);
    }, runs);
    const GpSingleValidation validation = gpSingleValidate(problem);
    gpSinglePrint("gpjson_speculation_no_validation", problem, runs, average_ms,
                  validation, "FAIL");

    cudaFree(raw_structural);
    cudaFree(escape_carry);
    cudaFree(quote_parity);
    cudaFree(escape_changes_quote);
    return 0;
}
