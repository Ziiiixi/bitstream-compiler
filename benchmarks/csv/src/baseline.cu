#include <cuda_runtime.h>
#include <cub/cub.cuh>

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <limits>
#include <numeric>
#include <string>
#include <vector>

#define CHECK_CUDA(call)                                                        \
  do {                                                                          \
    const cudaError_t error__ = (call);                                          \
    if (error__ != cudaSuccess) {                                                \
      std::fprintf(stderr, "CUDA error %s:%d: %s\n", __FILE__, __LINE__,         \
                   cudaGetErrorString(error__));                                 \
      std::exit(EXIT_FAILURE);                                                   \
    }                                                                           \
  } while (0)

namespace {

constexpr int kBlockSize = 256;
constexpr int kChunkBytes = 256;

template <typename T>
T ceil_div(T value, T divisor) {
  return (value + divisor - 1) / divisor;
}

struct XorByte {
  __host__ __device__ uint8_t operator()(const uint8_t &a,
                                         const uint8_t &b) const {
    return a ^ b;
  }
};

__global__ void csv_classify_kernel(const uint8_t *input, uint8_t *quote,
                                    uint8_t *comma, size_t size) {
  const size_t i =
      static_cast<size_t>(blockIdx.x) * blockDim.x + threadIdx.x;
  if (i >= size)
    return;

  const uint8_t c = input[i];
  quote[i] = (c == '"');
  comma[i] = (c == ',');
}

__global__ void csv_summary_from_quote_kernel(const uint8_t *quote,
                                              uint8_t *parity, size_t size,
                                              int chunk_bytes) {
  const size_t chunk =
      static_cast<size_t>(blockIdx.x) * blockDim.x + threadIdx.x;
  const size_t begin = chunk * static_cast<size_t>(chunk_bytes);
  if (begin >= size)
    return;

  const size_t end =
      min(begin + static_cast<size_t>(chunk_bytes), size);
  uint8_t value = 0;
  for (size_t i = begin; i < end; ++i)
    value ^= quote[i];
  parity[chunk] = value;
}

__global__ void csv_count_from_masks_kernel(const uint8_t *quote,
                                            const uint8_t *comma,
                                            const uint8_t *prefix,
                                            uint32_t *counts, size_t size,
                                            int chunk_bytes) {
  const size_t chunk =
      static_cast<size_t>(blockIdx.x) * blockDim.x + threadIdx.x;
  const size_t begin = chunk * static_cast<size_t>(chunk_bytes);
  if (begin >= size)
    return;

  const size_t end =
      min(begin + static_cast<size_t>(chunk_bytes), size);
  uint8_t inside_quote = prefix[chunk];
  uint32_t count = 0;
  for (size_t i = begin; i < end; ++i) {
    if (quote[i])
      inside_quote ^= 1;
    if (comma[i] && !inside_quote)
      ++count;
  }
  counts[chunk] = count;
}

std::vector<uint8_t> read_input(const char *path) {
  std::ifstream input(path, std::ios::binary | std::ios::ate);
  if (!input) {
    std::fprintf(stderr, "error: cannot open input: %s\n", path);
    std::exit(EXIT_FAILURE);
  }

  const std::streamoff end = input.tellg();
  if (end < 0 || static_cast<uintmax_t>(end) >
                     static_cast<uintmax_t>(
                         std::numeric_limits<std::streamsize>::max())) {
    std::fprintf(stderr, "error: input is too large to read: %s\n", path);
    std::exit(EXIT_FAILURE);
  }

  std::vector<uint8_t> bytes(static_cast<size_t>(end));
  input.seekg(0, std::ios::beg);
  if (!bytes.empty() &&
      !input.read(reinterpret_cast<char *>(bytes.data()),
                  static_cast<std::streamsize>(bytes.size()))) {
    std::fprintf(stderr, "error: failed while reading input: %s\n", path);
    std::exit(EXIT_FAILURE);
  }
  return bytes;
}

int parse_runs(const char *text) {
  char *end = nullptr;
  const long value = std::strtol(text, &end, 10);
  if (!text[0] || !end || *end != '\0' || value <= 0 ||
      value > std::numeric_limits<int>::max()) {
    std::fprintf(stderr, "error: runs must be a positive integer\n");
    std::exit(EXIT_FAILURE);
  }
  return static_cast<int>(value);
}

uint64_t cpu_outside_quote_commas(const std::vector<uint8_t> &input) {
  uint8_t inside_quote = 0;
  uint64_t count = 0;
  for (const uint8_t c : input) {
    if (c == '"')
      inside_quote ^= 1;
    if (c == ',' && !inside_quote)
      ++count;
  }
  return count;
}

} // namespace

int main(int argc, char **argv) {
  if (argc < 2 || argc > 3) {
    std::fprintf(stderr, "usage: %s <input> [runs]\n", argv[0]);
    return EXIT_FAILURE;
  }

  const int runs = argc == 3 ? parse_runs(argv[2]) : 5;
  const std::vector<uint8_t> input = read_input(argv[1]);
  const uint64_t cpu_count = cpu_outside_quote_commas(input);

  if (input.empty()) {
    std::printf("method=baseline bytes=0 runs=%d avg-us=0.000 "
                "gpu-count=0 cpu-count=0 correctness=PASS\n",
                runs);
    return EXIT_SUCCESS;
  }

  const size_t size = input.size();
  const size_t chunks =
      ceil_div(size, static_cast<size_t>(kChunkBytes));
  const size_t byte_blocks =
      ceil_div(size, static_cast<size_t>(kBlockSize));
  const size_t chunk_blocks =
      ceil_div(chunks, static_cast<size_t>(kBlockSize));

  uint8_t *d_input = nullptr;
  uint8_t *d_quote = nullptr;
  uint8_t *d_comma = nullptr;
  uint8_t *d_parity = nullptr;
  uint8_t *d_prefix = nullptr;
  uint32_t *d_counts = nullptr;
  void *d_scan_temp = nullptr;
  size_t scan_temp_bytes = 0;

  CHECK_CUDA(cudaMalloc(&d_input, size));
  CHECK_CUDA(cudaMalloc(&d_quote, size));
  CHECK_CUDA(cudaMalloc(&d_comma, size));
  CHECK_CUDA(cudaMalloc(&d_parity, chunks));
  CHECK_CUDA(cudaMalloc(&d_prefix, chunks));
  CHECK_CUDA(cudaMalloc(&d_counts, chunks * sizeof(uint32_t)));
  CHECK_CUDA(cudaMemcpy(d_input, input.data(), size, cudaMemcpyHostToDevice));

  CHECK_CUDA(cub::DeviceScan::ExclusiveScan(
      nullptr, scan_temp_bytes, d_parity, d_prefix, XorByte{}, uint8_t{0},
      chunks));
  CHECK_CUDA(cudaMalloc(&d_scan_temp, scan_temp_bytes));

  cudaEvent_t start{};
  cudaEvent_t stop{};
  CHECK_CUDA(cudaEventCreate(&start));
  CHECK_CUDA(cudaEventCreate(&stop));

  double total_ms = 0.0;
  for (int run = 0; run < runs; ++run) {
    CHECK_CUDA(cudaEventRecord(start));

    csv_classify_kernel<<<byte_blocks, kBlockSize>>>(
        d_input, d_quote, d_comma, size);
    CHECK_CUDA(cudaGetLastError());

    csv_summary_from_quote_kernel<<<chunk_blocks, kBlockSize>>>(
        d_quote, d_parity, size, kChunkBytes);
    CHECK_CUDA(cudaGetLastError());

    CHECK_CUDA(cub::DeviceScan::ExclusiveScan(
        d_scan_temp, scan_temp_bytes, d_parity, d_prefix, XorByte{},
        uint8_t{0}, chunks));

    csv_count_from_masks_kernel<<<chunk_blocks, kBlockSize>>>(
        d_quote, d_comma, d_prefix, d_counts, size, kChunkBytes);
    CHECK_CUDA(cudaGetLastError());

    CHECK_CUDA(cudaEventRecord(stop));
    CHECK_CUDA(cudaEventSynchronize(stop));
    float elapsed_ms = 0.0f;
    CHECK_CUDA(cudaEventElapsedTime(&elapsed_ms, start, stop));
    total_ms += elapsed_ms;
  }

  std::vector<uint32_t> chunk_counts(chunks);
  CHECK_CUDA(cudaMemcpy(chunk_counts.data(), d_counts,
                        chunks * sizeof(uint32_t), cudaMemcpyDeviceToHost));
  const uint64_t gpu_count =
      std::accumulate(chunk_counts.begin(), chunk_counts.end(), uint64_t{0});
  const bool correct = gpu_count == cpu_count;

  CHECK_CUDA(cudaEventDestroy(start));
  CHECK_CUDA(cudaEventDestroy(stop));
  CHECK_CUDA(cudaFree(d_scan_temp));
  CHECK_CUDA(cudaFree(d_counts));
  CHECK_CUDA(cudaFree(d_prefix));
  CHECK_CUDA(cudaFree(d_parity));
  CHECK_CUDA(cudaFree(d_comma));
  CHECK_CUDA(cudaFree(d_quote));
  CHECK_CUDA(cudaFree(d_input));

  const double average_us = total_ms * 1000.0 / runs;
  std::printf("method=baseline bytes=%zu runs=%d avg-us=%.3f "
              "gpu-count=%llu cpu-count=%llu correctness=%s\n",
              size, runs, average_us,
              static_cast<unsigned long long>(gpu_count),
              static_cast<unsigned long long>(cpu_count),
              correct ? "PASS" : "FAIL");
  if (!correct) {
    std::fprintf(stderr, "validation failed: gpu=%llu cpu=%llu\n",
                 static_cast<unsigned long long>(gpu_count),
                 static_cast<unsigned long long>(cpu_count));
    return 2;
  }
  return EXIT_SUCCESS;
}
