#include "gpjson_single_input_common.cuh"
#include "original_gpjson.cuh"

#include <cstddef>
#include <cstdint>

int main(int argc, char** argv) {
    const int runs = gpSingleRuns(argc, argv);
    if (runs == 0) return 1;
    GpSingleProblem problem(argv[1]);

    uint8_t* escape_carry = gpSingleAllocate<uint8_t>(GP4_ORIGINAL_THREADS);
    uint8_t* quote_carry = gpSingleAllocate<uint8_t>(GP4_ORIGINAL_THREADS);
    uint8_t* xor_bases = gpSingleAllocate<uint8_t>(GP4_SCAN_THREADS);
    uint64_t* escape_bitmap = gpSingleAllocate<uint64_t>(problem.expected.size());
    uint64_t* quote_or_string_bitmap = gpSingleAllocate<uint64_t>(problem.expected.size());

    const double average_ms = gpSingleBenchmark([&] {
        gp4LaunchOriginal(problem.device_input, problem.input.size(), problem.expected.size(),
                          escape_carry, quote_carry, xor_bases, escape_bitmap,
                          quote_or_string_bitmap, problem.device_output);
    }, runs);
    const GpSingleValidation validation = gpSingleValidate(problem);
    gpSinglePrint("gpjson_source_faithful_baseline", problem, runs, average_ms, validation);

    cudaFree(escape_carry);
    cudaFree(quote_carry);
    cudaFree(xor_bases);
    cudaFree(escape_bitmap);
    cudaFree(quote_or_string_bitmap);
    return validation.correct ? 0 : 2;
}
