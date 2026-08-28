#pragma once

#include <cuda_runtime.h>

#include <cstdint>

constexpr uint32_t FULL_THREADS = 256;
constexpr uint32_t FULL_WORDS_PER_THREAD = 4u;
constexpr uint32_t FULL_LOOKBACK_THREADS = 512u;
constexpr uint32_t FULL_CHUNK_WORDS = FULL_LOOKBACK_THREADS * FULL_WORDS_PER_THREAD;

__device__ __forceinline__ uint32_t fullPrefixXorWord(uint32_t value) {
    value ^= value << 1u;
    value ^= value << 2u;
    value ^= value << 4u;
    value ^= value << 8u;
    value ^= value << 16u;
    return value;
}

// These are cuJSON's original packed four-byte UTF-8 checks, with only names
// and unused parameters removed. Each call treats a uint32_t as four bytes.
__device__ __forceinline__ uint32_t fullCujsonUtf8Classification(uint32_t current, uint32_t previous_byte) {
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

__device__ __forceinline__ uint32_t fullCujsonUtf8ContinuationBytes(
    uint32_t previous_two_bytes, uint32_t previous_three_bytes, uint32_t classification) {
    constexpr uint32_t maximum_two_byte = 0xdfdfdfdfu;
    constexpr uint32_t maximum_three_byte = 0xefefefefu;
    uint32_t third_byte = __vsubus4(previous_two_bytes, maximum_two_byte);
    uint32_t fourth_byte = __vsubus4(previous_three_bytes, maximum_three_byte);
    uint32_t greater = static_cast<uint32_t>(__vsubss4(
        static_cast<int32_t>(third_byte | fourth_byte), 0));
    uint32_t must_be_continuation = __vcmpgtu4(greater, 0u);
    return (must_be_continuation & 0x80808080u) ^ classification;
}

__device__ __forceinline__ uint32_t fullCujsonValidateUtf8FourBytes(uint32_t current, uint32_t previous) {
    constexpr uint32_t maximum_leading_bytes =
        (0xbfu << 24u) | (0xdfu << 16u) | (0xefu << 8u) | 0xffu;
    uint32_t previous_incomplete = __vsubus4(previous, maximum_leading_bytes);
    if ((current & 0x80808080u) == 0u) return previous_incomplete;

    uint64_t adjacent = (static_cast<uint64_t>(current) << 32u) | previous;
    uint32_t previous_one_byte = static_cast<uint32_t>(adjacent >> 24u);
    uint32_t previous_two_bytes = static_cast<uint32_t>(adjacent >> 16u);
    uint32_t previous_three_bytes = static_cast<uint32_t>(adjacent >> 8u);
    uint32_t classification = fullCujsonUtf8Classification(current, previous_one_byte);
    return fullCujsonUtf8ContinuationBytes(previous_two_bytes, previous_three_bytes, classification);
}

__device__ __forceinline__ uint32_t fullFilterEscapedQuotesWord(uint32_t quote, uint32_t backslashes,
                                                                uint32_t overflow) {
    const uint32_t even_bits = 0x55555555u;
    const uint32_t odd_bits = ~even_bits;
    backslashes &= ~overflow;
    uint32_t apply_escaped = (backslashes << 1u) | overflow;
    uint32_t odd_sequence = backslashes & odd_bits & ~apply_escaped;
    uint32_t sequence_start_even = odd_sequence + backslashes;
    uint32_t escaped = (even_bits ^ (sequence_start_even << 1u)) & apply_escaped;
    return (~escaped) & quote;
}

__device__ __forceinline__ uint32_t fullPackMatches(uint32_t matches) {
    uint32_t bits = 0u;
    #pragma unroll
    for (uint32_t byte = 0; byte < 4u; ++byte) bits |= (matches >> (byte * 7u)) & 0x0fu;
    return bits;
}

__device__ __forceinline__ void fullClassifyWord(const uint8_t* input, uint64_t input_size, uint32_t word,
    uint32_t& slash_word, uint32_t& quote_word, uint32_t& operator_word, uint32_t& open_close_word,
    uint32_t& non_ascii) {
    uint64_t byte_start = static_cast<uint64_t>(word) * 32u;
    slash_word = 0u;
    quote_word = 0u;
    operator_word = 0u;
    open_close_word = 0u;
    non_ascii = 0u;

    uint32_t loaded[8];
    if (byte_start + 31u < input_size) {
        const uint4* vectors = reinterpret_cast<const uint4*>(input);
        uint4 first = vectors[word * 2u];
        uint4 second = vectors[word * 2u + 1u];
        loaded[0] = first.x;
        loaded[1] = first.y;
        loaded[2] = first.z;
        loaded[3] = first.w;
        loaded[4] = second.x;
        loaded[5] = second.y;
        loaded[6] = second.z;
        loaded[7] = second.w;
    } else {
        #pragma unroll
        for (uint32_t chunk = 0u; chunk < 8u; ++chunk) {
            uint64_t position = byte_start + chunk * 4u;
            loaded[chunk] = position < input_size ? *reinterpret_cast<const uint32_t*>(input + position) : 0u;
        }
    }

    #pragma unroll
    for (uint32_t chunk = 0; chunk < 8u; ++chunk) {
        uint32_t value = loaded[chunk];
        non_ascii |= value;
        uint32_t slash = __vcmpeq4(value, 0x5c5c5c5cu) & 0x01010101u;
        uint32_t quote = __vcmpeq4(value, 0x22222222u) & 0x01010101u;
        uint32_t open_close = (__vcmpeq4(value, 0x5b5b5b5bu) | __vcmpeq4(value, 0x5d5d5d5du) |
                               __vcmpeq4(value, 0x7b7b7b7bu) | __vcmpeq4(value, 0x7d7d7d7du)) & 0x01010101u;
        uint32_t colon_comma = (__vcmpeq4(value, 0x3a3a3a3au) |
                                __vcmpeq4(value, 0x2c2c2c2cu)) & 0x01010101u;
        slash_word |= fullPackMatches(slash) << (chunk * 4u);
        quote_word |= fullPackMatches(quote) << (chunk * 4u);
        open_close_word |= fullPackMatches(open_close) << (chunk * 4u);
        operator_word |= fullPackMatches(open_close | colon_comma) << (chunk * 4u);
    }

    uint64_t bytes_left = byte_start < input_size ? input_size - byte_start : 0u;
    if (bytes_left < 32u) {
        uint32_t valid_mask = bytes_left == 0u ? 0u : 0xffffffffu >> (32u - bytes_left);
        slash_word &= valid_mask;
        quote_word &= valid_mask;
        operator_word &= valid_mask;
        open_close_word &= valid_mask;
    }

}

__device__ __forceinline__ void fullClassifyWord(const uint8_t* input, uint64_t input_size, uint32_t word,
    uint32_t& slash_word, uint32_t& quote_word, uint32_t& operator_word, uint32_t& open_close_word) {
    uint32_t non_ascii = 0u;
    fullClassifyWord(input, input_size, word, slash_word, quote_word, operator_word, open_close_word, non_ascii);
}
