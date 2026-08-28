#include <cuda_runtime.h>

#include <algorithm>
#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <string>
#include <vector>

constexpr uint32_t THREADS = 256u;
constexpr uint32_t BYTES_PER_WORD = 32u;
constexpr uint32_t WORDS_PER_CHUNK = THREADS;
constexpr uint64_t FNV_OFFSET = 1469598103934665603ull;
constexpr uint64_t FNV_PRIME = 1099511628211ull;

struct InputDesc {
    uint64_t byte_offset;
    uint64_t byte_size;
    uint32_t word_offset;
    uint32_t padded_word_count;
};

#define CUDA_CHECK(call) do { cudaError_t error_ = (call); if (error_ != cudaSuccess) { \
    std::cerr << "CUDA error at " << __FILE__ << ':' << __LINE__ << ": " \
              << cudaGetErrorString(error_) << '\n'; std::exit(EXIT_FAILURE); } } while (0)

__device__ __forceinline__ uint32_t prefixXorWord(uint32_t value) {
    value ^= value << 1u;
    value ^= value << 2u;
    value ^= value << 4u;
    value ^= value << 8u;
    value ^= value << 16u;
    return value;
}

__device__ __forceinline__ uint32_t packMatches(uint32_t matches) {
    uint32_t bits = 0u;
    #pragma unroll
    for (uint32_t byte = 0u; byte < 4u; ++byte) bits |= (matches >> (byte * 7u)) & 0x0fu;
    return bits;
}

// cuJSON's packed four-byte UTF-8 validation operations.
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

    uint32_t first_byte =
        (__vcmpltu4(previous_byte, 0x80808080u) & too_long) |
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
        (less_than_12 & __vcmpgeu4(current_high, 0x08080808u) &
         (too_long | overlong_2 | two_continuations)) |
        (less_than_12 & __vcmpgtu4(current_high, 0x08080808u) & too_large) |
        (__vcmpeq4(current_high, 0x08080808u) & (too_large_1000 | overlong_4)) |
        (__vcmpgtu4(current_high, 0x09090909u) & less_than_12 & surrogate);
    return first_byte & second_byte_high;
}

__device__ __forceinline__ uint32_t cujsonUtf8ContinuationBytes(
    uint32_t previous_two_bytes, uint32_t previous_three_bytes, uint32_t classification) {
    constexpr uint32_t maximum_two_byte = 0xdfdfdfdfu;
    constexpr uint32_t maximum_three_byte = 0xefefefefu;
    uint32_t third_byte = __vsubus4(previous_two_bytes, maximum_two_byte);
    uint32_t fourth_byte = __vsubus4(previous_three_bytes, maximum_three_byte);
    uint32_t greater = static_cast<uint32_t>(__vsubss4(static_cast<int32_t>(third_byte | fourth_byte), 0));
    uint32_t must_be_continuation = __vcmpgtu4(greater, 0u);
    return (must_be_continuation & 0x80808080u) ^ classification;
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
    return cujsonUtf8ContinuationBytes(previous_two_bytes, previous_three_bytes, classification);
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
    const uint4* vectors = reinterpret_cast<const uint4*>(input);
    uint4 first = vectors[word_id * 2u];
    uint4 second = vectors[word_id * 2u + 1u];
    uint32_t loaded[8] = {first.x, first.y, first.z, first.w,
                          second.x, second.y, second.z, second.w};

    slash_word = 0u;
    quote_word = 0u;
    operator_word = 0u;
    open_close_word = 0u;
    utf_error = 0u;
    const uint32_t* input_words = reinterpret_cast<const uint32_t*>(input);
    #pragma unroll
    for (uint32_t part = 0u; part < 8u; ++part) {
        uint32_t input_word_id = word_id * 8u + part;
        uint32_t current = loaded[part];
        uint32_t previous = input_word_id == 0u ? 0u :
            (part == 0u ? input_words[input_word_id - 1u] : loaded[part - 1u]);
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

__device__ __forceinline__ void scanQuoteParity256(uint32_t value, uint32_t* shared_quote_parity) {
    uint32_t lane = threadIdx.x;
    shared_quote_parity[lane] = value;
    __syncthreads();
    for (uint32_t offset = 1u; offset < WORDS_PER_CHUNK; offset <<= 1u) {
        uint32_t current = shared_quote_parity[lane];
        uint32_t previous = lane >= offset ? shared_quote_parity[lane - offset] : 0u;
        __syncthreads();
        if (lane >= offset) shared_quote_parity[lane] = current ^ previous;
        __syncthreads();
    }
}

// Stage 1: UTF validation and cuJSON-style 32-byte classification.
__global__ void classifyKernel(const uint8_t* all_input, const InputDesc* inputs,
    uint32_t* slash_bitmap, uint32_t* quote_bitmap, uint32_t* operator_bitmap,
    uint32_t* open_close_bitmap, uint32_t* utf_error) {
    __shared__ uint32_t input_utf_error;
    InputDesc input = inputs[blockIdx.x];
    const uint8_t* bytes = all_input + input.byte_offset;
    if (threadIdx.x == 0u) input_utf_error = 0u;
    __syncthreads();

    for (uint32_t chunk_start = 0u; chunk_start < input.padded_word_count; chunk_start += WORDS_PER_CHUNK) {
        uint32_t word_id = chunk_start + threadIdx.x;
        uint32_t slash = 0u, quote = 0u, operators = 0u, open_close = 0u, local_utf_error = 0u;
        loadAndClassifyWord(bytes, input.byte_size, word_id, slash, quote, operators,
                            open_close, local_utf_error);
        uint32_t output_id = input.word_offset + word_id;
        slash_bitmap[output_id] = slash;
        quote_bitmap[output_id] = quote;
        operator_bitmap[output_id] = operators;
        open_close_bitmap[output_id] = open_close;
        if (local_utf_error != 0u) atomicOr(&input_utf_error, local_utf_error);
    }
    __syncthreads();
    if (threadIdx.x == 0u) utf_error[blockIdx.x] = input_utf_error;
}

// Stage 2: reload slash/quote bitmaps from global memory and materialize real quotes.
__global__ void escapedQuoteKernel(const InputDesc* inputs, const uint32_t* slash_bitmap,
    const uint32_t* quote_bitmap, uint32_t* real_quote_bitmap) {
    __shared__ uint32_t shared_slashes[WORDS_PER_CHUNK];
    __shared__ uint32_t previous_tile_slash_parity;
    InputDesc input = inputs[blockIdx.x];
    if (threadIdx.x == 0u) previous_tile_slash_parity = 0u;

    for (uint32_t chunk_start = 0u; chunk_start < input.padded_word_count; chunk_start += WORDS_PER_CHUNK) {
        uint32_t word_id = chunk_start + threadIdx.x;
        uint32_t output_id = input.word_offset + word_id;
        uint32_t slash = slash_bitmap[output_id];
        uint32_t quote = quote_bitmap[output_id];
        shared_slashes[threadIdx.x] = slash;
        __syncthreads();

        uint32_t trailing = static_cast<uint32_t>(__clz(~slash));
        uint32_t incoming = previous_tile_slash_parity;
        uint32_t possible_escaped = quote & ((slash << 1u) | 1u);
        if (possible_escaped != 0u || (threadIdx.x == WORDS_PER_CHUNK - 1u && trailing == 32u)) {
            int previous = static_cast<int>(threadIdx.x) - 1;
            while (previous >= 0) {
                uint32_t previous_slashes = shared_slashes[previous];
                uint32_t previous_trailing = static_cast<uint32_t>(__clz(~previous_slashes));
                if (previous_trailing != 32u) {
                    incoming = previous_trailing & 1u;
                    break;
                }
                --previous;
            }
        }
        real_quote_bitmap[output_id] = possible_escaped == 0u ? quote :
            filterEscapedQuotesWord(quote, slash, incoming);
        uint32_t outgoing = trailing == 32u ? incoming : (trailing & 1u);
        __syncthreads();
        if (threadIdx.x == WORDS_PER_CHUNK - 1u) previous_tile_slash_parity = outgoing;
    }
}

// Stage 3: reload real quotes, scan quote parity, and materialize the in-string bitmap.
__global__ void inStringKernel(const InputDesc* inputs, const uint32_t* real_quote_bitmap,
    uint32_t* in_string_bitmap) {
    __shared__ uint32_t shared_quote_parity[WORDS_PER_CHUNK];
    __shared__ uint32_t previous_tile_quote_parity;
    InputDesc input = inputs[blockIdx.x];
    if (threadIdx.x == 0u) previous_tile_quote_parity = 0u;

    for (uint32_t chunk_start = 0u; chunk_start < input.padded_word_count; chunk_start += WORDS_PER_CHUNK) {
        uint32_t word_id = chunk_start + threadIdx.x;
        uint32_t output_id = input.word_offset + word_id;
        uint32_t real_quote = real_quote_bitmap[output_id];
        scanQuoteParity256(static_cast<uint32_t>(__popc(real_quote)) & 1u, shared_quote_parity);

        uint32_t tile_quote_parity = shared_quote_parity[WORDS_PER_CHUNK - 1u];
        uint32_t parity_before = previous_tile_quote_parity ^
            (threadIdx.x == 0u ? 0u : shared_quote_parity[threadIdx.x - 1u]);
        uint32_t in_string = prefixXorWord(real_quote);
        in_string_bitmap[output_id] = parity_before != 0u ? ~in_string : in_string;
        __syncthreads();
        if (threadIdx.x == 0u)
            previous_tile_quote_parity ^= tile_quote_parity;
    }
}

// Stage 4: reload GM intermediates and overwrite the in-string/open-close rows with final bitmaps.
__global__ void structuralFilterKernel(const InputDesc* inputs, const uint32_t* operator_bitmap,
    uint32_t* open_close_bitmap, uint32_t* in_string_or_structural_bitmap) {
    InputDesc input = inputs[blockIdx.x];
    for (uint32_t chunk_start = 0u; chunk_start < input.padded_word_count; chunk_start += WORDS_PER_CHUNK) {
        uint32_t word_id = chunk_start + threadIdx.x;
        uint32_t output_id = input.word_offset + word_id;
        uint32_t in_string = in_string_or_structural_bitmap[output_id];
        in_string_or_structural_bitmap[output_id] = ~in_string & operator_bitmap[output_id];
        open_close_bitmap[output_id] = ~in_string & open_close_bitmap[output_id];
    }
}

struct HostInput {
    std::string path;
    uint64_t size = 0u;
    uint32_t word_offset = 0u;
    uint32_t word_count = 0u;
    uint32_t padded_word_count = 0u;
};

static bool validUtf8(const uint8_t* data, uint64_t size) {
    uint64_t i = 0u;
    while (i < size) {
        uint8_t first = data[i++];
        if (first <= 0x7fu) continue;
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
        if (i + continuation_count > size) return false;
        if (data[i] < second_min || data[i] > second_max) return false;
        ++i;
        for (uint32_t continuation = 1u; continuation < continuation_count; ++continuation, ++i)
            if (data[i] < 0x80u || data[i] > 0xbfu) return false;
    }
    return true;
}

static void makeCpuReference(const uint8_t* data, uint64_t size, uint32_t word_count,
    std::vector<uint32_t>& structural, std::vector<uint32_t>& open_close) {
    structural.assign(word_count, 0u);
    open_close.assign(word_count, 0u);
    bool in_string = false;
    uint32_t consecutive_slashes = 0u;
    for (uint64_t position = 0u; position < size; ++position) {
        uint8_t value = data[position];
        bool real_quote = value == static_cast<uint8_t>('"') && (consecutive_slashes & 1u) == 0u;
        if (real_quote) in_string = !in_string;
        if (!in_string) {
            bool is_open_close = value == static_cast<uint8_t>('[') || value == static_cast<uint8_t>(']') ||
                                 value == static_cast<uint8_t>('{') || value == static_cast<uint8_t>('}');
            bool is_operator = is_open_close || value == static_cast<uint8_t>(':') ||
                               value == static_cast<uint8_t>(',');
            uint32_t word = static_cast<uint32_t>(position / BYTES_PER_WORD);
            uint32_t bit = static_cast<uint32_t>(position % BYTES_PER_WORD);
            if (is_operator) structural[word] |= 1u << bit;
            if (is_open_close) open_close[word] |= 1u << bit;
        }
        consecutive_slashes = value == static_cast<uint8_t>('\\') ? consecutive_slashes + 1u : 0u;
    }
}

static uint64_t hashWords(const uint32_t* words, uint32_t count) {
    uint64_t hash = FNV_OFFSET;
    for (uint32_t i = 0u; i < count; ++i) {
        hash ^= static_cast<uint64_t>(words[i]);
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
    std::vector<InputDesc> descriptors(inputs.size());
    for (size_t i = 0u; i < inputs.size(); ++i) {
        HostInput& input = inputs[i];
        uint64_t byte_offset = static_cast<uint64_t>(input.word_offset) * BYTES_PER_WORD;
        std::ifstream file(input.path, std::ios::binary);
        file.read(reinterpret_cast<char*>(all_input.data() + byte_offset),
                  static_cast<std::streamsize>(input.size));
        if (!file && input.size != 0u) {
            std::cerr << "failed to read " << input.path << '\n';
            return EXIT_FAILURE;
        }
        descriptors[i] = {byte_offset, input.size, input.word_offset, input.padded_word_count};
    }

    uint8_t* d_input = nullptr;
    InputDesc* d_descriptors = nullptr;
    uint32_t* d_workspace = nullptr;
    uint32_t* d_utf_error = nullptr;
    size_t bitmap_bytes = std::max<size_t>(static_cast<size_t>(total_words) * sizeof(uint32_t), sizeof(uint32_t));
    CUDA_CHECK(cudaMalloc(reinterpret_cast<void**>(&d_input), input_storage_bytes));
    CUDA_CHECK(cudaMalloc(reinterpret_cast<void**>(&d_descriptors), descriptors.size() * sizeof(InputDesc)));
    CUDA_CHECK(cudaMalloc(reinterpret_cast<void**>(&d_workspace), bitmap_bytes * 6u));
    CUDA_CHECK(cudaMalloc(reinterpret_cast<void**>(&d_utf_error), inputs.size() * sizeof(uint32_t)));
    CUDA_CHECK(cudaMemcpy(d_input, all_input.data(), input_storage_bytes, cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemcpy(d_descriptors, descriptors.data(), descriptors.size() * sizeof(InputDesc),
                          cudaMemcpyHostToDevice));

    uint32_t* d_slash = d_workspace;
    uint32_t* d_quote = d_workspace + total_words;
    uint32_t* d_operators = d_workspace + total_words * 2u;
    uint32_t* d_open_close = d_workspace + total_words * 3u;
    uint32_t* d_real_quote = d_workspace + total_words * 4u;
    uint32_t* d_in_string_or_structural = d_workspace + total_words * 5u;
    dim3 grid(static_cast<uint32_t>(inputs.size()));
    dim3 block(THREADS);

    auto launch = [&]() {
        classifyKernel<<<grid, block>>>(d_input, d_descriptors, d_slash, d_quote,
            d_operators, d_open_close, d_utf_error);
        escapedQuoteKernel<<<grid, block>>>(d_descriptors, d_slash, d_quote, d_real_quote);
        inStringKernel<<<grid, block>>>(d_descriptors, d_real_quote, d_in_string_or_structural);
        structuralFilterKernel<<<grid, block>>>(d_descriptors, d_operators, d_open_close,
            d_in_string_or_structural);
    };

    for (int warmup = 0; warmup < 3; ++warmup) launch();
    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaDeviceSynchronize());

    cudaEvent_t events[5];
    for (cudaEvent_t& event : events) CUDA_CHECK(cudaEventCreate(&event));
    double stage_ms[4] = {};
    for (int run = 0; run < runs; ++run) {
        CUDA_CHECK(cudaEventRecord(events[0]));
        classifyKernel<<<grid, block>>>(d_input, d_descriptors, d_slash, d_quote,
            d_operators, d_open_close, d_utf_error);
        CUDA_CHECK(cudaEventRecord(events[1]));
        escapedQuoteKernel<<<grid, block>>>(d_descriptors, d_slash, d_quote, d_real_quote);
        CUDA_CHECK(cudaEventRecord(events[2]));
        inStringKernel<<<grid, block>>>(d_descriptors, d_real_quote, d_in_string_or_structural);
        CUDA_CHECK(cudaEventRecord(events[3]));
        structuralFilterKernel<<<grid, block>>>(d_descriptors, d_operators, d_open_close,
            d_in_string_or_structural);
        CUDA_CHECK(cudaEventRecord(events[4]));
        CUDA_CHECK(cudaEventSynchronize(events[4]));
        CUDA_CHECK(cudaGetLastError());
        for (int stage = 0; stage < 4; ++stage) {
            float elapsed = 0.0f;
            CUDA_CHECK(cudaEventElapsedTime(&elapsed, events[stage], events[stage + 1]));
            stage_ms[stage] += elapsed;
        }
    }

    std::vector<uint32_t> gpu_structural(std::max<uint32_t>(1u, total_words));
    std::vector<uint32_t> gpu_open_close(std::max<uint32_t>(1u, total_words));
    std::vector<uint32_t> gpu_utf_error(inputs.size());
    if (total_words != 0u) {
        CUDA_CHECK(cudaMemcpy(gpu_structural.data(), d_in_string_or_structural,
                              static_cast<size_t>(total_words) * sizeof(uint32_t), cudaMemcpyDeviceToHost));
        CUDA_CHECK(cudaMemcpy(gpu_open_close.data(), d_open_close,
                              static_cast<size_t>(total_words) * sizeof(uint32_t), cudaMemcpyDeviceToHost));
    }
    CUDA_CHECK(cudaMemcpy(gpu_utf_error.data(), d_utf_error, inputs.size() * sizeof(uint32_t),
                          cudaMemcpyDeviceToHost));

    bool all_correct = true;
    uint64_t combined_checksum = FNV_OFFSET;
    std::vector<uint64_t> structural_hashes(inputs.size()), open_close_hashes(inputs.size());
    for (size_t i = 0u; i < inputs.size(); ++i) {
        const HostInput& input = inputs[i];
        std::vector<uint32_t> expected_structural, expected_open_close;
        makeCpuReference(all_input.data() + static_cast<size_t>(input.word_offset) * BYTES_PER_WORD,
                         input.size, input.word_count, expected_structural, expected_open_close);
        bool expected_utf_error = !validUtf8(
            all_input.data() + static_cast<size_t>(input.word_offset) * BYTES_PER_WORD, input.size);
        const uint32_t* actual_structural = gpu_structural.data() + input.word_offset;
        const uint32_t* actual_open_close = gpu_open_close.data() + input.word_offset;
        bool correct = (gpu_utf_error[i] != 0u) == expected_utf_error;
        for (uint32_t word = 0u; word < input.word_count; ++word)
            correct = correct && actual_structural[word] == expected_structural[word] &&
                      actual_open_close[word] == expected_open_close[word];
        all_correct = all_correct && correct;
        structural_hashes[i] = hashWords(actual_structural, input.word_count);
        open_close_hashes[i] = hashWords(actual_open_close, input.word_count);
        combined_checksum = appendHash(combined_checksum, structural_hashes[i]);
        combined_checksum = appendHash(combined_checksum, open_close_hashes[i]);
        combined_checksum = appendHash(combined_checksum, gpu_utf_error[i] != 0u ? 1u : 0u);
    }

    double total_ms = stage_ms[0] + stage_ms[1] + stage_ms[2] + stage_ms[3];
    std::cout << std::fixed << std::setprecision(3)
              << "method=cujson_bitgen_targeted_baseline inputs=" << inputs.size()
              << " threads=" << THREADS << " words_per_chunk=" << WORDS_PER_CHUNK
              << " avg_us=" << total_ms * 1000.0 / runs
              << " classify_utf_us=" << stage_ms[0] * 1000.0 / runs
              << " escaped_quote_us=" << stage_ms[1] * 1000.0 / runs
              << " in_string_us=" << stage_ms[2] * 1000.0 / runs
              << " final_filter_us=" << stage_ms[3] * 1000.0 / runs
              << " outputs_correct=" << (all_correct ? "PASS" : "FAIL")
              << " checksum=" << combined_checksum << '\n';
    for (size_t i = 0u; i < inputs.size(); ++i) {
        std::cout << "input=" << i << " bytes=" << inputs[i].size
                  << " words=" << inputs[i].word_count
                  << " padded_words=" << inputs[i].padded_word_count
                  << " structural_hash=" << structural_hashes[i]
                  << " open_close_hash=" << open_close_hashes[i]
                  << " utf_error=" << (gpu_utf_error[i] != 0u ? 1 : 0) << '\n';
    }

    for (cudaEvent_t event : events) cudaEventDestroy(event);
    cudaFree(d_input);
    cudaFree(d_descriptors);
    cudaFree(d_workspace);
    cudaFree(d_utf_error);
    return all_correct ? EXIT_SUCCESS : EXIT_FAILURE;
}
