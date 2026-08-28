#include "hierarchical_common.cuh"

#include <cub/device/device_scan.cuh>
#include <thrust/iterator/counting_iterator.h>
#include <thrust/iterator/transform_iterator.h>

#include <algorithm>
#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <string>
#include <vector>

struct QuoteParityMaskInput {
    const uint32_t* quote_parity_masks;

    __host__ __device__ uint8_t operator()(uint32_t warp_id) const {
        uint32_t value = quote_parity_masks[warp_id];
        value ^= value >> 16u;
        value ^= value >> 8u;
        value ^= value >> 4u;
        value ^= value >> 2u;
        value ^= value >> 1u;
        return static_cast<uint8_t>(value & 1u);
    }
};

struct QuoteParityXor {
    __host__ __device__ uint8_t operator()(uint8_t left, uint8_t right) const {
        return static_cast<uint8_t>(left ^ right);
    }
};

// F1 classifies each 32-byte word once and enumerates both possible results
// for the incoming slash state. Both candidates survive in GM until F2 selects.
__global__ void enumerateSlashCandidatesKernel(const uint8_t* input, uint64_t input_size,
    uint32_t* operator_bitmap, uint32_t* raw_open_close,
    uint32_t* structural_if_slash_zero, uint32_t* structural_if_slash_one,
    uint8_t* trailing_slashes, uint32_t* quote_parity_if_slash_zero,
    uint32_t* quote_parity_if_slash_one, uint32_t* utf_error) {
    uint32_t word_id = blockIdx.x * blockDim.x + threadIdx.x;
    const uint32_t* input_words = reinterpret_cast<const uint32_t*>(input);
    uint32_t first_input_word_id = word_id * 8u;
    const uint4* input_vectors = reinterpret_cast<const uint4*>(input);
    uint4 first_vector = input_vectors[word_id * 2u];
    uint4 second_vector = input_vectors[word_id * 2u + 1u];
    uint32_t loaded_words[8] = {first_vector.x, first_vector.y, first_vector.z, first_vector.w,
                                second_vector.x, second_vector.y, second_vector.z, second_vector.w};

    uint32_t thread_utf_error = 0u;
    #pragma unroll
    for (uint32_t part = 0u; part < 8u; ++part) {
        uint32_t input_word_id = first_input_word_id + part;
        uint32_t current = loaded_words[part];
        uint32_t previous = input_word_id == 0u ? 0u :
            (part == 0u ? input_words[input_word_id - 1u] : loaded_words[part - 1u]);
        if (((current | previous) & 0x80808080u) != 0u)
            thread_utf_error |= fullCujsonValidateUtf8FourBytes(current, previous);
    }
    if (thread_utf_error != 0u) atomicOr(utf_error, thread_utf_error);

    uint32_t slash_word = 0u;
    uint32_t current_quote = 0u;
    uint32_t operator_word = 0u;
    uint32_t open_close_word = 0u;
    #pragma unroll
    for (uint32_t part = 0u; part < 8u; ++part) {
        uint32_t current = loaded_words[part];
        uint32_t slash = __vcmpeq4(current, 0x5c5c5c5cu) & 0x01010101u;
        uint32_t quote = __vcmpeq4(current, 0x22222222u) & 0x01010101u;
        uint32_t open_close = (__vcmpeq4(current, 0x5b5b5b5bu) | __vcmpeq4(current, 0x5d5d5d5du) |
                               __vcmpeq4(current, 0x7b7b7b7bu) | __vcmpeq4(current, 0x7d7d7d7du)) & 0x01010101u;
        uint32_t colon_comma = (__vcmpeq4(current, 0x3a3a3a3au) |
                                __vcmpeq4(current, 0x2c2c2c2cu)) & 0x01010101u;
        slash_word |= fullPackMatches(slash) << (part * 4u);
        current_quote |= fullPackMatches(quote) << (part * 4u);
        open_close_word |= fullPackMatches(open_close) << (part * 4u);
        operator_word |= fullPackMatches(open_close | colon_comma) << (part * 4u);
    }

    uint64_t byte_start = static_cast<uint64_t>(word_id) * 32u;
    uint64_t bytes_left = byte_start < input_size ? input_size - byte_start : 0u;
    if (bytes_left < 32u) {
        uint32_t valid_mask = bytes_left == 0u ? 0u : 0xffffffffu >> (32u - bytes_left);
        slash_word &= valid_mask;
        current_quote &= valid_mask;
        operator_word &= valid_mask;
        open_close_word &= valid_mask;
    }

    trailing_slashes[word_id] = static_cast<uint8_t>(__clz(~slash_word));
    uint32_t possible_escape = current_quote & ((slash_word << 1u) | 1u);
    uint32_t real_quote_if_slash_zero = possible_escape == 0u ? current_quote :
        fullFilterEscapedQuotesWord(current_quote, slash_word, 0u);
    uint32_t real_quote_if_slash_one = possible_escape == 0u ? current_quote :
        fullFilterEscapedQuotesWord(current_quote, slash_word, 1u);
    uint32_t local_in_string_if_slash_zero = fullPrefixXorWord(real_quote_if_slash_zero);
    uint32_t local_in_string_if_slash_one = fullPrefixXorWord(real_quote_if_slash_one);

    operator_bitmap[word_id] = operator_word;
    raw_open_close[word_id] = open_close_word;
    structural_if_slash_zero[word_id] = ~local_in_string_if_slash_zero & operator_word;
    structural_if_slash_one[word_id] = ~local_in_string_if_slash_one & operator_word;

    uint32_t parity_zero = static_cast<uint32_t>(__popc(real_quote_if_slash_zero) & 1u);
    uint32_t parity_one = static_cast<uint32_t>(__popc(real_quote_if_slash_one) & 1u);
    uint32_t parity_zero_mask = __ballot_sync(0xffffffffu, parity_zero != 0u);
    uint32_t parity_one_mask = __ballot_sync(0xffffffffu, parity_one != 0u);
    if ((threadIdx.x & 31u) == 0u) {
        uint32_t warp_id = word_id >> 5u;
        quote_parity_if_slash_zero[warp_id] = parity_zero_mask;
        quote_parity_if_slash_one[warp_id] = parity_one_mask;
    }
}

// F2 resolves the incoming slash state from completed F1 summaries and only
// selects a precomputed candidate. It performs no input reread or recovery.
__global__ void resolveAndSelectSlashCandidateKernel(const uint8_t* trailing_slashes,
    uint32_t word_count, uint32_t* structural_if_slash_zero,
    const uint32_t* structural_if_slash_one, uint32_t* quote_parity_if_slash_zero,
    const uint32_t* quote_parity_if_slash_one) {
    uint32_t word_id = blockIdx.x * blockDim.x + threadIdx.x;
    uint32_t incoming_slash = 0u;
    if (word_id < word_count && word_id != 0u) {
        int32_t previous = static_cast<int32_t>(word_id) - 1;
        uint8_t previous_trailing_slashes = trailing_slashes[previous];
        while (previous_trailing_slashes == 32u && previous != 0) {
            --previous;
            previous_trailing_slashes = trailing_slashes[previous];
        }
        incoming_slash = static_cast<uint32_t>(previous_trailing_slashes & 1u);
    }

    if (incoming_slash != 0u)
        structural_if_slash_zero[word_id] = structural_if_slash_one[word_id];

    uint32_t incoming_mask = __ballot_sync(0xffffffffu, incoming_slash != 0u);
    uint32_t lane = threadIdx.x & 31u;
    if (lane == 0u) {
        uint32_t warp_id = word_id >> 5u;
        uint32_t parity_zero_mask = quote_parity_if_slash_zero[warp_id];
        uint32_t parity_one_mask = quote_parity_if_slash_one[warp_id];
        quote_parity_if_slash_zero[warp_id] =
            (parity_zero_mask & ~incoming_mask) | (parity_one_mask & incoming_mask);
    }
}

// F3 resolves the incoming quote parity and selects the corresponding final
// bitmap. The state-one candidate equals state-zero XOR operator_bitmap.
__global__ void selectInStringCandidateKernel(const uint32_t* selected_quote_parity_masks,
    const uint8_t* quote_warp_prefix, const uint32_t* operator_bitmap,
    const uint32_t* raw_open_close, uint32_t* selected_structural_bitmap,
    uint32_t* filtered_open_close, uint32_t* structural_counts,
    uint32_t* open_close_counts) {
    uint32_t word_id = blockIdx.x * blockDim.x + threadIdx.x;
    uint32_t lane = threadIdx.x & 31u;
    uint32_t warp_id = word_id >> 5u;
    uint32_t parity_mask = selected_quote_parity_masks[warp_id];
    uint32_t lower_lanes = lane == 0u ? 0u : ((1u << lane) - 1u);
    uint32_t incoming_string = static_cast<uint32_t>(quote_warp_prefix[warp_id]) ^
        static_cast<uint32_t>(__popc(parity_mask & lower_lanes) & 1u);
    uint32_t select_state_one = 0u - incoming_string;
    uint32_t structural = selected_structural_bitmap[word_id] ^
        (operator_bitmap[word_id] & select_state_one);
    uint32_t current_filtered_open_close = structural & raw_open_close[word_id];
    selected_structural_bitmap[word_id] = structural;
    filtered_open_close[word_id] = current_filtered_open_close;
    structural_counts[word_id] = static_cast<uint32_t>(__popc(structural));
    open_close_counts[word_id] = static_cast<uint32_t>(__popc(current_filtered_open_close));
}

constexpr uint64_t FNV_OFFSET = 1469598103934665603ull;
constexpr uint64_t FNV_PRIME = 1099511628211ull;

#define CUDA_CHECK(call) do { cudaError_t status_ = (call); if (status_ != cudaSuccess) { \
    std::cerr << "CUDA error at " << __FILE__ << ':' << __LINE__ << ": " \
              << cudaGetErrorString(status_) << '\n'; std::exit(EXIT_FAILURE); } } while (0)

struct HierarchicalEnumerationInput {
    std::string path;
    uint64_t input_size = 0u;
    uint32_t word_count = 0u;
    uint32_t blocks = 0u;
    uint32_t padded_words = 0u;
    uint32_t padded_warps = 0u;
    std::vector<uint8_t> host_input;
    uint8_t* input = nullptr;
    uint32_t* operators = nullptr;
    uint32_t* raw_open_close = nullptr;
    uint32_t* structural = nullptr;
    uint32_t* structural_if_slash_one = nullptr;
    uint32_t* filtered_open_close = nullptr;
    uint32_t* structural_counts = nullptr;
    uint32_t* open_close_counts = nullptr;
    uint32_t* utf_error = nullptr;
    uint32_t* quote_parity_masks = nullptr;
    uint32_t* quote_parity_masks_if_slash_one = nullptr;
    uint8_t* trailing_slashes = nullptr;
    uint8_t* quote_warp_prefix = nullptr;
    void* scan_storage = nullptr;
    size_t scan_bytes = 0u;
    cudaStream_t stream = nullptr;
};

static cudaError_t launchHierarchicalEnumeration(HierarchicalEnumerationInput& input) {
    auto selected_quote_parity = thrust::make_transform_iterator(
        thrust::make_counting_iterator(0u), QuoteParityMaskInput{input.quote_parity_masks});
    enumerateSlashCandidatesKernel<<<input.blocks, FULL_THREADS, 0, input.stream>>>(input.input,
        input.input_size, input.operators, input.raw_open_close, input.structural,
        input.structural_if_slash_one, input.trailing_slashes, input.quote_parity_masks,
        input.quote_parity_masks_if_slash_one, input.utf_error);
    resolveAndSelectSlashCandidateKernel<<<input.blocks, FULL_THREADS, 0, input.stream>>>(
        input.trailing_slashes, input.word_count, input.structural,
        input.structural_if_slash_one, input.quote_parity_masks,
        input.quote_parity_masks_if_slash_one);
    cudaError_t status = cub::DeviceScan::ExclusiveScan(input.scan_storage, input.scan_bytes,
        selected_quote_parity, input.quote_warp_prefix, QuoteParityXor{},
        static_cast<uint8_t>(0u), input.padded_warps, input.stream);
    if (status != cudaSuccess) return status;
    selectInStringCandidateKernel<<<input.blocks, FULL_THREADS, 0, input.stream>>>(
        input.quote_parity_masks, input.quote_warp_prefix, input.operators,
        input.raw_open_close, input.structural, input.filtered_open_close,
        input.structural_counts, input.open_close_counts);
    return cudaGetLastError();
}

static bool validUtf8(const uint8_t* data, uint64_t size) {
    uint64_t position = 0u;
    while (position < size) {
        uint8_t first = data[position++];
        if (first < 0x80u) continue;
        uint32_t continuation_count = 0u;
        uint8_t second_min = 0x80u, second_max = 0xbfu;
        if (first >= 0xc2u && first <= 0xdfu) continuation_count = 1u;
        else if (first >= 0xe0u && first <= 0xefu) {
            continuation_count = 2u;
            if (first == 0xe0u) second_min = 0xa0u;
            if (first == 0xedu) second_max = 0x9fu;
        } else if (first >= 0xf0u && first <= 0xf4u) {
            continuation_count = 3u;
            if (first == 0xf0u) second_min = 0x90u;
            if (first == 0xf4u) second_max = 0x8fu;
        } else return false;
        if (position + continuation_count > size) return false;
        if (data[position] < second_min || data[position] > second_max) return false;
        ++position;
        for (uint32_t continuation = 1u; continuation < continuation_count; ++continuation, ++position)
            if (data[position] < 0x80u || data[position] > 0xbfu) return false;
    }
    return true;
}

static void makeCpuReference(const uint8_t* data, uint64_t size, uint32_t word_count,
    std::vector<uint32_t>& structural, std::vector<uint32_t>& open_close) {
    structural.assign(word_count, 0u);
    open_close.assign(word_count, 0u);
    bool in_string = false;
    uint32_t slash_run = 0u;
    for (uint64_t position = 0u; position < size; ++position) {
        uint8_t byte = data[position];
        bool real_quote = byte == static_cast<uint8_t>('"') && (slash_run & 1u) == 0u;
        if (real_quote) in_string = !in_string;
        bool is_open_close = byte == '[' || byte == ']' || byte == '{' || byte == '}';
        bool is_operator = is_open_close || byte == ':' || byte == ',';
        uint32_t bit = 1u << (position & 31u);
        uint32_t word = static_cast<uint32_t>(position >> 5u);
        if (!in_string && is_operator) structural[word] |= bit;
        if (!in_string && is_open_close) open_close[word] |= bit;
        slash_run = byte == static_cast<uint8_t>('\\') ? slash_run + 1u : 0u;
    }
}

static uint64_t hashWords(const uint32_t* words, uint32_t count) {
    uint64_t hash = FNV_OFFSET;
    for (uint32_t word = 0u; word < count; ++word) {
        hash ^= words[word];
        hash *= FNV_PRIME;
    }
    return hash;
}

static uint64_t appendHash(uint64_t hash, uint64_t value) {
    hash ^= value;
    return hash * FNV_PRIME;
}

static bool parsePositiveInt(const char* text, int& value) {
    char* end = nullptr;
    long parsed = std::strtol(text, &end, 10);
    if (end == text || *end != '\0' || parsed <= 0 || parsed > std::numeric_limits<int>::max()) return false;
    value = static_cast<int>(parsed);
    return true;
}

int main(int argc, char** argv) {
    if (argc < 3) {
        std::cerr << "usage: " << argv[0] << " RUNS file1.json [file2.json ...]\n";
        return EXIT_FAILURE;
    }
    int runs = 0;
    if (!parsePositiveInt(argv[1], runs)) {
        std::cerr << "RUNS must be a positive integer\n";
        return EXIT_FAILURE;
    }

    std::vector<HierarchicalEnumerationInput> inputs(static_cast<size_t>(argc - 2));
    uint64_t total_blocks = 0u;
    for (int argument = 2; argument < argc; ++argument) {
        HierarchicalEnumerationInput& input = inputs[static_cast<size_t>(argument - 2)];
        input.path = argv[argument];
        std::ifstream file(input.path, std::ios::binary | std::ios::ate);
        if (!file) {
            std::cerr << "cannot open " << input.path << '\n';
            return EXIT_FAILURE;
        }
        std::streamoff end = file.tellg();
        if (end < 0) return EXIT_FAILURE;
        input.input_size = static_cast<uint64_t>(end);
        uint64_t words_64 = (input.input_size + 31u) / 32u;
        if (words_64 > std::numeric_limits<uint32_t>::max()) {
            std::cerr << "input exceeds the 32-bit word range\n";
            return EXIT_FAILURE;
        }
        input.word_count = static_cast<uint32_t>(words_64);
        uint64_t padded_words_64 = ((words_64 + 1u + FULL_THREADS - 1u) / FULL_THREADS) * FULL_THREADS;
        if (padded_words_64 > std::numeric_limits<uint32_t>::max()) {
            std::cerr << "padded input exceeds the 32-bit word range\n";
            return EXIT_FAILURE;
        }
        input.padded_words = static_cast<uint32_t>(padded_words_64);
        input.blocks = input.padded_words / FULL_THREADS;
        input.padded_warps = input.padded_words / 32u;
        total_blocks += input.blocks;

        size_t padded_size = static_cast<size_t>(input.padded_words) * 32u;
        size_t bitmap_bytes = static_cast<size_t>(input.padded_words) * sizeof(uint32_t);
        input.host_input.assign(padded_size, 0u);
        file.seekg(0);
        file.read(reinterpret_cast<char*>(input.host_input.data()),
                  static_cast<std::streamsize>(input.input_size));
        if (!file && input.input_size != 0u) {
            std::cerr << "failed to read " << input.path << '\n';
            return EXIT_FAILURE;
        }

        CUDA_CHECK(cudaStreamCreateWithFlags(&input.stream, cudaStreamNonBlocking));
        CUDA_CHECK(cudaMalloc(&input.input, padded_size));
        CUDA_CHECK(cudaMalloc(&input.operators, bitmap_bytes));
        CUDA_CHECK(cudaMalloc(&input.raw_open_close, bitmap_bytes));
        CUDA_CHECK(cudaMalloc(&input.structural, bitmap_bytes));
        CUDA_CHECK(cudaMalloc(&input.structural_if_slash_one, bitmap_bytes));
        CUDA_CHECK(cudaMalloc(&input.filtered_open_close, bitmap_bytes));
        CUDA_CHECK(cudaMalloc(&input.structural_counts, bitmap_bytes));
        CUDA_CHECK(cudaMalloc(&input.open_close_counts, bitmap_bytes));
        CUDA_CHECK(cudaMalloc(&input.utf_error, sizeof(uint32_t)));
        CUDA_CHECK(cudaMalloc(&input.trailing_slashes, input.padded_words * sizeof(uint8_t)));
        CUDA_CHECK(cudaMalloc(&input.quote_parity_masks, input.padded_warps * sizeof(uint32_t)));
        CUDA_CHECK(cudaMalloc(&input.quote_parity_masks_if_slash_one,
                              input.padded_warps * sizeof(uint32_t)));
        CUDA_CHECK(cudaMalloc(&input.quote_warp_prefix, input.padded_warps * sizeof(uint8_t)));
        CUDA_CHECK(cudaMemcpyAsync(input.input, input.host_input.data(), padded_size,
                                   cudaMemcpyHostToDevice, input.stream));
        CUDA_CHECK(cudaMemsetAsync(input.utf_error, 0, sizeof(uint32_t), input.stream));

        auto selected_quote_parity = thrust::make_transform_iterator(
            thrust::make_counting_iterator(0u), QuoteParityMaskInput{input.quote_parity_masks});
        CUDA_CHECK(cub::DeviceScan::ExclusiveScan(nullptr, input.scan_bytes,
            selected_quote_parity, input.quote_warp_prefix, QuoteParityXor{},
            static_cast<uint8_t>(0u), input.padded_warps, input.stream));
        CUDA_CHECK(cudaMalloc(&input.scan_storage, input.scan_bytes));
    }
    CUDA_CHECK(cudaDeviceSynchronize());

    for (int warmup = 0; warmup < 3; ++warmup) {
        for (HierarchicalEnumerationInput& input : inputs)
            CUDA_CHECK(launchHierarchicalEnumeration(input));
        CUDA_CHECK(cudaDeviceSynchronize());
    }

    cudaStream_t timing_stream = nullptr;
    cudaEvent_t start = nullptr, stop = nullptr;
    std::vector<cudaEvent_t> finished(inputs.size());
    CUDA_CHECK(cudaStreamCreateWithFlags(&timing_stream, cudaStreamNonBlocking));
    CUDA_CHECK(cudaEventCreate(&start));
    CUDA_CHECK(cudaEventCreate(&stop));
    for (cudaEvent_t& event : finished) CUDA_CHECK(cudaEventCreate(&event));

    double total_ms = 0.0;
    std::vector<double> completion_ms(inputs.size(), 0.0);
    for (int run = 0; run < runs; ++run) {
        CUDA_CHECK(cudaEventRecord(start, timing_stream));
        for (size_t index = 0u; index < inputs.size(); ++index) {
            HierarchicalEnumerationInput& input = inputs[index];
            CUDA_CHECK(cudaStreamWaitEvent(input.stream, start));
            CUDA_CHECK(launchHierarchicalEnumeration(input));
            CUDA_CHECK(cudaEventRecord(finished[index], input.stream));
        }
        for (cudaEvent_t event : finished) CUDA_CHECK(cudaStreamWaitEvent(timing_stream, event));
        CUDA_CHECK(cudaEventRecord(stop, timing_stream));
        CUDA_CHECK(cudaEventSynchronize(stop));
        float elapsed_ms = 0.0f;
        CUDA_CHECK(cudaEventElapsedTime(&elapsed_ms, start, stop));
        total_ms += elapsed_ms;
        for (size_t index = 0u; index < inputs.size(); ++index) {
            CUDA_CHECK(cudaEventElapsedTime(&elapsed_ms, start, finished[index]));
            completion_ms[index] += elapsed_ms;
        }
    }

    bool all_correct = true;
    uint64_t combined_checksum = FNV_OFFSET;
    std::vector<uint64_t> structural_hashes(inputs.size()), open_close_hashes(inputs.size());
    std::vector<uint32_t> utf_errors(inputs.size());
    for (size_t index = 0u; index < inputs.size(); ++index) {
        HierarchicalEnumerationInput& input = inputs[index];
        std::vector<uint32_t> structural(input.word_count), open_close(input.word_count);
        std::vector<uint32_t> expected_structural, expected_open_close;
        CUDA_CHECK(cudaMemcpy(structural.data(), input.structural,
                              input.word_count * sizeof(uint32_t), cudaMemcpyDeviceToHost));
        CUDA_CHECK(cudaMemcpy(open_close.data(), input.filtered_open_close,
                              input.word_count * sizeof(uint32_t), cudaMemcpyDeviceToHost));
        CUDA_CHECK(cudaMemcpy(&utf_errors[index], input.utf_error,
                              sizeof(uint32_t), cudaMemcpyDeviceToHost));
        makeCpuReference(input.host_input.data(), input.input_size, input.word_count,
                         expected_structural, expected_open_close);
        bool correct = (utf_errors[index] != 0u) == !validUtf8(input.host_input.data(), input.input_size);
        for (uint32_t word = 0u; word < input.word_count; ++word)
            correct = correct && structural[word] == expected_structural[word] &&
                      open_close[word] == expected_open_close[word];
        all_correct = all_correct && correct;
        structural_hashes[index] = hashWords(structural.data(), input.word_count);
        open_close_hashes[index] = hashWords(open_close.data(), input.word_count);
        combined_checksum = appendHash(combined_checksum, structural_hashes[index]);
        combined_checksum = appendHash(combined_checksum, open_close_hashes[index]);
        combined_checksum = appendHash(combined_checksum, utf_errors[index] != 0u ? 1u : 0u);
    }

    std::cout << std::fixed << std::setprecision(3)
              << "method=cujson_hierarchical_enumeration_literal inputs=" << inputs.size()
              << " threads=" << FULL_THREADS << " total_blocks=" << total_blocks
              << " avg_us=" << total_ms * 1000.0 / runs
              << " outputs_correct=" << (all_correct ? "PASS" : "FAIL")
              << " checksum=" << combined_checksum << '\n';
    for (size_t index = 0u; index < inputs.size(); ++index)
        std::cout << "input=" << index << " bytes=" << inputs[index].input_size
                  << " words=" << inputs[index].word_count << " blocks=" << inputs[index].blocks
                  << " completion_us=" << completion_ms[index] * 1000.0 / runs
                  << " structural_hash=" << structural_hashes[index]
                  << " open_close_hash=" << open_close_hashes[index]
                  << " utf_error=" << (utf_errors[index] != 0u) << '\n';

    for (cudaEvent_t event : finished) CUDA_CHECK(cudaEventDestroy(event));
    CUDA_CHECK(cudaEventDestroy(start));
    CUDA_CHECK(cudaEventDestroy(stop));
    CUDA_CHECK(cudaStreamDestroy(timing_stream));
    for (HierarchicalEnumerationInput& input : inputs) {
        CUDA_CHECK(cudaFree(input.scan_storage));
        CUDA_CHECK(cudaFree(input.input));
        CUDA_CHECK(cudaFree(input.operators));
        CUDA_CHECK(cudaFree(input.raw_open_close));
        CUDA_CHECK(cudaFree(input.structural));
        CUDA_CHECK(cudaFree(input.structural_if_slash_one));
        CUDA_CHECK(cudaFree(input.filtered_open_close));
        CUDA_CHECK(cudaFree(input.structural_counts));
        CUDA_CHECK(cudaFree(input.open_close_counts));
        CUDA_CHECK(cudaFree(input.utf_error));
        CUDA_CHECK(cudaFree(input.trailing_slashes));
        CUDA_CHECK(cudaFree(input.quote_parity_masks));
        CUDA_CHECK(cudaFree(input.quote_parity_masks_if_slash_one));
        CUDA_CHECK(cudaFree(input.quote_warp_prefix));
        CUDA_CHECK(cudaStreamDestroy(input.stream));
    }
    return all_correct ? EXIT_SUCCESS : EXIT_FAILURE;
}

#undef CUDA_CHECK
