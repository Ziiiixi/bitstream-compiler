#pragma once

#include "gpjson_reference_common.cuh"

// This file is the structural-bitmap-only GPJSON baseline. It is the original
// eight-stage computation with the original fixed launch geometry; only later
// newline and nesting-index stages outside this experiment are omitted.

__device__ __forceinline__ void gp4OriginalSegment(
    std::size_t input_size, int thread_index,
    std::size_t& byte_start, std::size_t& byte_end) {
    const std::size_t bytes_per_thread =
        (input_size + GP4_ORIGINAL_THREADS - 1) / GP4_ORIGINAL_THREADS;
    const std::size_t aligned_bytes =
        ((bytes_per_thread + GP4_WORD_BYTES - 1) / GP4_WORD_BYTES) * GP4_WORD_BYTES;
    byte_start = static_cast<std::size_t>(thread_index) * aligned_bytes;
    byte_end = byte_start + aligned_bytes;
}

__global__ void gp4OriginalEscapeCarryKernel(
    const uint8_t* input, std::size_t input_size, uint8_t* escape_carry) {
    const int thread_index = blockIdx.x * blockDim.x + threadIdx.x;
    std::size_t byte_start, byte_end;
    gp4OriginalSegment(input_size, thread_index, byte_start, byte_end);
    uint8_t carry = 0u;
    for (std::size_t position = byte_start;
         position < byte_end && position < input_size; ++position)
        carry = input[position] == '\\' ? static_cast<uint8_t>(carry ^ 1u) : 0u;
    escape_carry[thread_index] = carry;
}

__global__ void gp4OriginalEscapeBitmapKernel(
    const uint8_t* input, std::size_t input_size,
    const uint8_t* escape_carry, uint64_t* escape_bitmap) {
    const int thread_index = blockIdx.x * blockDim.x + threadIdx.x;
    std::size_t byte_start, byte_end;
    gp4OriginalSegment(input_size, thread_index, byte_start, byte_end);
    uint8_t carry = thread_index == 0 ? 0u : escape_carry[thread_index - 1];
    uint64_t escaped = 0ull;

    for (std::size_t position = byte_start;
         position < byte_end && position < input_size; ++position) {
        const int bit_id = static_cast<int>(position & 63u);
        if (carry != 0u) escaped |= 1ull << bit_id;
        carry = input[position] == '\\' ? static_cast<uint8_t>(carry ^ 1u) : 0u;
        if (bit_id == 63) {
            escape_bitmap[position >> 6] = escaped;
            escaped = 0ull;
        }
    }
    if (input_size <= byte_end && input_size > byte_start &&
        ((input_size - 1) & 63u) != 63u)
        escape_bitmap[(input_size - 1) >> 6] = escaped;
}

__global__ void gp4OriginalQuoteBitmapKernel(
    const uint8_t* input, std::size_t input_size,
    const uint64_t* escape_bitmap, uint64_t* quote_bitmap,
    uint8_t* quote_carry) {
    const int thread_index = blockIdx.x * blockDim.x + threadIdx.x;
    std::size_t byte_start, byte_end;
    gp4OriginalSegment(input_size, thread_index, byte_start, byte_end);
    uint64_t escaped = 0ull;
    uint64_t quotes = 0ull;
    int quote_count = 0;

    for (std::size_t position = byte_start;
         position < byte_end && position < input_size; ++position) {
        const int bit_id = static_cast<int>(position & 63u);
        if (bit_id == 0) escaped = escape_bitmap[position >> 6];
        if (input[position] == '"' && (escaped & (1ull << bit_id)) == 0ull) {
            quotes |= 1ull << bit_id;
            ++quote_count;
        }
        if (bit_id == 63) {
            quote_bitmap[position >> 6] = quotes;
            quotes = 0ull;
        }
    }
    if (input_size <= byte_end && input_size > byte_start &&
        ((input_size - 1) & 63u) != 63u)
        quote_bitmap[(input_size - 1) >> 6] = quotes;
    quote_carry[thread_index] = static_cast<uint8_t>(quote_count & 1);
}

__global__ void gp4OriginalXorPreScanKernel(uint8_t* values, int count) {
    const int thread_index = blockIdx.x * blockDim.x + threadIdx.x;
    const int stride = blockDim.x * gridDim.x;
    const int values_per_thread = (count + stride - 1) / stride;
    const int start = thread_index * values_per_thread;
    const int end = start + values_per_thread;
    uint8_t prefix = 0u;
    for (int index = start; index < end && index < count; ++index) {
        prefix ^= values[index];
        values[index] = prefix;
    }
}

__global__ void gp4OriginalXorPostScanKernel(
    uint8_t* values, int count, int stride, uint8_t* bases) {
    const int values_per_thread = (count + stride - 1) / stride;
    uint8_t prefix = 0u;
    for (int index = 0; index < stride - 1; ++index) {
        bases[index] = prefix;
        prefix ^= values[values_per_thread * (index + 1) - 1];
    }
    bases[stride - 1] = prefix;
}

__global__ void gp4OriginalXorRebaseKernel(
    uint8_t* values, int count, const uint8_t* bases) {
    const int thread_index = blockIdx.x * blockDim.x + threadIdx.x;
    const int stride = blockDim.x * gridDim.x;
    const int values_per_thread = (count + stride - 1) / stride;
    const int start = thread_index * values_per_thread;
    const int end = start + values_per_thread;
    for (int index = start; index < end && index < count; ++index)
        values[index] ^= bases[thread_index];
}

__global__ void gp4OriginalStringBitmapKernel(
    uint64_t* quote_or_string_bitmap, std::size_t input_size,
    std::size_t word_count, const uint8_t* quote_carry) {
    const int thread_index = blockIdx.x * blockDim.x + threadIdx.x;
    std::size_t byte_start, byte_end;
    gp4OriginalSegment(input_size, thread_index, byte_start, byte_end);
    const std::size_t word_start = byte_start >> 6;
    std::size_t word_end = (byte_end + 63) >> 6;
    if (word_end > word_count) word_end = word_count;
    uint64_t incoming_string = thread_index > 0 && quote_carry[thread_index - 1] == 1u
                                   ? 0xffffffffffffffffull : 0ull;

    for (std::size_t word_id = word_start; word_id < word_end; ++word_id) {
        const uint64_t in_string =
            gp4PrefixXor64(quote_or_string_bitmap[word_id]) ^ incoming_string;
        quote_or_string_bitmap[word_id] = in_string;
        incoming_string = (in_string >> 63) != 0ull
                              ? 0xffffffffffffffffull : 0ull;
    }
}

__global__ void gp4OriginalStructuralBitmapKernel(
    const uint8_t* input, std::size_t input_size,
    const uint64_t* string_bitmap, uint64_t* structural_bitmap) {
    const int thread_index = blockIdx.x * blockDim.x + threadIdx.x;
    std::size_t byte_start, byte_end;
    gp4OriginalSegment(input_size, thread_index, byte_start, byte_end);
    uint64_t in_string = 0ull;
    uint64_t structural = 0ull;

    for (std::size_t position = byte_start;
         position < byte_end && position < input_size; ++position) {
        const int bit_id = static_cast<int>(position & 63u);
        if (bit_id == 0) in_string = string_bitmap[position >> 6];
        if ((in_string & (1ull << bit_id)) == 0ull &&
            gp4IsStructural(input[position]))
            structural |= 1ull << bit_id;
        if (bit_id == 63) {
            structural_bitmap[position >> 6] = structural;
            structural = 0ull;
        }
    }
    if (input_size <= byte_end && input_size > byte_start &&
        ((input_size - 1) & 63u) != 63u)
        structural_bitmap[(input_size - 1) >> 6] = structural;
}

inline void gp4LaunchOriginal(
    const uint8_t* input, std::size_t input_size, std::size_t word_count,
    uint8_t* escape_carry, uint8_t* quote_carry, uint8_t* xor_bases,
    uint64_t* escape_bitmap, uint64_t* quote_or_string_bitmap,
    uint64_t* structural_bitmap) {
    gp4OriginalEscapeCarryKernel<<<GP4_ORIGINAL_GRID, GP4_ORIGINAL_BLOCK>>>(
        input, input_size, escape_carry);
    gp4OriginalEscapeBitmapKernel<<<GP4_ORIGINAL_GRID, GP4_ORIGINAL_BLOCK>>>(
        input, input_size, escape_carry, escape_bitmap);
    gp4OriginalQuoteBitmapKernel<<<GP4_ORIGINAL_GRID, GP4_ORIGINAL_BLOCK>>>(
        input, input_size, escape_bitmap, quote_or_string_bitmap, quote_carry);
    gp4OriginalXorPreScanKernel<<<GP4_SCAN_GRID, GP4_SCAN_BLOCK>>>(
        quote_carry, GP4_ORIGINAL_THREADS);
    gp4OriginalXorPostScanKernel<<<1, 1>>>(
        quote_carry, GP4_ORIGINAL_THREADS, GP4_SCAN_THREADS, xor_bases);
    gp4OriginalXorRebaseKernel<<<GP4_SCAN_GRID, GP4_SCAN_BLOCK>>>(
        quote_carry, GP4_ORIGINAL_THREADS, xor_bases);
    gp4OriginalStringBitmapKernel<<<GP4_ORIGINAL_GRID, GP4_ORIGINAL_BLOCK>>>(
        quote_or_string_bitmap, input_size, word_count, quote_carry);
    gp4OriginalStructuralBitmapKernel<<<GP4_ORIGINAL_GRID, GP4_ORIGINAL_BLOCK>>>(
        input, input_size, quote_or_string_bitmap, structural_bitmap);
}
