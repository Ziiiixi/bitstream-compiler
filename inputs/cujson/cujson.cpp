// Prepared from AutomataLab/cuJSON at revision
// 2ac7d3dcd7ad1ff64ebdb14022bf94c59b3b4953.
// Copyright (c) 2024 Ashkan Vedadi Gargary, Soroosh Safari Loaliyan,
// and Zhijia Zhao. Licensed under the MIT License; see
// ../../third_party/licenses/cuJSON-MIT.txt.

using uint8_t = unsigned char;
using uint32_t = unsigned int;
using uint64_t = unsigned long long;
using int32_t = int;
using size_t = unsigned long long;

#define __global__
#define __device__
#define __host__
#define __forceinline__ inline
#define __noinline__ __attribute__((noinline))
#define __shared__

constexpr int ROW2 = 2;
constexpr int ROW3 = 3;
constexpr int ROW4 = 4;
constexpr int ROW5 = 5;
constexpr int BLOCKSIZE = 256;

struct Dim3 { int x; };
Dim3 blockIdx, blockDim, threadIdx, gridDim;

inline uint32_t __popc(uint32_t x) { return __builtin_popcount(x); }
inline uint32_t __clz(uint32_t x) { return x == 0 ? 32u : static_cast<uint32_t>(__builtin_clz(x)); }

// Portable definitions of the CUDA packed-byte intrinsics keep the prepared
// source executable by an ordinary C++ frontend and, importantly, preserve
// the data flow from both current and previous UTF input words.
inline uint32_t __vcmpeq4(uint32_t lhs, uint32_t rhs) {
    uint32_t result = 0u;
    for (uint32_t lane = 0; lane < 4u; ++lane) {
        uint32_t shift = lane * 8u;
        uint32_t lhs_byte = (lhs >> shift) & 0xffu;
        uint32_t rhs_byte = (rhs >> shift) & 0xffu;
        if (lhs_byte == rhs_byte) result |= 0xffu << shift;
    }
    return result;
}

inline uint32_t __vcmpltu4(uint32_t lhs, uint32_t rhs) {
    uint32_t result = 0u;
    for (uint32_t lane = 0; lane < 4u; ++lane) {
        uint32_t shift = lane * 8u;
        uint32_t lhs_byte = (lhs >> shift) & 0xffu;
        uint32_t rhs_byte = (rhs >> shift) & 0xffu;
        if (lhs_byte < rhs_byte) result |= 0xffu << shift;
    }
    return result;
}

inline uint32_t __vcmpgeu4(uint32_t lhs, uint32_t rhs) {
    uint32_t result = 0u;
    for (uint32_t lane = 0; lane < 4u; ++lane) {
        uint32_t shift = lane * 8u;
        uint32_t lhs_byte = (lhs >> shift) & 0xffu;
        uint32_t rhs_byte = (rhs >> shift) & 0xffu;
        if (lhs_byte >= rhs_byte) result |= 0xffu << shift;
    }
    return result;
}

inline uint32_t __vcmpgtu4(uint32_t lhs, uint32_t rhs) {
    uint32_t result = 0u;
    for (uint32_t lane = 0; lane < 4u; ++lane) {
        uint32_t shift = lane * 8u;
        uint32_t lhs_byte = (lhs >> shift) & 0xffu;
        uint32_t rhs_byte = (rhs >> shift) & 0xffu;
        if (lhs_byte > rhs_byte) result |= 0xffu << shift;
    }
    return result;
}

inline uint32_t __vsubus4(uint32_t lhs, uint32_t rhs) {
    uint32_t result = 0u;
    for (uint32_t lane = 0; lane < 4u; ++lane) {
        uint32_t shift = lane * 8u;
        uint32_t lhs_byte = (lhs >> shift) & 0xffu;
        uint32_t rhs_byte = (rhs >> shift) & 0xffu;
        uint32_t difference = lhs_byte > rhs_byte ? lhs_byte - rhs_byte : 0u;
        result |= difference << shift;
    }
    return result;
}

inline int32_t __vsubss4(int32_t lhs, int32_t rhs) {
    uint32_t result = 0u;
    for (uint32_t lane = 0; lane < 4u; ++lane) {
        uint32_t shift = lane * 8u;
        int lhs_byte = static_cast<int>(
            static_cast<signed char>((static_cast<uint32_t>(lhs) >> shift) & 0xffu));
        int rhs_byte = static_cast<int>(
            static_cast<signed char>((static_cast<uint32_t>(rhs) >> shift) & 0xffu));
        int difference = lhs_byte - rhs_byte;
        if (difference > 127) difference = 127;
        if (difference < -128) difference = -128;
        result |= (static_cast<uint32_t>(difference) & 0xffu) << shift;
    }
    return static_cast<int32_t>(result);
}

inline int cudaMallocAsync(uint32_t** ptr, size_t, int) { *ptr = nullptr; return 0; }
inline int cudaMemsetAsync(uint32_t*, int, size_t, int) { return 0; }
inline int cudaStreamSynchronize(int) { return 0; }

#line 139 "upstream/cuJSON/utils.cu"
__device__ __forceinline__
uint32_t prefix_xor(uint32_t x) {
    x ^= (x << 1);   // XOR with left-shifted version by 1 bit.
    x ^= (x << 2);   // XOR with left-shifted version by 2 bits.
    x ^= (x << 4);   // XOR with left-shifted version by 4 bits.
    x ^= (x << 8);   // XOR with left-shifted version by 8 bits.
    x ^= (x << 16);  // XOR with left-shifted version by 16 bits.
    return x;        // Returns the resulting XOR value.
}

#line 313 "upstream/cuJSON/parse_standard_json.cu"
// These helpers preserve cuJSON's packed four-byte UTF-8 validation. Each
// validation thread reads its current input word and the immediately preceding
// word so byte sequences that cross a word boundary are checked explicitly.
__device__ __forceinline__
uint32_t classifyUtf8FourBytes(uint32_t current, uint32_t previous_byte) {
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
        ((__vcmpeq4(previous_byte, 0xc0c0c0c0u) |
          __vcmpeq4(previous_byte, 0xc1c1c1c1u)) & overlong_2) |
        (__vcmpeq4(previous_byte, 0xededededu) & surrogate) |
        (__vcmpeq4(previous_byte, 0xe0e0e0e0u) & overlong_3) |
        (__vcmpeq4(previous_byte, 0xf0f0f0f0u) & overlong_4) |
        (__vcmpgtu4(previous_byte, 0xf4f4f4f4u) & too_large_1000) |
        (__vcmpgtu4(previous_byte, 0xf3f3f3f3u) & too_large);
    first_byte = __vcmpeq4(first_byte, 0u) & two_continuations;

    uint32_t current_high = (current >> 4u) & 0x0f0f0f0fu;
    uint32_t less_than_12 = __vcmpltu4(current_high, 0x0c0c0c0cu);
    uint32_t second_byte_high =
        ((__vcmpltu4(current_high, 0x08080808u) |
          __vcmpgtu4(current_high, 0x0b0b0b0bu)) & too_short) |
        (less_than_12 & __vcmpgeu4(current_high, 0x08080808u) &
         (too_long | overlong_2 | two_continuations)) |
        (less_than_12 & __vcmpgtu4(current_high, 0x08080808u) & too_large) |
        (__vcmpeq4(current_high, 0x08080808u) &
         (too_large_1000 | overlong_4)) |
        (__vcmpgtu4(current_high, 0x09090909u) & less_than_12 & surrogate);
    return first_byte & second_byte_high;
}

__device__ __forceinline__
uint32_t checkUtf8ContinuationBytes(uint32_t previous_two_bytes,
                                    uint32_t previous_three_bytes,
                                    uint32_t classification) {
    constexpr uint32_t maximum_two_byte = 0xdfdfdfdfu;
    constexpr uint32_t maximum_three_byte = 0xefefefefu;
    uint32_t third_byte = __vsubus4(previous_two_bytes, maximum_two_byte);
    uint32_t fourth_byte = __vsubus4(previous_three_bytes, maximum_three_byte);
    uint32_t greater = static_cast<uint32_t>(
        __vsubss4(static_cast<int32_t>(third_byte | fourth_byte), 0));
    uint32_t must_be_continuation = __vcmpgtu4(greater, 0u);
    return (must_be_continuation & 0x80808080u) ^ classification;
}

__device__ __forceinline__
uint32_t validateUtf8FourBytes(uint32_t current, uint32_t previous) {
    constexpr uint32_t maximum_leading_bytes =
        (0xbfu << 24u) | (0xdfu << 16u) | (0xefu << 8u) | 0xffu;
    uint32_t previous_incomplete = __vsubus4(previous, maximum_leading_bytes);
    if ((current & 0x80808080u) == 0u) {
        return previous_incomplete;
    }

    uint64_t adjacent = (static_cast<uint64_t>(current) << 32u) | previous;
    uint32_t previous_one_byte = static_cast<uint32_t>(adjacent >> 24u);
    uint32_t previous_two_bytes = static_cast<uint32_t>(adjacent >> 16u);
    uint32_t previous_three_bytes = static_cast<uint32_t>(adjacent >> 8u);
    uint32_t classification = classifyUtf8FourBytes(current, previous_one_byte);
    return checkUtf8ContinuationBytes(previous_two_bytes,
                                      previous_three_bytes,
                                      classification);
}

#line 513 "upstream/cuJSON/parse_standard_json.cu"
__global__ __noinline__
void checkAscii(uint32_t* input_words,
                int input_word_count,
                uint32_t* has_non_ascii_GPU) {
    int index = blockIdx.x * blockDim.x + threadIdx.x;
    int stride = blockDim.x * gridDim.x;

    for (int word = index; word < input_word_count; word += stride) {
        if ((input_words[word] & 0x80808080u) != 0u) {
            has_non_ascii_GPU[0] = 1u;
        }
    }
}

#line 537 "upstream/cuJSON/parse_standard_json.cu"
__global__ __noinline__
void checkUTF8(uint32_t* input_words,
               uint32_t* utf8_error_GPU,
               int input_word_count) {
    int index = blockIdx.x * blockDim.x + threadIdx.x;
    int stride = blockDim.x * gridDim.x;

    for (int word = index; word < input_word_count; word += stride) {
        uint32_t current = input_words[word];
        uint32_t previous = word > 0 ? input_words[word - 1] : 0u;
        uint32_t error = validateUtf8FourBytes(current, previous);
        if (error != 0u) {
            utf8_error_GPU[0] = error;
        }
    }
}

#line 448 "upstream/cuJSON/parse_standard_json.cu"
__device__ __forceinline__
void classifyEightByteWords(uint32_t block,
                            uint32_t block_2,
                            bool has_second_word,
                            uint8_t& res_slash,
                            uint8_t& res_quote,
                            uint8_t& res_op,
                            uint8_t& res_open_close) {
    uint32_t temp_res_slash = (__vcmpeq4(block, 0x5C5C5C5C) & 0x01010101);
    uint32_t temp_res_quote = (__vcmpeq4(block, 0x22222222) & 0x01010101);
    uint32_t temp_open_close = ((
                __vcmpeq4(block, 0x5B5B5B5B) |
                __vcmpeq4(block, 0x5D5D5D5D) |
                __vcmpeq4(block, 0x7B7B7B7B) |
                __vcmpeq4(block, 0x7D7D7D7D)) & 0x01010101);
    uint32_t temp_colon_comma = ((
                __vcmpeq4(block, 0x3A3A3A3A) |
                __vcmpeq4(block, 0x2C2C2C2C)) & 0x01010101);
    uint32_t temp_res_op = temp_colon_comma | temp_open_close;

    res_slash = 0;
    res_quote = 0;
    res_op = 0;
    res_open_close = 0;

    if (!has_second_word) {
        for (int j = 0; j < 4; ++j) {
            res_slash = static_cast<uint8_t>(static_cast<uint32_t>(res_slash) | ((temp_res_slash >> (j * 7)) & 0x0F));
            res_quote = static_cast<uint8_t>(static_cast<uint32_t>(res_quote) | ((temp_res_quote >> (j * 7)) & 0x0F));
            res_op = static_cast<uint8_t>(static_cast<uint32_t>(res_op) | ((temp_res_op >> (j * 7)) & 0x0F));
            res_open_close = static_cast<uint8_t>(static_cast<uint32_t>(res_open_close) | ((temp_open_close >> (j * 7)) & 0x0F));
        }
        return;
    }

    uint32_t temp2_res_slash = (__vcmpeq4(block_2, 0x5C5C5C5C) & 0x01010101);
    uint32_t temp2_res_quote = (__vcmpeq4(block_2, 0x22222222) & 0x01010101);
    uint32_t temp2_open_close = ((
                __vcmpeq4(block_2, 0x5B5B5B5B) |
                __vcmpeq4(block_2, 0x5D5D5D5D) |
                __vcmpeq4(block_2, 0x7B7B7B7B) |
                __vcmpeq4(block_2, 0x7D7D7D7D)) & 0x01010101);
    uint32_t temp2_colon_comma = ((
                __vcmpeq4(block_2, 0x3A3A3A3A) |
                __vcmpeq4(block_2, 0x2C2C2C2C)) & 0x01010101);
    uint32_t temp2_res_op = temp2_colon_comma | temp2_open_close;

    for (int j = 0; j < 4; ++j) {
        res_slash = static_cast<uint8_t>(static_cast<uint32_t>(res_slash) | ((temp_res_slash >> (j * 7)) & 0x0F) | (((temp2_res_slash >> (j * 7)) & 0x0F) << 4));
        res_quote = static_cast<uint8_t>(static_cast<uint32_t>(res_quote) | ((temp_res_quote >> (j * 7)) & 0x0F) | (((temp2_res_quote >> (j * 7)) & 0x0F) << 4));
        res_op = static_cast<uint8_t>(static_cast<uint32_t>(res_op) | ((temp_res_op >> (j * 7)) & 0x0F) | (((temp2_res_op >> (j * 7)) & 0x0F) << 4));
        res_open_close = static_cast<uint8_t>(static_cast<uint32_t>(res_open_close) | ((temp_open_close >> (j * 7)) & 0x0F) | (((temp2_open_close >> (j * 7)) & 0x0F) << 4));
    }
}

__device__ __forceinline__
uint32_t filterEscapedQuotesWord(uint32_t current_word_quote, uint32_t backslashes, uint32_t overflow) {
    const uint32_t evenBits = 0x55555555UL;
    const uint32_t oddBits = ~evenBits;

    backslashes = backslashes & (~overflow);
    uint32_t applyEscapedChar = (backslashes << 1) | overflow;
    uint32_t oddSequence = backslashes & oddBits & ~applyEscapedChar;
    uint32_t sequenceStartatEven = oddSequence + backslashes;
    uint32_t invert_mask = sequenceStartatEven << 1;
    uint32_t escaped = (evenBits ^ invert_mask) & applyEscapedChar;
    return (~escaped) & current_word_quote;
}

__global__
void bitMapCreatorSimd(uint32_t* block_GPU,
                       uint8_t* outputSlash,
                       uint8_t* outputQuote,
                       uint8_t* op_GPU,
                       uint8_t* open_close_GPU,
                       uint64_t size,
                       int total_padded_8) {
    int index = blockIdx.x * blockDim.x + threadIdx.x;
    int stride = blockDim.x * gridDim.x;

    for (int i = index; i < total_padded_8; i += stride) {
        uint32_t start_word = static_cast<uint32_t>(i) * 2u;
        uint32_t block = block_GPU[start_word];
        uint64_t second_word_start = static_cast<uint64_t>(i) * 8u + 4u;
        bool has_second_word = second_word_start < size;
        uint32_t block_2 = has_second_word ? block_GPU[start_word + 1u] : 0u;

        uint8_t res_slash = 0u;
        uint8_t res_quote = 0u;
        uint8_t res_op = 0u;
        uint8_t res_open_close = 0u;
        classifyEightByteWords(block, block_2, has_second_word, res_slash, res_quote, res_op, res_open_close);

        outputSlash[i] = res_slash;
        outputQuote[i] = res_quote;
        op_GPU[i] = res_op;
        open_close_GPU[i] = res_open_close;
    }
}

__global__
void findEscapedQuoteMerge_NEW(uint32_t* backslashes_GPU,
                               uint32_t* quote_GPU,
                               uint32_t* real_quote_GPU,
                               int size,
                               int total_padded_32,
                               int WORDS) {
    int index = blockIdx.x * blockDim.x + threadIdx.x;
    int stride = blockDim.x * gridDim.x;

    for (int i = index; i < total_padded_32; i += stride) {
        int start = i * WORDS;
        #pragma unroll
        for (int k = start; k < size && k < start + WORDS; ++k) {
            uint32_t overflow = 2u;
            if (k == 0) {
                overflow = 0u;
            } else {
                int j = k - 1;
                while (overflow == 2u && j >= 0) {
                    uint32_t backslash_j = backslashes_GPU[j];
                    uint32_t trailing_backslashes = static_cast<uint32_t>(__clz(~backslash_j));
                    overflow = (trailing_backslashes == 32u) ? 2u : (trailing_backslashes & 1u);
                    --j;
                }
                if (overflow == 2u) {
                    overflow = 0u;
                }
            }

            uint32_t current_word_quote = quote_GPU[k];
            uint32_t slash_word = backslashes_GPU[k];
            uint32_t possible_escaped_quote = current_word_quote & ((slash_word << 1u) | overflow);
            uint32_t real_quote = possible_escaped_quote == 0u
                                      ? current_word_quote
                                      : filterEscapedQuotesWord(current_word_quote, slash_word, overflow);
            real_quote_GPU[k] = real_quote;
            quote_GPU[k] = static_cast<uint32_t>(__popc(real_quote));
        }
    }
}

__global__
void inStringFinderBaseline(uint32_t* real_quote_GPU,
                            uint32_t* prefix_sum_ones,
                            uint32_t* res,
                            int total_padded_32) {
    int index = blockIdx.x * blockDim.x + threadIdx.x;
    int stride = blockDim.x * gridDim.x;

    for (int i = index; i < total_padded_32; i += stride) {
        bool overflow = (prefix_sum_ones[i] & 1u) != 0u;
        uint32_t in_string = prefix_xor(real_quote_GPU[i]);
        res[i] = overflow ? ~in_string : in_string;
    }
}

__global__
void findOutUsefulStringMerge(uint32_t* op_GPU,
                              uint32_t* open_close_GPU,
                              uint32_t* inString_GPU,
                              uint64_t size,
                              int total_padded_32,
                              int WORDS,
                              uint32_t* total_bits) {
    int index = blockIdx.x * blockDim.x + threadIdx.x;
    int stride = blockDim.x * gridDim.x;

    for (int i = index; i < total_padded_32; i += stride) {
        int start = i * WORDS;
        #pragma unroll
        for (int k = start; k < size && k < start + WORDS; ++k) {
            uint32_t all_structural = op_GPU[k];
            uint32_t open_close = open_close_GPU[k];
            uint32_t in_string = inString_GPU[k];

            uint32_t structural = ~in_string & all_structural;
            uint32_t filtered_open_close = ~in_string & open_close;
            inString_GPU[k] = structural;
            open_close_GPU[k] = filtered_open_close;
            total_bits[k] = static_cast<uint32_t>(__popc(structural));
            op_GPU[k] = static_cast<uint32_t>(__popc(filtered_open_close));
        }
    }
}

// Prepared original cuJSON pipeline through the structural-bitmap endpoint used
// by the mypc experiment. CUDA launches are ordinary calls so the Polygeist C++
// frontend sees their memory accesses and stage order deterministically.
void thrust_exclusive_scan_quote_count(uint32_t* input,
                                       uint32_t* output,
                                       int total_padded_32);

extern "C" void cujson_tokenizer(uint32_t* block_GPU,
                                  uint32_t* has_non_ascii_GPU,
                                  uint32_t* utf8_error_GPU,
                                  uint32_t* backslashes_GPU,
                                  uint32_t* quote_GPU,
                                  uint32_t* real_quote_GPU,
                                  uint32_t* in_string_GPU,
                                  uint32_t* op_GPU,
                                  uint32_t* open_close_GPU,
                                  uint32_t* structural_count_GPU,
                                  uint64_t size,
                                  int total_padded_8,
                                  int total_padded_32,
                                  int total_padded_8B,
                                  int bitmap_words_per_thread) {
    int input_word_count = static_cast<int>((size + 3u) / 4u);

    // The original host path skips checkUTF8 for ASCII-only input. The prepared
    // analysis path calls both stages conservatively so every possible input
    // follows one deterministic stage sequence.
    checkAscii(block_GPU,
               input_word_count,
               has_non_ascii_GPU);
    checkUTF8(block_GPU,
              utf8_error_GPU,
              input_word_count);

    bitMapCreatorSimd(block_GPU,
                      reinterpret_cast<uint8_t*>(backslashes_GPU),
                      reinterpret_cast<uint8_t*>(quote_GPU),
                      reinterpret_cast<uint8_t*>(op_GPU),
                      reinterpret_cast<uint8_t*>(open_close_GPU),
                      size,
                      total_padded_8);

    findEscapedQuoteMerge_NEW(backslashes_GPU,
                              quote_GPU,
                              real_quote_GPU,
                              total_padded_32,
                              total_padded_8B,
                              bitmap_words_per_thread);

    uint32_t* quote_prefix_GPU = quote_GPU;
    thrust_exclusive_scan_quote_count(quote_prefix_GPU,
                                      quote_prefix_GPU,
                                      total_padded_32);

    inStringFinderBaseline(real_quote_GPU,
                           quote_prefix_GPU,
                           in_string_GPU,
                           total_padded_32);

    findOutUsefulStringMerge(op_GPU,
                             open_close_GPU,
                             in_string_GPU,
                             total_padded_32,
                             total_padded_8B,
                             bitmap_words_per_thread,
                             structural_count_GPU);
}
