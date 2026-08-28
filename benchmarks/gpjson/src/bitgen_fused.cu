#include "control_common.cuh"

// One CTA owns one complete input. Each 1,024-word tile passes slash, quote,
// and in-string values directly from one GPJSON stage to the next.
__global__ void bitgenFusedKernel(const uint8_t* all_input,
    const GpInputDescriptor* descriptors, uint64_t* structural_bitmap) {
    __shared__ uint64_t shared_slashes[GP_WORDS_PER_TILE];
    __shared__ uint32_t shared_warp_quote_parity[GP_WARPS_PER_TILE];
    __shared__ uint32_t previous_tile_escape;
    __shared__ uint32_t previous_tile_quote_parity;
    GpInputDescriptor input = descriptors[blockIdx.x];
    const uint8_t* bytes = all_input + input.byte_offset;
    if (threadIdx.x == 0u) {
        previous_tile_escape = 0u;
        previous_tile_quote_parity = 0u;
    }

    for (uint64_t tile_start = 0u; tile_start < input.padded_word_count; tile_start += GP_WORDS_PER_TILE) {
        uint64_t word_id = tile_start + threadIdx.x;
        uint64_t slash_word, quote_word, structural_word;
        gpClassifyWord(bytes, input.byte_size, word_id, slash_word, quote_word, structural_word);

        shared_slashes[threadIdx.x] = slash_word;
        // This also publishes the previous iteration's two carry updates.
        __syncthreads();
        uint32_t old_tile_escape = previous_tile_escape;
        uint32_t old_tile_parity = previous_tile_quote_parity;
        uint32_t incoming_escape = gpIncomingEscape(shared_slashes, old_tile_escape);
        uint64_t real_quote = gpFilterEscapedQuotes64(quote_word, slash_word, incoming_escape);
        uint32_t outgoing_escape = gpOutgoingEscape(slash_word, incoming_escape);

        uint32_t word_quote_parity = static_cast<uint32_t>(__popcll(real_quote)) & 1u;
        uint32_t inclusive_quote_parity = gpWarpInclusiveXorScan1024(
            word_quote_parity, shared_warp_quote_parity);
        uint32_t parity_before_word = old_tile_parity ^ inclusive_quote_parity ^ word_quote_parity;
        uint64_t in_string = gpPrefixXor64(real_quote);
        if (parity_before_word != 0u) in_string = ~in_string;
        structural_bitmap[input.word_offset + word_id] = structural_word & ~in_string;

        // Delay both writes until all threads have snapshotted the old carries.
        // The slash barrier at the start of the next iteration publishes them.
        if (threadIdx.x == GP_WORDS_PER_TILE - 1u) previous_tile_escape = outgoing_escape;
        if (threadIdx.x == 0u)
            previous_tile_quote_parity = old_tile_parity ^
                shared_warp_quote_parity[GP_WARPS_PER_TILE - 1u];
    }
}

int main(int argc, char** argv) {
    if (argc < 3) {
        std::cerr << "usage: " << argv[0] << " RUNS file1 [file2 ...]\n";
        return EXIT_FAILURE;
    }
    int runs = 0;
    if (!gpParsePositiveInt(argv[1], runs)) {
        std::cerr << "RUNS must be a positive integer\n";
        return EXIT_FAILURE;
    }

    std::vector<std::string> paths(argv + 2, argv + argc);
    GpHostBatch batch;
    try {
        batch = gpLoadBatch(paths);
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return EXIT_FAILURE;
    }

    size_t input_bytes = batch.bytes.size();
    size_t bitmap_words = static_cast<size_t>(std::max<uint64_t>(batch.total_padded_words, 1u));
    size_t bitmap_bytes = bitmap_words * sizeof(uint64_t);
    uint8_t* device_input = nullptr;
    GpInputDescriptor* device_descriptors = nullptr;
    uint64_t* device_structural = nullptr;
    GP_CUDA_CHECK(cudaMalloc(&device_input, input_bytes));
    GP_CUDA_CHECK(cudaMalloc(&device_descriptors, batch.descriptors.size() * sizeof(GpInputDescriptor)));
    GP_CUDA_CHECK(cudaMalloc(&device_structural, bitmap_bytes));
    GP_CUDA_CHECK(cudaMemcpy(device_input, batch.bytes.data(), input_bytes, cudaMemcpyHostToDevice));
    GP_CUDA_CHECK(cudaMemcpy(device_descriptors, batch.descriptors.data(),
                             batch.descriptors.size() * sizeof(GpInputDescriptor), cudaMemcpyHostToDevice));

    uint32_t input_count = static_cast<uint32_t>(batch.inputs.size());
    for (int warmup = 0; warmup < 3; ++warmup)
        bitgenFusedKernel<<<input_count, GP_THREADS>>>(device_input, device_descriptors, device_structural);
    GP_CUDA_CHECK(cudaDeviceSynchronize());

    cudaEvent_t start, stop;
    GP_CUDA_CHECK(cudaEventCreate(&start));
    GP_CUDA_CHECK(cudaEventCreate(&stop));
    double total_ms = 0.0;
    for (int run = 0; run < runs; ++run) {
        GP_CUDA_CHECK(cudaEventRecord(start));
        bitgenFusedKernel<<<input_count, GP_THREADS>>>(device_input, device_descriptors, device_structural);
        GP_CUDA_CHECK(cudaEventRecord(stop));
        GP_CUDA_CHECK(cudaEventSynchronize(stop));
        GP_CUDA_CHECK(cudaGetLastError());
        float elapsed_ms = 0.0f;
        GP_CUDA_CHECK(cudaEventElapsedTime(&elapsed_ms, start, stop));
        total_ms += elapsed_ms;
    }

    std::vector<uint64_t> output(bitmap_words, 0ull);
    if (batch.total_padded_words != 0u)
        GP_CUDA_CHECK(cudaMemcpy(output.data(), device_structural,
                                 static_cast<size_t>(batch.total_padded_words) * sizeof(uint64_t),
                                 cudaMemcpyDeviceToHost));
    uint64_t checksum = 0u;
    bool correct = gpCheckOutput(batch, output, checksum);
    gpPrintResult("gpjson_bitgen_fused", batch, runs, total_ms / runs, correct, checksum);

    GP_CUDA_CHECK(cudaEventDestroy(start));
    GP_CUDA_CHECK(cudaEventDestroy(stop));
    GP_CUDA_CHECK(cudaFree(device_structural));
    GP_CUDA_CHECK(cudaFree(device_descriptors));
    GP_CUDA_CHECK(cudaFree(device_input));
    return correct ? EXIT_SUCCESS : EXIT_FAILURE;
}
