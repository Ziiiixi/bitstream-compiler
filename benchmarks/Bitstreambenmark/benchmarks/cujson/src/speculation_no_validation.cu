#include "hierarchical_common.cuh"

#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <string>
#include <vector>

constexpr uint64_t FNV_OFFSET = 1469598103934665603ull;
constexpr uint64_t FNV_PRIME = 1099511628211ull;

#define CUDA_CHECK(call) do { cudaError_t status_ = (call); if (status_ != cudaSuccess) { \
    std::cerr << "CUDA error at " << __FILE__ << ':' << __LINE__ << ": " \
              << cudaGetErrorString(status_) << '\n'; std::exit(EXIT_FAILURE); } } while (0)

// This is hierarchical speculation's first kernel without either scan,
// validation, or recovery stage. Every word predicts both incoming states as 0.
__global__ void noValidationRecoveryKernel(const uint8_t* input, uint64_t input_size,
    uint32_t* operator_bitmap, uint32_t* raw_open_close, uint32_t* structural_bitmap,
    uint32_t* filtered_open_close, uint8_t* slash_transitions,
    uint32_t* quote_parity_masks, uint32_t* utf_error) {
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

    uint32_t trailing = static_cast<uint32_t>(__clz(~slash_word));
    slash_transitions[word_id] = static_cast<uint8_t>(
        trailing == 32u ? 1u : ((trailing & 1u) << 1u));

    uint32_t possible_escape = current_quote & (slash_word << 1u);
    uint32_t real_quote = possible_escape == 0u ? current_quote :
        fullFilterEscapedQuotesWord(current_quote, slash_word, 0u);
    uint32_t quote_parity = static_cast<uint32_t>(__popc(real_quote) & 1u);
    uint32_t parity_mask = __ballot_sync(0xffffffffu, quote_parity != 0u);
    if ((threadIdx.x & 31u) == 0u) quote_parity_masks[word_id >> 5u] = parity_mask;

    uint32_t in_string = fullPrefixXorWord(real_quote);
    uint32_t structural = ~in_string & operator_word;
    operator_bitmap[word_id] = operator_word;
    raw_open_close[word_id] = open_close_word;
    structural_bitmap[word_id] = structural;
    filtered_open_close[word_id] = structural & open_close_word;
}

struct NoValidationInput {
    std::string path;
    uint64_t input_size = 0u;
    uint32_t word_count = 0u;
    uint32_t padded_words = 0u;
    uint32_t blocks = 0u;
    std::vector<uint8_t> host_input;
    uint8_t* input = nullptr;
    uint32_t* operators = nullptr;
    uint32_t* raw_open_close = nullptr;
    uint32_t* structural = nullptr;
    uint32_t* filtered_open_close = nullptr;
    uint32_t* utf_error = nullptr;
    uint32_t* quote_parity_masks = nullptr;
    uint8_t* slash_transitions = nullptr;
    cudaStream_t stream = nullptr;
};

static cudaError_t launchNoValidationRecovery(NoValidationInput& input) {
    noValidationRecoveryKernel<<<input.blocks, FULL_THREADS, 0, input.stream>>>(input.input,
        input.input_size, input.operators, input.raw_open_close, input.structural,
        input.filtered_open_close, input.slash_transitions, input.quote_parity_masks,
        input.utf_error);
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

    std::vector<NoValidationInput> inputs(static_cast<size_t>(argc - 2));
    uint64_t total_blocks = 0u;
    for (int argument = 2; argument < argc; ++argument) {
        NoValidationInput& input = inputs[static_cast<size_t>(argument - 2)];
        input.path = argv[argument];
        std::ifstream file(input.path, std::ios::binary | std::ios::ate);
        if (!file) {
            std::cerr << "cannot open " << input.path << '\n';
            return EXIT_FAILURE;
        }
        std::streamoff end = file.tellg();
        if (end < 0) return EXIT_FAILURE;
        input.input_size = static_cast<uint64_t>(end);
        uint64_t words = (input.input_size + 31u) / 32u;
        uint64_t padded_words = ((words + 1u + FULL_THREADS - 1u) / FULL_THREADS) * FULL_THREADS;
        if (words > std::numeric_limits<uint32_t>::max() ||
            padded_words > std::numeric_limits<uint32_t>::max()) {
            std::cerr << "input exceeds the 32-bit word range\n";
            return EXIT_FAILURE;
        }
        input.word_count = static_cast<uint32_t>(words);
        input.padded_words = static_cast<uint32_t>(padded_words);
        input.blocks = input.padded_words / FULL_THREADS;
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
        CUDA_CHECK(cudaMalloc(&input.filtered_open_close, bitmap_bytes));
        CUDA_CHECK(cudaMalloc(&input.utf_error, sizeof(uint32_t)));
        CUDA_CHECK(cudaMalloc(&input.slash_transitions, input.padded_words * sizeof(uint8_t)));
        CUDA_CHECK(cudaMalloc(&input.quote_parity_masks,
            (input.padded_words / 32u) * sizeof(uint32_t)));
        CUDA_CHECK(cudaMemcpyAsync(input.input, input.host_input.data(), padded_size,
                                   cudaMemcpyHostToDevice, input.stream));
        CUDA_CHECK(cudaMemsetAsync(input.utf_error, 0, sizeof(uint32_t), input.stream));
    }
    CUDA_CHECK(cudaDeviceSynchronize());

    for (int warmup = 0; warmup < 3; ++warmup) {
        for (NoValidationInput& input : inputs) CUDA_CHECK(launchNoValidationRecovery(input));
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
            NoValidationInput& input = inputs[index];
            CUDA_CHECK(cudaStreamWaitEvent(input.stream, start));
            CUDA_CHECK(launchNoValidationRecovery(input));
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
    std::vector<uint64_t> wrong_words(inputs.size()), wrong_structural(inputs.size());
    std::vector<uint64_t> wrong_open_close(inputs.size());
    for (size_t index = 0u; index < inputs.size(); ++index) {
        NoValidationInput& input = inputs[index];
        std::vector<uint32_t> structural(input.word_count), predicted_open_close(input.word_count);
        std::vector<uint32_t> expected_structural, expected_open_close;
        CUDA_CHECK(cudaMemcpy(structural.data(), input.structural,
                              input.word_count * sizeof(uint32_t), cudaMemcpyDeviceToHost));
        CUDA_CHECK(cudaMemcpy(predicted_open_close.data(), input.filtered_open_close,
                              input.word_count * sizeof(uint32_t), cudaMemcpyDeviceToHost));
        CUDA_CHECK(cudaMemcpy(&utf_errors[index], input.utf_error,
                              sizeof(uint32_t), cudaMemcpyDeviceToHost));
        makeCpuReference(input.host_input.data(), input.input_size, input.word_count,
                         expected_structural, expected_open_close);
        bool correct = (utf_errors[index] != 0u) == !validUtf8(input.host_input.data(), input.input_size);
        for (uint32_t word = 0u; word < input.word_count; ++word) {
            bool structural_correct = structural[word] == expected_structural[word];
            bool open_close_correct = predicted_open_close[word] == expected_open_close[word];
            bool word_correct = structural_correct && open_close_correct;
            wrong_structural[index] += !structural_correct;
            wrong_open_close[index] += !open_close_correct;
            wrong_words[index] += !word_correct;
            correct = correct && word_correct;
        }
        all_correct = all_correct && correct;
        structural_hashes[index] = hashWords(structural.data(), input.word_count);
        open_close_hashes[index] = hashWords(predicted_open_close.data(), input.word_count);
        combined_checksum = appendHash(combined_checksum, structural_hashes[index]);
        combined_checksum = appendHash(combined_checksum, open_close_hashes[index]);
        combined_checksum = appendHash(combined_checksum, utf_errors[index] != 0u ? 1u : 0u);
    }

    std::cout << std::fixed << std::setprecision(3)
              << "method=cujson_speculation_no_validation inputs=" << inputs.size()
              << " threads=" << FULL_THREADS << " total_blocks=" << total_blocks
              << " avg_us=" << total_ms * 1000.0 / runs
              << " outputs_correct=" << (all_correct ? "PASS" : "FAIL")
              << " checksum=" << combined_checksum << '\n';
    for (size_t index = 0u; index < inputs.size(); ++index) {
        double word_accuracy = inputs[index].word_count == 0u ? 100.0 :
            100.0 * static_cast<double>(inputs[index].word_count - wrong_words[index]) /
            static_cast<double>(inputs[index].word_count);
        std::cout << "input=" << index << " bytes=" << inputs[index].input_size
                  << " words=" << inputs[index].word_count << " blocks=" << inputs[index].blocks
                  << " completion_us=" << completion_ms[index] * 1000.0 / runs
                  << " wrong_words=" << wrong_words[index]
                  << " wrong_structural_words=" << wrong_structural[index]
                  << " wrong_open_close_words=" << wrong_open_close[index]
                  << " word_accuracy_percent=" << word_accuracy
                  << " structural_hash=" << structural_hashes[index]
                  << " open_close_hash=" << open_close_hashes[index]
                  << " utf_error=" << (utf_errors[index] != 0u) << '\n';
    }

    for (cudaEvent_t event : finished) CUDA_CHECK(cudaEventDestroy(event));
    CUDA_CHECK(cudaEventDestroy(start));
    CUDA_CHECK(cudaEventDestroy(stop));
    CUDA_CHECK(cudaStreamDestroy(timing_stream));
    for (NoValidationInput& input : inputs) {
        CUDA_CHECK(cudaFree(input.input));
        CUDA_CHECK(cudaFree(input.operators));
        CUDA_CHECK(cudaFree(input.raw_open_close));
        CUDA_CHECK(cudaFree(input.structural));
        CUDA_CHECK(cudaFree(input.filtered_open_close));
        CUDA_CHECK(cudaFree(input.utf_error));
        CUDA_CHECK(cudaFree(input.slash_transitions));
        CUDA_CHECK(cudaFree(input.quote_parity_masks));
        CUDA_CHECK(cudaStreamDestroy(input.stream));
    }
    return EXIT_SUCCESS;
}

#undef CUDA_CHECK
