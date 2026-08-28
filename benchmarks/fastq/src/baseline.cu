// Standalone FASTQ staged baseline.
//
// This file intentionally contains only the reportable baseline pipeline:
//   1. materialize one newline byte per input byte;
//   2. summarize each chunk as (newline count, newline count modulo 4);
//   3. exclusive-scan the modulo-4 chunk state with CUB;
//   4. select the complete-record count for each chunk's incoming phase.
//
// No fused, speculative, hot-state, or recovery implementation is included.

#include <cuda_runtime.h>
#include <cub/cub.cuh>

#include <algorithm>
#include <cerrno>
#include <climits>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <numeric>
#include <string>
#include <vector>

#define CHECK_CUDA(call)                                                       \
  do {                                                                         \
    const cudaError_t error__ = (call);                                        \
    if (error__ != cudaSuccess) {                                              \
      std::fprintf(stderr, "CUDA error %s:%d: %s\n", __FILE__, __LINE__,      \
                   cudaGetErrorString(error__));                               \
      std::exit(EXIT_FAILURE);                                                 \
    }                                                                          \
  } while (0)

// The frozen reportable configuration used BLOCK_SIZE=512 and
// FASTQ_CHUNK=8192. Both remain compile-time-overridable for portability.
#ifndef BLOCK_SIZE
#define BLOCK_SIZE 512
#endif

#ifndef FASTQ_CHUNK
#define FASTQ_CHUNK 8192
#endif

static_assert(BLOCK_SIZE > 0 && BLOCK_SIZE <= 1024,
              "BLOCK_SIZE must be in [1, 1024]");
static_assert((BLOCK_SIZE & (BLOCK_SIZE - 1)) == 0,
              "BLOCK_SIZE must be a power of two");
static_assert(FASTQ_CHUNK > 0 && FASTQ_CHUNK <= INT_MAX,
              "FASTQ_CHUNK must fit in a positive int");

struct FastqMod4Add {
  __host__ __device__ uint8_t operator()(uint8_t a, uint8_t b) const {
    return static_cast<uint8_t>((a + b) & 3u);
  }
};

__host__ __device__ static inline uint64_t
fastq_count_from_newline_count(uint64_t newline_count, uint8_t state) {
  return (newline_count + static_cast<uint64_t>(state & 3u)) >> 2;
}

__device__ static inline size_t fastq_min_size(size_t a, size_t b) {
  return a < b ? a : b;
}

// K1: one byte per input character, materialized in global memory.
__global__ void fastq_newline_kernel(const uint8_t *in,
                                     uint8_t *newline,
                                     size_t n) {
  const size_t i =
      static_cast<size_t>(blockIdx.x) * blockDim.x + threadIdx.x;
  if (i < n)
    newline[i] = (in[i] == '\n');
}

// K2: consume the materialized newline bitmap and emit the reduced chunk
// state needed by the fair baseline.
__global__ void fastq_count_mod_from_newline_cta_kernel(
    const uint8_t *newline,
    uint32_t *newline_count,
    uint8_t *chunk_mod,
    size_t n,
    int chunk) {
  __shared__ uint32_t sh[BLOCK_SIZE];
  const uint32_t tid = threadIdx.x;
  const size_t chunk_id = blockIdx.x;
  const size_t start = chunk_id * static_cast<size_t>(chunk);
  const size_t end = fastq_min_size(start + static_cast<size_t>(chunk), n);

  uint32_t local = 0;
  for (size_t i = start + tid; i < end; i += blockDim.x)
    local += newline[i] != 0;
  sh[tid] = local;
  __syncthreads();

  for (uint32_t stride = blockDim.x >> 1; stride > 0; stride >>= 1) {
    if (tid < stride)
      sh[tid] += sh[tid + stride];
    __syncthreads();
  }

  if (tid == 0) {
    newline_count[chunk_id] = sh[0];
    chunk_mod[chunk_id] = static_cast<uint8_t>(sh[0] & 3u);
  }
}

// K3 is cub::DeviceScan::ExclusiveScan with FastqMod4Add and identity zero.

// K4: select the number of record-completing newlines from the exact incoming
// phase produced by K3.
__global__ void fastq_select_counts_mod_kernel(const uint32_t *newline_count,
                                               const uint8_t *prefix_mod,
                                               uint64_t *counts,
                                               size_t chunks) {
  const size_t chunk_id =
      static_cast<size_t>(blockIdx.x) * blockDim.x + threadIdx.x;
  if (chunk_id >= chunks)
    return;

  counts[chunk_id] = fastq_count_from_newline_count(
      newline_count[chunk_id], prefix_mod[chunk_id]);
}

template <typename T>
static T ceil_div(T numerator, T denominator) {
  return numerator / denominator + (numerator % denominator != 0);
}

static std::vector<uint8_t> read_file(const std::string &path) {
  std::ifstream input(path, std::ios::binary | std::ios::ate);
  if (!input) {
    std::cerr << "error: cannot open input: " << path << '\n';
    std::exit(EXIT_FAILURE);
  }

  const std::streamoff end = input.tellg();
  if (end < 0 || static_cast<uintmax_t>(end) >
                     static_cast<uintmax_t>(
                         std::numeric_limits<size_t>::max())) {
    std::cerr << "error: input size is not representable: " << path << '\n';
    std::exit(EXIT_FAILURE);
  }

  std::vector<uint8_t> bytes(static_cast<size_t>(end));
  input.seekg(0, std::ios::beg);
  if (!bytes.empty() &&
      !input.read(reinterpret_cast<char *>(bytes.data()),
                  static_cast<std::streamsize>(bytes.size()))) {
    std::cerr << "error: failed to read input: " << path << '\n';
    std::exit(EXIT_FAILURE);
  }
  return bytes;
}

static int parse_runs(const char *text) {
  errno = 0;
  char *end = nullptr;
  const long value = std::strtol(text, &end, 10);
  if (errno != 0 || end == text || *end != '\0' || value <= 0 ||
      value > INT_MAX) {
    std::cerr << "error: runs must be a positive integer\n";
    std::exit(EXIT_FAILURE);
  }
  return static_cast<int>(value);
}

struct CpuReference {
  std::vector<uint64_t> chunk_counts;
  uint64_t record_count = 0;
};

static CpuReference cpu_fastq_reference(const std::vector<uint8_t> &text) {
  CpuReference reference;
  const size_t n = text.size();
  const size_t chunk_size = static_cast<size_t>(FASTQ_CHUNK);
  const size_t chunks = ceil_div(n, chunk_size);
  reference.chunk_counts.reserve(chunks);

  uint8_t phase = 0;
  for (size_t chunk_id = 0; chunk_id < chunks; ++chunk_id) {
    const size_t start = chunk_id * chunk_size;
    const size_t end =
        std::min(start + chunk_size, static_cast<size_t>(text.size()));
    uint64_t chunk_records = 0;
    for (size_t i = start; i < end; ++i) {
      if (text[i] != '\n')
        continue;
      if (phase == 3)
        ++chunk_records;
      phase = static_cast<uint8_t>((phase + 1u) & 3u);
    }
    reference.chunk_counts.push_back(chunk_records);
    reference.record_count += chunk_records;
  }
  return reference;
}

static int run_baseline(const std::string &path, int runs) {
  const std::vector<uint8_t> text = read_file(path);
  const CpuReference cpu = cpu_fastq_reference(text);
  const size_t n = text.size();
  const size_t chunks = cpu.chunk_counts.size();

  if (n == 0) {
    std::cout << "method=baseline"
              << " input=" << std::quoted(path)
              << " bytes=0"
              << " runs=" << runs
              << " block-size=" << BLOCK_SIZE
              << " chunk-size=" << FASTQ_CHUNK
              << " chunks=0"
              << " avg-us=0.000"
              << " gpu-count=0"
              << " cpu-count=0"
              << " correctness=PASS\n";
    return EXIT_SUCCESS;
  }

  const size_t byte_blocks =
      ceil_div(n, static_cast<size_t>(BLOCK_SIZE));
  const size_t chunk_blocks =
      ceil_div(chunks, static_cast<size_t>(BLOCK_SIZE));

  uint8_t *d_input = nullptr;
  uint8_t *d_newline = nullptr;
  uint32_t *d_newline_count = nullptr;
  uint8_t *d_chunk_mod = nullptr;
  uint8_t *d_prefix_mod = nullptr;
  uint64_t *d_counts = nullptr;
  void *d_scan_tmp = nullptr;
  size_t scan_tmp_bytes = 0;

  CHECK_CUDA(cudaMalloc(&d_input, n));
  CHECK_CUDA(cudaMalloc(&d_newline, n));
  CHECK_CUDA(cudaMalloc(&d_newline_count, chunks * sizeof(uint32_t)));
  CHECK_CUDA(cudaMalloc(&d_chunk_mod, chunks * sizeof(uint8_t)));
  CHECK_CUDA(cudaMalloc(&d_prefix_mod, chunks * sizeof(uint8_t)));
  CHECK_CUDA(cudaMalloc(&d_counts, chunks * sizeof(uint64_t)));
  CHECK_CUDA(cudaMemcpy(d_input, text.data(), n, cudaMemcpyHostToDevice));

  CHECK_CUDA(cub::DeviceScan::ExclusiveScan(
      nullptr, scan_tmp_bytes, d_chunk_mod, d_prefix_mod, FastqMod4Add{},
      uint8_t{0}, chunks));
  CHECK_CUDA(cudaMalloc(&d_scan_tmp, scan_tmp_bytes));

  cudaEvent_t start{};
  cudaEvent_t stop{};
  CHECK_CUDA(cudaEventCreate(&start));
  CHECK_CUDA(cudaEventCreate(&stop));

  double total_us = 0.0;
  for (int run = 0; run < runs; ++run) {
    CHECK_CUDA(cudaEventRecord(start));

    fastq_newline_kernel<<<byte_blocks, BLOCK_SIZE>>>(d_input, d_newline, n);
    fastq_count_mod_from_newline_cta_kernel<<<chunks, BLOCK_SIZE>>>(
        d_newline, d_newline_count, d_chunk_mod, n, FASTQ_CHUNK);
    CHECK_CUDA(cub::DeviceScan::ExclusiveScan(
        d_scan_tmp, scan_tmp_bytes, d_chunk_mod, d_prefix_mod,
        FastqMod4Add{}, uint8_t{0}, chunks));
    fastq_select_counts_mod_kernel<<<chunk_blocks, BLOCK_SIZE>>>(
        d_newline_count, d_prefix_mod, d_counts, chunks);

    CHECK_CUDA(cudaGetLastError());
    CHECK_CUDA(cudaEventRecord(stop));
    CHECK_CUDA(cudaEventSynchronize(stop));
    float elapsed_ms = 0.0f;
    CHECK_CUDA(cudaEventElapsedTime(&elapsed_ms, start, stop));
    total_us += static_cast<double>(elapsed_ms) * 1000.0;
  }

  std::vector<uint64_t> gpu_chunk_counts(chunks);
  CHECK_CUDA(cudaMemcpy(gpu_chunk_counts.data(), d_counts,
                        chunks * sizeof(uint64_t), cudaMemcpyDeviceToHost));
  const uint64_t gpu_records =
      std::accumulate(gpu_chunk_counts.begin(), gpu_chunk_counts.end(),
                      uint64_t{0});
  const bool correct = gpu_chunk_counts == cpu.chunk_counts &&
                       gpu_records == cpu.record_count;

  CHECK_CUDA(cudaEventDestroy(start));
  CHECK_CUDA(cudaEventDestroy(stop));
  CHECK_CUDA(cudaFree(d_scan_tmp));
  CHECK_CUDA(cudaFree(d_counts));
  CHECK_CUDA(cudaFree(d_prefix_mod));
  CHECK_CUDA(cudaFree(d_chunk_mod));
  CHECK_CUDA(cudaFree(d_newline_count));
  CHECK_CUDA(cudaFree(d_newline));
  CHECK_CUDA(cudaFree(d_input));

  std::cout << std::fixed << std::setprecision(3)
            << "method=baseline"
            << " input=" << std::quoted(path)
            << " bytes=" << n
            << " runs=" << runs
            << " block-size=" << BLOCK_SIZE
            << " chunk-size=" << FASTQ_CHUNK
            << " chunks=" << chunks
            << " avg-us=" << (total_us / static_cast<double>(runs))
            << " gpu-count=" << gpu_records
            << " cpu-count=" << cpu.record_count
            << " correctness=" << (correct ? "PASS" : "FAIL") << '\n';

  return correct ? EXIT_SUCCESS : 2;
}

static void print_usage(const char *program) {
  std::cerr << "usage: " << program << " <input> [runs]\n";
}

int main(int argc, char **argv) {
  if (argc < 2 || argc > 3) {
    print_usage(argv[0]);
    return EXIT_FAILURE;
  }

  const int runs = argc == 3 ? parse_runs(argv[2]) : 5;
  return run_baseline(argv[1], runs);
}
