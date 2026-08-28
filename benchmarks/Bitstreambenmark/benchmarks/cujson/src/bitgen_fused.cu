#include <cuda_runtime.h>

#include <algorithm>
#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <string>
#include <vector>

constexpr uint32_t THREADS = 256u;
constexpr uint32_t WARP_SIZE = 32u;
constexpr uint32_t WARP_COUNT = THREADS / WARP_SIZE;
constexpr uint32_t BYTES_PER_WORD = 32u;
constexpr uint32_t WORDS_PER_CHUNK = THREADS;
constexpr uint64_t FNV_OFFSET = 1469598103934665603ull;
constexpr uint64_t FNV_PRIME = 1099511628211ull;

struct InputDescriptor {
    uint64_t byte_offset;
    uint64_t byte_size;
    uint32_t word_offset;
    uint32_t padded_word_count;
};

#define CUDA_CHECK(call) do { cudaError_t status_ = (call); if (status_ != cudaSuccess) { \
    std::cerr << "CUDA error at " << __FILE__ << ':' << __LINE__ << ": " \
              << cudaGetErrorString(status_) << '\n'; std::exit(EXIT_FAILURE); } } while (0)

__device__ __forceinline__ uint32_t prefixXorWord(uint32_t value) {
    value ^= value << 1u;
    value ^= value << 2u;
    value ^= value << 4u;
    value ^= value << 8u;
    value ^= value << 16u;
    return value;
}

// These are the packed four-byte operations used by cuJSON's UTF-8 checker.
__device__ __forceinline__ uint32_t cujsonUtf8Classification(uint32_t current, uint32_t previous_byte) {
    constexpr uint32_t too_short = 0x01010101u;
    constexpr uint32_t too_long = 0x02020202u;
    constexpr uint32_t overlong_2 = 0x20202020u;
    constexpr uint32_t overlong_3 = 0x04040404u;
    constexpr uint32_t overlong_4 = 0x40404040u;
    constexpr uint32_t surrogate = 0x10101010u;
    constexpr uint32_t two_continuations = 0x80808080u;
    constexpr uint32_t too_large = 0x08080808u;
    constexpr uint32_t too_large_1000 = 0x40404040u;

    uint32_t first_byte = (__vcmpltu4(previous_byte, 0x80808080u) & too_long) |
        (__vcmpgeu4(previous_byte, 0xc0c0c0c0u) & too_short) |
        ((__vcmpeq4(previous_byte, 0xc0c0c0c0u) | __vcmpeq4(previous_byte, 0xc1c1c1c1u)) & overlong_2) |
        (__vcmpeq4(previous_byte, 0xededededu) & surrogate) |
        (__vcmpeq4(previous_byte, 0xe0e0e0e0u) & overlong_3) |
        (__vcmpeq4(previous_byte, 0xf0f0f0f0u) & overlong_4) |
        (__vcmpgtu4(previous_byte, 0xf4f4f4f4u) & too_large_1000) |
        (__vcmpgtu4(previous_byte, 0xf3f3f3f3u) & too_large);
    first_byte = __vcmpeq4(first_byte, 0u) & two_continuations;

    uint32_t current_high = (current >> 4u) & 0x0f0f0f0fu;
    uint32_t less_than_12 = __vcmpltu4(current_high, 0x0c0c0c0cu);
    uint32_t second_byte_high =
        ((__vcmpltu4(current_high, 0x08080808u) | __vcmpgtu4(current_high, 0x0b0b0b0bu)) & too_short) |
        (less_than_12 & __vcmpgeu4(current_high, 0x08080808u) & (too_long | overlong_2 | two_continuations)) |
        (less_than_12 & __vcmpgtu4(current_high, 0x08080808u) & too_large) |
        (__vcmpeq4(current_high, 0x08080808u) & (too_large_1000 | overlong_4)) |
        (__vcmpgtu4(current_high, 0x09090909u) & less_than_12 & surrogate);
    return first_byte & second_byte_high;
}

__device__ __forceinline__ uint32_t cujsonValidateUtf8FourBytes(uint32_t current, uint32_t previous) {
    constexpr uint32_t maximum_leading_bytes =
        (0xbfu << 24u) | (0xdfu << 16u) | (0xefu << 8u) | 0xffu;
    uint32_t previous_incomplete = __vsubus4(previous, maximum_leading_bytes);
    if ((current & 0x80808080u) == 0u) return previous_incomplete;

    uint64_t adjacent = (static_cast<uint64_t>(current) << 32u) | previous;
    uint32_t previous_one_byte = static_cast<uint32_t>(adjacent >> 24u);
    uint32_t previous_two_bytes = static_cast<uint32_t>(adjacent >> 16u);
    uint32_t previous_three_bytes = static_cast<uint32_t>(adjacent >> 8u);
    uint32_t classification = cujsonUtf8Classification(current, previous_one_byte);
    uint32_t third_byte = __vsubus4(previous_two_bytes, 0xdfdfdfdfu);
    uint32_t fourth_byte = __vsubus4(previous_three_bytes, 0xefefefefu);
    uint32_t greater = static_cast<uint32_t>(__vsubss4(static_cast<int32_t>(third_byte | fourth_byte), 0));
    uint32_t must_be_continuation = __vcmpgtu4(greater, 0u);
    return (must_be_continuation & 0x80808080u) ^ classification;
}

__device__ __forceinline__ uint32_t packMatches(uint32_t matches) {
    uint32_t bits = 0u;
    #pragma unroll
    for (uint32_t byte = 0u; byte < 4u; ++byte) bits |= (matches >> (byte * 7u)) & 0x0fu;
    return bits;
}

__device__ __forceinline__ uint32_t filterEscapedQuotesWord(
    uint32_t quote, uint32_t backslashes, uint32_t overflow) {
    constexpr uint32_t even_bits = 0x55555555u;
    constexpr uint32_t odd_bits = ~even_bits;
    backslashes &= ~overflow;
    uint32_t apply_escaped = (backslashes << 1u) | overflow;
    uint32_t odd_sequence = backslashes & odd_bits & ~apply_escaped;
    uint32_t sequence_start_even = odd_sequence + backslashes;
    uint32_t escaped = (even_bits ^ (sequence_start_even << 1u)) & apply_escaped;
    return (~escaped) & quote;
}

__device__ __forceinline__ void loadAndClassifyWord(const uint8_t* input, uint64_t input_size,
    uint32_t word_id, uint32_t& slash_word, uint32_t& quote_word, uint32_t& operator_word,
    uint32_t& open_close_word, uint32_t& utf_error) {
    const uint32_t* input_words = reinterpret_cast<const uint32_t*>(input);
    const uint4* input_vectors = reinterpret_cast<const uint4*>(input);
    uint32_t first_input_word = word_id * 8u;
    uint4 first = input_vectors[word_id * 2u];
    uint4 second = input_vectors[word_id * 2u + 1u];
    uint32_t loaded[8] = {first.x, first.y, first.z, first.w, second.x, second.y, second.z, second.w};

    utf_error = 0u;
    slash_word = 0u;
    quote_word = 0u;
    operator_word = 0u;
    open_close_word = 0u;
    #pragma unroll
    for (uint32_t part = 0u; part < 8u; ++part) {
        uint32_t current = loaded[part];
        uint32_t current_input_word = first_input_word + part;
        uint32_t previous = current_input_word == 0u ? 0u :
            (part == 0u ? input_words[current_input_word - 1u] : loaded[part - 1u]);
        if (((current | previous) & 0x80808080u) != 0u)
            utf_error |= cujsonValidateUtf8FourBytes(current, previous);

        uint32_t slash = __vcmpeq4(current, 0x5c5c5c5cu) & 0x01010101u;
        uint32_t quote = __vcmpeq4(current, 0x22222222u) & 0x01010101u;
        uint32_t open_close = (__vcmpeq4(current, 0x5b5b5b5bu) | __vcmpeq4(current, 0x5d5d5d5du) |
                               __vcmpeq4(current, 0x7b7b7b7bu) | __vcmpeq4(current, 0x7d7d7d7du)) & 0x01010101u;
        uint32_t colon_comma = (__vcmpeq4(current, 0x3a3a3a3au) |
                                __vcmpeq4(current, 0x2c2c2c2cu)) & 0x01010101u;
        slash_word |= packMatches(slash) << (part * 4u);
        quote_word |= packMatches(quote) << (part * 4u);
        open_close_word |= packMatches(open_close) << (part * 4u);
        operator_word |= packMatches(open_close | colon_comma) << (part * 4u);
    }

    uint64_t byte_start = static_cast<uint64_t>(word_id) * BYTES_PER_WORD;
    uint64_t bytes_left = byte_start < input_size ? input_size - byte_start : 0u;
    if (bytes_left < BYTES_PER_WORD) {
        uint32_t valid_mask = bytes_left == 0u ? 0u : 0xffffffffu >> (BYTES_PER_WORD - bytes_left);
        slash_word &= valid_mask;
        quote_word &= valid_mask;
        operator_word &= valid_mask;
        open_close_word &= valid_mask;
    }
}

// Inclusive XOR scan across the CTA: register shuffles inside each warp and
// shared memory only for the eight warp totals.
__device__ __forceinline__ uint32_t blockInclusiveXor(
    uint32_t value, uint32_t* shared_warp_prefixes) {
    uint32_t warp_lane = threadIdx.x % WARP_SIZE;
    uint32_t warp_id = threadIdx.x / WARP_SIZE;

    for (uint32_t offset = 1u; offset < WARP_SIZE; offset <<= 1u) {
        uint32_t previous = __shfl_up_sync(0xffffffffu, value, offset);
        if (warp_lane >= offset) value ^= previous;
    }

    if (warp_lane == WARP_SIZE - 1u) shared_warp_prefixes[warp_id] = value;
    __syncthreads();

    if (warp_id == 0u) {
        uint32_t warp_value = warp_lane < WARP_COUNT ? shared_warp_prefixes[warp_lane] : 0u;
        for (uint32_t offset = 1u; offset < WARP_COUNT; offset <<= 1u) {
            uint32_t previous = __shfl_up_sync(0xffffffffu, warp_value, offset);
            if (warp_lane >= offset) warp_value ^= previous;
        }
        if (warp_lane < WARP_COUNT) shared_warp_prefixes[warp_lane] = warp_value;
    }
    __syncthreads();

    if (warp_id != 0u) value ^= shared_warp_prefixes[warp_id - 1u];
    return value;
}

// One CTA owns one complete input. The outer loop is over 8192-byte chunks;
// all tokenizer stages for a chunk finish before the CTA advances to the next
// chunk. Slash/quote/operator/string intermediates therefore stay local.
__global__ void bitgenFusedKernel(const uint8_t* all_input, const InputDescriptor* descriptors,
    uint32_t* structural_bitmap, uint32_t* filtered_open_close_bitmap, uint32_t* utf_errors) {
    uint32_t input_id = blockIdx.x;
    InputDescriptor descriptor = descriptors[input_id];
    const uint8_t* input = all_input + descriptor.byte_offset;
    uint32_t lane = threadIdx.x;

    __shared__ uint32_t shared_slashes[THREADS];
    __shared__ uint32_t shared_warp_quote_parity[WARP_COUNT];
    __shared__ uint32_t previous_tile_slash_parity;
    __shared__ uint32_t previous_tile_quote_parity;
    __shared__ uint32_t input_utf_error;
    if (lane == 0u) {
        previous_tile_slash_parity = 0u;
        previous_tile_quote_parity = 0u;
        input_utf_error = 0u;
    }

    for (uint32_t chunk_start = 0u; chunk_start < descriptor.padded_word_count; chunk_start += WORDS_PER_CHUNK) {
        uint32_t word_id = chunk_start + lane;
        uint32_t slash_word = 0u, quote_word = 0u, operator_word = 0u, open_close_word = 0u;
        uint32_t thread_utf_error = 0u;
        loadAndClassifyWord(input, descriptor.byte_size, word_id, slash_word, quote_word,
                            operator_word, open_close_word, thread_utf_error);

        // Match cuJSON's escaped-quote lookback, but keep this tile's slash
        // words in shared memory instead of materializing and rereading them.
        shared_slashes[lane] = slash_word;
        __syncthreads();
        if (thread_utf_error != 0u) atomicOr(&input_utf_error, thread_utf_error);

        uint32_t trailing = static_cast<uint32_t>(__clz(~slash_word));
        uint32_t old_slash_parity = previous_tile_slash_parity;
        uint32_t old_quote_parity = previous_tile_quote_parity;
        uint32_t incoming_escape = old_slash_parity;
        uint32_t possible_escape = quote_word & ((slash_word << 1u) | 1u);
        if (possible_escape != 0u || (lane == WORDS_PER_CHUNK - 1u && trailing == 32u)) {
            int previous = static_cast<int>(lane) - 1;
            while (previous >= 0) {
                uint32_t previous_slashes = shared_slashes[previous];
                uint32_t previous_trailing = static_cast<uint32_t>(__clz(~previous_slashes));
                if (previous_trailing != 32u) {
                    incoming_escape = previous_trailing & 1u;
                    break;
                }
                --previous;
            }
        }
        uint32_t real_quote = possible_escape == 0u ? quote_word :
            filterEscapedQuotesWord(quote_word, slash_word, incoming_escape);
        uint32_t outgoing_escape = trailing == 32u ? incoming_escape : (trailing & 1u);

        uint32_t word_quote_parity = static_cast<uint32_t>(__popc(real_quote)) & 1u;
        uint32_t inclusive_quote_parity = blockInclusiveXor(word_quote_parity, shared_warp_quote_parity);
        uint32_t preceding_word_parity = inclusive_quote_parity ^ word_quote_parity;
        uint32_t tile_quote_parity = shared_warp_quote_parity[WARP_COUNT - 1u];
        uint32_t incoming_string = old_quote_parity ^ preceding_word_parity;
        // Every thread has consumed both old carries before these writes.
        if (lane == WORDS_PER_CHUNK - 1u) previous_tile_slash_parity = outgoing_escape;
        if (lane == 0u) previous_tile_quote_parity = old_quote_parity ^ tile_quote_parity;

        uint32_t in_string = prefixXorWord(real_quote);
        if (incoming_string != 0u) in_string = ~in_string;
        uint32_t structural = ~in_string & operator_word;
        uint32_t filtered_open_close = ~in_string & open_close_word;
        uint32_t output_word = descriptor.word_offset + word_id;
        structural_bitmap[output_word] = structural;
        filtered_open_close_bitmap[output_word] = filtered_open_close;
    }

    if (lane == 0u) utf_errors[input_id] = input_utf_error;
}

struct HostInput {
    std::string path;
    uint64_t size = 0u;
    uint32_t word_offset = 0u;
    uint32_t word_count = 0u;
    uint32_t padded_word_count = 0u;
};

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
        }
        else return false;
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
    for (uint32_t i = 0u; i < count; ++i) {
        hash ^= words[i];
        hash *= FNV_PRIME;
    }
    return hash;
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
    std::vector<HostInput> inputs(static_cast<size_t>(argc - 2));
    uint64_t total_words_64 = 0u;
    for (int argument = 2; argument < argc; ++argument) {
        HostInput& input = inputs[static_cast<size_t>(argument - 2)];
        input.path = argv[argument];
        std::ifstream file(input.path, std::ios::binary | std::ios::ate);
        if (!file) {
            std::cerr << "cannot open " << input.path << '\n';
            return EXIT_FAILURE;
        }
        std::streamoff end = file.tellg();
        if (end < 0) return EXIT_FAILURE;
        input.size = static_cast<uint64_t>(end);
        uint64_t words = (input.size + BYTES_PER_WORD - 1u) / BYTES_PER_WORD;
        // The zero sentinel flushes UTF state at an exact EOF boundary. Rounding
        // then guarantees that every device iteration contains 256 real lanes.
        uint64_t padded_words = ((words + 1u + WORDS_PER_CHUNK - 1u) / WORDS_PER_CHUNK) * WORDS_PER_CHUNK;
        if (words > std::numeric_limits<uint32_t>::max() ||
            padded_words > std::numeric_limits<uint32_t>::max() ||
            total_words_64 + padded_words > std::numeric_limits<uint32_t>::max()) {
            std::cerr << "combined inputs exceed the 32-bit bitmap index range\n";
            return EXIT_FAILURE;
        }
        input.word_offset = static_cast<uint32_t>(total_words_64);
        input.word_count = static_cast<uint32_t>(words);
        input.padded_word_count = static_cast<uint32_t>(padded_words);
        total_words_64 += padded_words;
    }

    uint32_t total_words = static_cast<uint32_t>(total_words_64);
    size_t input_storage_bytes = std::max<size_t>(static_cast<size_t>(total_words) * BYTES_PER_WORD, BYTES_PER_WORD);
    std::vector<uint8_t> all_input(input_storage_bytes, 0u);
    std::vector<InputDescriptor> descriptors(inputs.size());
    for (size_t i = 0u; i < inputs.size(); ++i) {
        HostInput& input = inputs[i];
        uint64_t byte_offset = static_cast<uint64_t>(input.word_offset) * BYTES_PER_WORD;
        std::ifstream file(input.path, std::ios::binary);
        file.read(reinterpret_cast<char*>(all_input.data() + byte_offset), static_cast<std::streamsize>(input.size));
        if (!file && input.size != 0u) {
            std::cerr << "failed to read " << input.path << '\n';
            return EXIT_FAILURE;
        }
        descriptors[i] = {byte_offset, input.size, input.word_offset, input.padded_word_count};
    }
    uint8_t* device_input = nullptr;
    InputDescriptor* device_descriptors = nullptr;
    uint32_t* device_structural = nullptr;
    uint32_t* device_open_close = nullptr;
    uint32_t* device_utf_errors = nullptr;
    CUDA_CHECK(cudaMalloc(&device_input, input_storage_bytes));
    CUDA_CHECK(cudaMalloc(&device_descriptors, descriptors.size() * sizeof(InputDescriptor)));
    CUDA_CHECK(cudaMalloc(&device_structural, std::max<uint32_t>(1u, total_words) * sizeof(uint32_t)));
    CUDA_CHECK(cudaMalloc(&device_open_close, std::max<uint32_t>(1u, total_words) * sizeof(uint32_t)));
    CUDA_CHECK(cudaMalloc(&device_utf_errors, inputs.size() * sizeof(uint32_t)));
    CUDA_CHECK(cudaMemcpy(device_input, all_input.data(), input_storage_bytes, cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemcpy(device_descriptors, descriptors.data(), descriptors.size() * sizeof(InputDescriptor),
                          cudaMemcpyHostToDevice));

    for (int warmup = 0; warmup < 3; ++warmup)
        bitgenFusedKernel<<<static_cast<uint32_t>(inputs.size()), THREADS>>>(device_input, device_descriptors,
            device_structural, device_open_close, device_utf_errors);
    CUDA_CHECK(cudaDeviceSynchronize());

    cudaEvent_t start, stop;
    CUDA_CHECK(cudaEventCreate(&start));
    CUDA_CHECK(cudaEventCreate(&stop));
    double total_ms = 0.0;
    for (int run = 0; run < runs; ++run) {
        CUDA_CHECK(cudaEventRecord(start));
        bitgenFusedKernel<<<static_cast<uint32_t>(inputs.size()), THREADS>>>(device_input, device_descriptors,
            device_structural, device_open_close, device_utf_errors);
        CUDA_CHECK(cudaEventRecord(stop));
        CUDA_CHECK(cudaEventSynchronize(stop));
        CUDA_CHECK(cudaGetLastError());
        float elapsed_ms = 0.0f;
        CUDA_CHECK(cudaEventElapsedTime(&elapsed_ms, start, stop));
        total_ms += elapsed_ms;
    }

    std::vector<uint32_t> structural(std::max<uint32_t>(1u, total_words));
    std::vector<uint32_t> open_close(std::max<uint32_t>(1u, total_words));
    std::vector<uint32_t> utf_errors(inputs.size());
    if (total_words != 0u) {
        CUDA_CHECK(cudaMemcpy(structural.data(), device_structural, total_words * sizeof(uint32_t), cudaMemcpyDeviceToHost));
        CUDA_CHECK(cudaMemcpy(open_close.data(), device_open_close, total_words * sizeof(uint32_t), cudaMemcpyDeviceToHost));
    }
    CUDA_CHECK(cudaMemcpy(utf_errors.data(), device_utf_errors, inputs.size() * sizeof(uint32_t), cudaMemcpyDeviceToHost));

    bool correct = true;
    uint64_t combined_checksum = FNV_OFFSET;
    std::vector<uint64_t> structural_hash(inputs.size()), open_close_hash(inputs.size());
    for (size_t i = 0; i < inputs.size(); ++i) {
        std::vector<uint32_t> expected_structural, expected_open_close;
        const HostInput& input = inputs[i];
        const uint8_t* input_bytes = all_input.data() + static_cast<size_t>(input.word_offset) * BYTES_PER_WORD;
        makeCpuReference(input_bytes, input.size, input.word_count, expected_structural, expected_open_close);
        bool expected_utf_error = !validUtf8(input_bytes, input.size);
        uint32_t offset = input.word_offset;
        uint32_t count = input.word_count;
        structural_hash[i] = hashWords(structural.data() + offset, count);
        open_close_hash[i] = hashWords(open_close.data() + offset, count);
        for (uint32_t word = 0u; word < count; ++word) {
            if (structural[offset + word] != expected_structural[word] ||
                open_close[offset + word] != expected_open_close[word]) correct = false;
        }
        if ((utf_errors[i] != 0u) != expected_utf_error) correct = false;
        combined_checksum ^= structural_hash[i];
        combined_checksum *= FNV_PRIME;
        combined_checksum ^= open_close_hash[i];
        combined_checksum *= FNV_PRIME;
        combined_checksum ^= static_cast<uint64_t>(utf_errors[i] != 0u);
        combined_checksum *= FNV_PRIME;
    }

    std::cout << std::fixed << std::setprecision(3)
              << "method=cujson_bitgen_fused inputs=" << inputs.size()
              << " threads=" << THREADS << " words_per_chunk=" << WORDS_PER_CHUNK
              << " avg_us=" << total_ms * 1000.0 / runs
              << " outputs_correct=" << (correct ? "PASS" : "FAIL")
              << " checksum=" << combined_checksum << '\n';
    for (size_t i = 0; i < inputs.size(); ++i)
        std::cout << "input=" << i << " bytes=" << inputs[i].size
                  << " words=" << inputs[i].word_count
                  << " padded_words=" << inputs[i].padded_word_count
                  << " structural_hash=" << structural_hash[i]
                  << " open_close_hash=" << open_close_hash[i]
                  << " utf_error=" << (utf_errors[i] != 0u) << '\n';

    CUDA_CHECK(cudaEventDestroy(start));
    CUDA_CHECK(cudaEventDestroy(stop));
    CUDA_CHECK(cudaFree(device_input));
    CUDA_CHECK(cudaFree(device_descriptors));
    CUDA_CHECK(cudaFree(device_structural));
    CUDA_CHECK(cudaFree(device_open_close));
    CUDA_CHECK(cudaFree(device_utf_errors));
    return correct ? EXIT_SUCCESS : EXIT_FAILURE;
}
