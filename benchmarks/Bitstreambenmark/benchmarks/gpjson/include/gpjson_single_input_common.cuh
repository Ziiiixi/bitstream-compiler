#pragma once

#include "gpjson_reference_common.cuh"

#include <cuda_runtime.h>

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <string>
#include <utility>
#include <vector>

constexpr int GP_SINGLE_WARMUPS = 2;

template <typename T>
T* gpSingleAllocate(std::size_t count) {
    T* pointer = nullptr;
    GP4_CUDA_CHECK(cudaMalloc(&pointer, std::max<std::size_t>(count, 1u) * sizeof(T)));
    return pointer;
}

struct GpSingleProblem {
    std::string path;
    std::vector<uint8_t> input;
    std::vector<uint64_t> expected;
    uint8_t* device_input = nullptr;
    uint64_t* device_output = nullptr;

    explicit GpSingleProblem(std::string input_path)
        : path(std::move(input_path)), input(gp4ReadFile(path)), expected(gp4CpuStructuralBitmap(input)) {
        device_input = gpSingleAllocate<uint8_t>(input.size());
        device_output = gpSingleAllocate<uint64_t>(expected.size());
        if (!input.empty()) GP4_CUDA_CHECK(cudaMemcpy(device_input, input.data(), input.size(), cudaMemcpyHostToDevice));
    }

    ~GpSingleProblem() {
        cudaFree(device_input);
        cudaFree(device_output);
    }

    GpSingleProblem(const GpSingleProblem&) = delete;
    GpSingleProblem& operator=(const GpSingleProblem&) = delete;
};

struct GpSingleValidation {
    uint64_t gpu_hash = 0u;
    uint64_t cpu_hash = 0u;
    std::size_t matching_words = 0u;
    std::size_t total_words = 0u;
    std::size_t first_mismatch = 0u;
    bool correct = false;

    double wordAccuracy() const {
        return total_words == 0u ? 100.0 : 100.0 * static_cast<double>(matching_words) / static_cast<double>(total_words);
    }
};

inline GpSingleValidation gpSingleValidate(const GpSingleProblem& problem) {
    std::vector<uint64_t> actual(problem.expected.size());
    if (!actual.empty()) GP4_CUDA_CHECK(cudaMemcpy(actual.data(), problem.device_output,
        actual.size() * sizeof(uint64_t), cudaMemcpyDeviceToHost));

    GpSingleValidation result;
    result.gpu_hash = gp4HashWords(actual);
    result.cpu_hash = gp4HashWords(problem.expected);
    result.total_words = actual.size();
    result.first_mismatch = actual.size();
    for (std::size_t word = 0; word < actual.size(); ++word) {
        if (actual[word] == problem.expected[word]) ++result.matching_words;
        else if (result.first_mismatch == actual.size()) result.first_mismatch = word;
    }
    result.correct = result.matching_words == result.total_words;
    return result;
}

template <typename Launch>
double gpSingleBenchmark(Launch launch, int runs) {
    for (int warmup = 0; warmup < GP_SINGLE_WARMUPS; ++warmup) {
        launch();
        GP4_CUDA_CHECK(cudaGetLastError());
    }
    GP4_CUDA_CHECK(cudaDeviceSynchronize());

    cudaEvent_t start = nullptr;
    cudaEvent_t stop = nullptr;
    GP4_CUDA_CHECK(cudaEventCreate(&start));
    GP4_CUDA_CHECK(cudaEventCreate(&stop));
    double total_ms = 0.0;
    for (int run = 0; run < runs; ++run) {
        GP4_CUDA_CHECK(cudaEventRecord(start));
        launch();
        GP4_CUDA_CHECK(cudaGetLastError());
        GP4_CUDA_CHECK(cudaEventRecord(stop));
        GP4_CUDA_CHECK(cudaEventSynchronize(stop));
        float elapsed_ms = 0.0f;
        GP4_CUDA_CHECK(cudaEventElapsedTime(&elapsed_ms, start, stop));
        total_ms += elapsed_ms;
    }
    GP4_CUDA_CHECK(cudaEventDestroy(start));
    GP4_CUDA_CHECK(cudaEventDestroy(stop));
    return total_ms / static_cast<double>(runs);
}

inline int gpSingleRuns(int argc, char** argv) {
    if (argc < 2 || argc > 3) {
        std::cerr << "usage: " << argv[0] << " INPUT [RUNS]\n";
        return 0;
    }
    return argc == 3 ? std::max(1, std::atoi(argv[2])) : 5;
}

inline void gpSinglePrint(const char* method, const GpSingleProblem& problem, int runs,
                          double average_ms, const GpSingleValidation& validation,
                          const char* expected_correctness = "PASS",
                          int grid = GP4_ORIGINAL_GRID,
                          int block = GP4_ORIGINAL_BLOCK) {
    std::cout << std::fixed << std::setprecision(6)
              << "method=" << method << " dataset=" << problem.path
              << " bytes=" << problem.input.size() << " words64=" << problem.expected.size()
              << " grid=" << grid << " block=" << block
              << " runs=" << runs << " warmups=" << GP_SINGLE_WARMUPS
              << " avg_ms=" << average_ms << " expected_correct=" << expected_correctness
              << " correct=" << (validation.correct ? "PASS" : "FAIL")
              << " word_accuracy=" << validation.wordAccuracy() << "%"
              << " gpu_hash=0x" << std::hex << validation.gpu_hash
              << " cpu_hash=0x" << validation.cpu_hash << std::dec;
    if (!validation.correct) std::cout << " first_mismatch_word=" << validation.first_mismatch;
    std::cout << '\n';
}
