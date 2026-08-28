#pragma once

#include <cuda_runtime.h>

#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

// GPJSON's source launch geometry. The original implementation divides the
// complete byte stream among this fixed logical grid.
constexpr int GP4_ORIGINAL_GRID = 16384;
constexpr int GP4_ORIGINAL_BLOCK = 1024;
constexpr int GP4_ORIGINAL_THREADS = GP4_ORIGINAL_GRID * GP4_ORIGINAL_BLOCK;
constexpr int GP4_SCAN_GRID = 32;
constexpr int GP4_SCAN_BLOCK = 32;
constexpr int GP4_SCAN_THREADS = GP4_SCAN_GRID * GP4_SCAN_BLOCK;

constexpr std::size_t GP4_WORD_BYTES = 64;

#ifndef GP4_CUDA_CHECK
#define GP4_CUDA_CHECK(call) do {                                                     \
    cudaError_t gp4_error = (call);                                                   \
    if (gp4_error != cudaSuccess) {                                                   \
        std::cerr << "CUDA error: " << cudaGetErrorString(gp4_error) << " at "        \
                  << __FILE__ << ':' << __LINE__ << '\n';                            \
        std::exit(1);                                                                 \
    }                                                                                 \
} while (0)
#endif

__host__ __device__ __forceinline__ bool gp4IsStructural(uint8_t value) {
    return value == '{' || value == '}' || value == '[' || value == ']' ||
           value == ':' || value == ',';
}

// GPJSON computes the inclusive quote prefix with these six XOR shifts.
__host__ __device__ __forceinline__ uint64_t gp4PrefixXor64(uint64_t quotes) {
    quotes ^= quotes << 1;
    quotes ^= quotes << 2;
    quotes ^= quotes << 4;
    quotes ^= quotes << 8;
    quotes ^= quotes << 16;
    quotes ^= quotes << 32;
    return quotes;
}

inline std::vector<uint8_t> gp4ReadFile(const std::string& path) {
    std::ifstream stream(path, std::ios::binary | std::ios::ate);
    if (!stream) throw std::runtime_error("cannot open input: " + path);
    const std::streamsize size = stream.tellg();
    stream.seekg(0);
    std::vector<uint8_t> bytes(static_cast<std::size_t>(size));
    if (size > 0 && !stream.read(reinterpret_cast<char*>(bytes.data()), size))
        throw std::runtime_error("cannot read input: " + path);
    return bytes;
}

inline uint64_t gp4Mix64(uint64_t value) {
    value += 0x9e3779b97f4a7c15ull;
    value = (value ^ (value >> 30)) * 0xbf58476d1ce4e5b9ull;
    value = (value ^ (value >> 27)) * 0x94d049bb133111ebull;
    return value ^ (value >> 31);
}

inline uint64_t gp4HashWords(const std::vector<uint64_t>& words) {
    uint64_t hash = 0x6a09e667f3bcc909ull;
    for (std::size_t index = 0; index < words.size(); ++index) {
        hash ^= gp4Mix64(words[index] ^
                         (index * 0x9e3779b97f4a7c15ull));
        hash = (hash << 13) | (hash >> 51);
    }
    return hash;
}

inline std::vector<uint64_t> gp4CpuStructuralBitmap(
    const std::vector<uint8_t>& input) {
    std::vector<uint64_t> structural((input.size() + 63) / 64, 0ull);
    bool escape = false;
    bool in_string = false;
    for (std::size_t position = 0; position < input.size(); ++position) {
        const uint8_t value = input[position];
        if (value == '"' && !escape) in_string = !in_string;
        if (!in_string && gp4IsStructural(value))
            structural[position >> 6] |= 1ull << (position & 63u);
        escape = value == '\\' ? !escape : false;
    }
    return structural;
}

inline uint64_t gp4CpuStructuralHash(const std::vector<uint8_t>& input) {
    return gp4HashWords(gp4CpuStructuralBitmap(input));
}
