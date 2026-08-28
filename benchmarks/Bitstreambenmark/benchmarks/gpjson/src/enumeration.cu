#include "control_common.cuh"

#include <cuda/atomic>
#include <cuda_runtime.h>

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <string>
#include <vector>

constexpr uint32_t ENUMERATION_WARMUPS = 2u;

template <typename T>
static T* allocateDevice(std::size_t count) {
    T* pointer = nullptr;
    GP_CUDA_CHECK(cudaMalloc(&pointer, std::max<std::size_t>(count, 1u) * sizeof(T)));
    return pointer;
}

__global__ void gpjsonPerThreadEnumerationKernel(const uint8_t* input, uint64_t input_size,
    uint64_t word_count, volatile uint64_t* slash_bitmap, volatile uint64_t* real_quote_bitmap,
    volatile uint64_t* in_string_bitmap, uint64_t* structural_bitmap,
    uint32_t* slash_ready, uint32_t* in_string_ready, uint32_t epoch) {
    uint64_t word_id = static_cast<uint64_t>(blockIdx.x) * blockDim.x + threadIdx.x;
    if (word_id >= word_count) return;

    // Classify this 64-byte word once. The raw quote and structural masks remain
    // local; the slash mask is materialized because another thread validates from it.
    uint64_t slash_word = 0ull, quote_word = 0ull, structural_word = 0ull;
    gpClassifyWord(input, input_size, word_id, slash_word, quote_word, structural_word);
    slash_bitmap[word_id] = slash_word;
    cuda::atomic_ref<uint32_t, cuda::thread_scope_device> my_slash_ready(slash_ready[word_id]);
    my_slash_ready.store(epoch, cuda::memory_order_release);

    // Enumerate both possible incoming escape states before validation.
    uint64_t real_quote_if_escape_zero = gpFilterEscapedQuotes64(quote_word, slash_word, 0u);
    uint64_t real_quote_if_escape_one = gpFilterEscapedQuotes64(quote_word, slash_word, 1u);

    // Resolve the actual incoming escape by reading predecessor slash payloads
    // from global memory. A full-slash word extends the lookup farther backward.
    uint32_t incoming_escape = 0u;
    int64_t previous_word = static_cast<int64_t>(word_id) - 1;
    while (previous_word >= 0) {
        uint64_t previous_id = static_cast<uint64_t>(previous_word);
        cuda::atomic_ref<uint32_t, cuda::thread_scope_device> previous_ready(slash_ready[previous_id]);
        while (previous_ready.load(cuda::memory_order_acquire) != epoch) __nanosleep(64u);
        uint64_t previous_slashes = slash_bitmap[previous_id];
        if (previous_slashes != 0xffffffffffffffffull) {
            incoming_escape = static_cast<uint32_t>(__clzll(~previous_slashes)) & 1u;
            break;
        }
        --previous_word;
    }

    uint64_t real_quote = incoming_escape == 0u ? real_quote_if_escape_zero : real_quote_if_escape_one;
    real_quote_bitmap[word_id] = real_quote;

    // Enumerate both possible incoming in-string states. Validation only selects
    // one candidate after the predecessor has published its actual bitmap.
    uint64_t in_string_if_zero = gpPrefixXor64(real_quote);
    uint64_t in_string_if_one = ~in_string_if_zero;
    uint32_t active_lanes = __activemask();
    bool published = false;
    while (true) {
        bool predecessor_ready = word_id == 0u;
        uint32_t incoming_string = 0u;
        if (!published && !predecessor_ready) {
            cuda::atomic_ref<uint32_t, cuda::thread_scope_device> previous_ready(in_string_ready[word_id - 1u]);
            if (previous_ready.load(cuda::memory_order_acquire) == epoch) {
                incoming_string = static_cast<uint32_t>(in_string_bitmap[word_id - 1u] >> 63u);
                predecessor_ready = true;
            }
        }
        if (!published && predecessor_ready) {
            uint64_t in_string = incoming_string == 0u ? in_string_if_zero : in_string_if_one;
            in_string_bitmap[word_id] = in_string;
            cuda::atomic_ref<uint32_t, cuda::thread_scope_device> my_ready(in_string_ready[word_id]);
            my_ready.store(epoch, cuda::memory_order_release);
            published = true;
        }
        if (__all_sync(active_lanes, published)) break;
        __nanosleep(64u);
    }

    // Reload the selected global payload before producing GPJSON's final bitmap.
    uint64_t actual_in_string = in_string_bitmap[word_id];
    structural_bitmap[word_id] = structural_word & ~actual_in_string;
}

static cudaError_t launchEnumeration(const uint8_t* input, uint64_t input_size,
    uint64_t word_count, uint64_t* slash_bitmap, uint64_t* real_quote_bitmap,
    uint64_t* in_string_bitmap, uint64_t* structural_bitmap,
    uint32_t* slash_ready, uint32_t* in_string_ready, uint32_t epoch,
    uint32_t grid_size) {
    gpjsonPerThreadEnumerationKernel<<<grid_size, GP_THREADS>>>(input, input_size, word_count,
        slash_bitmap, real_quote_bitmap, in_string_bitmap, structural_bitmap,
        slash_ready, in_string_ready, epoch);
    return cudaGetLastError();
}

int main(int argc, char** argv) {
    if (argc < 2 || argc > 3) {
        std::cerr << "usage: " << argv[0] << " INPUT [RUNS]\n";
        return EXIT_FAILURE;
    }
    int runs = 5;
    if (argc == 3 && !gpParsePositiveInt(argv[2], runs)) {
        std::cerr << "RUNS must be a positive integer\n";
        return EXIT_FAILURE;
    }
    if (static_cast<uint64_t>(runs) + ENUMERATION_WARMUPS + 1u > 0xffffffffull) {
        std::cerr << "RUNS exceeds the readiness-epoch range\n";
        return EXIT_FAILURE;
    }

    GpHostBatch batch;
    try {
        batch = gpLoadBatch({std::string(argv[1])});
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return EXIT_FAILURE;
    }
    const GpHostInput& host_input = batch.inputs.front();
    uint64_t word_count = host_input.word_count;
    uint64_t logical_grid = (word_count + GP_THREADS - 1u) / GP_THREADS;
    if (logical_grid > 0x7fffffffull) {
        std::cerr << "input requires too many thread blocks\n";
        return EXIT_FAILURE;
    }
    uint32_t launch_grid = static_cast<uint32_t>(std::max<uint64_t>(logical_grid, 1u));

    uint8_t* device_input = allocateDevice<uint8_t>(batch.bytes.size());
    uint64_t* device_slash = allocateDevice<uint64_t>(word_count);
    uint64_t* device_real_quote = allocateDevice<uint64_t>(word_count);
    uint64_t* device_in_string = allocateDevice<uint64_t>(word_count);
    uint64_t* device_structural = allocateDevice<uint64_t>(word_count);
    uint32_t* device_slash_ready = allocateDevice<uint32_t>(word_count);
    uint32_t* device_in_string_ready = allocateDevice<uint32_t>(word_count);
    GP_CUDA_CHECK(cudaMemcpy(device_input, batch.bytes.data(), batch.bytes.size(), cudaMemcpyHostToDevice));
    GP_CUDA_CHECK(cudaMemset(device_slash_ready, 0, std::max<uint64_t>(word_count, 1u) * sizeof(uint32_t)));
    GP_CUDA_CHECK(cudaMemset(device_in_string_ready, 0, std::max<uint64_t>(word_count, 1u) * sizeof(uint32_t)));

    uint32_t epoch = 1u;
    for (uint32_t warmup = 0u; warmup < ENUMERATION_WARMUPS; ++warmup)
        GP_CUDA_CHECK(launchEnumeration(device_input, host_input.byte_size, word_count,
            device_slash, device_real_quote, device_in_string, device_structural,
            device_slash_ready, device_in_string_ready, epoch++, launch_grid));
    GP_CUDA_CHECK(cudaDeviceSynchronize());

    cudaEvent_t start = nullptr, stop = nullptr;
    GP_CUDA_CHECK(cudaEventCreate(&start));
    GP_CUDA_CHECK(cudaEventCreate(&stop));
    double total_ms = 0.0;
    for (int run = 0; run < runs; ++run) {
        GP_CUDA_CHECK(cudaEventRecord(start));
        GP_CUDA_CHECK(launchEnumeration(device_input, host_input.byte_size, word_count,
            device_slash, device_real_quote, device_in_string, device_structural,
            device_slash_ready, device_in_string_ready, epoch++, launch_grid));
        GP_CUDA_CHECK(cudaEventRecord(stop));
        GP_CUDA_CHECK(cudaEventSynchronize(stop));
        float elapsed_ms = 0.0f;
        GP_CUDA_CHECK(cudaEventElapsedTime(&elapsed_ms, start, stop));
        total_ms += elapsed_ms;
    }

    std::vector<uint64_t> structural(static_cast<std::size_t>(std::max<uint64_t>(word_count, 1u)), 0ull);
    if (word_count != 0u) GP_CUDA_CHECK(cudaMemcpy(structural.data(), device_structural,
        static_cast<std::size_t>(word_count) * sizeof(uint64_t), cudaMemcpyDeviceToHost));
    uint64_t checksum = 0u;
    bool correct = gpCheckOutput(batch, structural, checksum);
    std::cout << std::fixed << std::setprecision(3)
              << "method=gpjson_enumeration inputs=1 bytes=" << host_input.byte_size
              << " words64=" << word_count << " grid=" << logical_grid
              << " block=" << GP_THREADS << " runs=" << runs
              << " avg_us=" << total_ms * 1000.0 / runs
              << " outputs_correct=" << (correct ? "PASS" : "FAIL")
              << " checksum=" << checksum << '\n';

    GP_CUDA_CHECK(cudaEventDestroy(start));
    GP_CUDA_CHECK(cudaEventDestroy(stop));
    GP_CUDA_CHECK(cudaFree(device_input));
    GP_CUDA_CHECK(cudaFree(device_slash));
    GP_CUDA_CHECK(cudaFree(device_real_quote));
    GP_CUDA_CHECK(cudaFree(device_in_string));
    GP_CUDA_CHECK(cudaFree(device_structural));
    GP_CUDA_CHECK(cudaFree(device_slash_ready));
    GP_CUDA_CHECK(cudaFree(device_in_string_ready));
    return correct ? EXIT_SUCCESS : EXIT_FAILURE;
}

#undef GP_CUDA_CHECK
