#include <cuda_runtime.h>
#include <cub/cub.cuh>

#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <limits>
#include <stdexcept>
#include <string>
#include <vector>

#define CHECK_CUDA(call)                                                       \
  do {                                                                         \
    const cudaError_t error__ = (call);                                         \
    if (error__ != cudaSuccess) {                                               \
      std::fprintf(stderr, "CUDA error %s:%d: %s\n", __FILE__, __LINE__,       \
                   cudaGetErrorString(error__));                               \
      std::exit(EXIT_FAILURE);                                                  \
    }                                                                           \
  } while (0)

#ifndef BLOCK_SIZE
#define BLOCK_SIZE 256
#endif

#ifndef XML_STATE_CHUNK
#define XML_STATE_CHUNK 1024
#endif

static constexpr int kBlockSize = BLOCK_SIZE;
static constexpr int kChunkBytes = XML_STATE_CHUNK;

static_assert(kBlockSize > 0, "BLOCK_SIZE must be positive");
static_assert(kChunkBytes > 0, "XML_STATE_CHUNK must be positive");
static_assert(kChunkBytes % 32 == 0,
              "XML_STATE_CHUNK must be a multiple of 32");

template <typename T>
static T ceil_div(T value, T divisor) {
  return (value + divisor - 1) / divisor;
}

struct XmlStateSummary {
  uint8_t s0, s1, s2, s3;
};

static_assert(sizeof(XmlStateSummary) == 4,
              "the transition summary must contain exactly four states");

__host__ __device__ static inline XmlStateSummary
xml_state_make_summary(uint8_t s0, uint8_t s1, uint8_t s2, uint8_t s3) {
  return {s0, s1, s2, s3};
}

__host__ __device__ static inline XmlStateSummary xml_state_identity() {
  return xml_state_make_summary(0, 1, 2, 3);
}

__host__ __device__ static inline uint8_t
xml_state_of(const XmlStateSummary &summary, uint8_t state) {
  return state == 0 ? summary.s0
         : state == 1 ? summary.s1
         : state == 2 ? summary.s2
                      : summary.s3;
}

struct XmlStateSummaryMerge {
  __host__ __device__ XmlStateSummary operator()(
      const XmlStateSummary &first,
      const XmlStateSummary &second) const {
    return xml_state_make_summary(
        xml_state_of(second, xml_state_of(first, 0)),
        xml_state_of(second, xml_state_of(first, 1)),
        xml_state_of(second, xml_state_of(first, 2)),
        xml_state_of(second, xml_state_of(first, 3)));
  }
};

__host__ __device__ static inline uint8_t
xml_state_step_flags(uint8_t state,
                     bool is_lt,
                     bool is_gt,
                     bool is_slash,
                     bool is_eq,
                     bool is_dquote,
                     bool is_squote,
                     uint8_t *emit) {
  *emit = 0;
  if (state == 0) {
    if (is_lt) {
      *emit = 1;
      return 1;
    }
    return 0;
  }
  if (state == 1) {
    if (is_gt) {
      *emit = 1;
      return 0;
    }
    if (is_dquote) {
      *emit = 1;
      return 2;
    }
    if (is_squote) {
      *emit = 1;
      return 3;
    }
    *emit = is_slash || is_eq;
    return 1;
  }
  if (state == 2) {
    if (is_dquote) {
      *emit = 1;
      return 1;
    }
    return 2;
  }
  if (is_squote) {
    *emit = 1;
    return 1;
  }
  return 3;
}

__host__ __device__ static inline uint8_t
xml_state_step_char(uint8_t state, uint8_t c, uint8_t *emit) {
  return xml_state_step_flags(state, c == '<', c == '>', c == '/', c == '=',
                              c == '"', c == '\'', emit);
}

// Stage 1: materialize one mask byte per input byte for every delimiter class.
__global__ void xml_state_classify_kernel(const uint8_t *in,
                                          uint8_t *lt,
                                          uint8_t *gt,
                                          uint8_t *slash,
                                          uint8_t *eq,
                                          uint8_t *dquote,
                                          uint8_t *squote,
                                          size_t n) {
  const size_t i = static_cast<size_t>(blockIdx.x) * blockDim.x + threadIdx.x;
  if (i >= n)
    return;
  const uint8_t c = in[i];
  lt[i] = c == '<';
  gt[i] = c == '>';
  slash[i] = c == '/';
  eq[i] = c == '=';
  dquote[i] = c == '"';
  squote[i] = c == '\'';
}

// Stage 2: compute the exact outgoing state for all four possible inputs.
__global__ void xml_state_summary_from_masks_kernel(
    const uint8_t *lt,
    const uint8_t *gt,
    const uint8_t *slash,
    const uint8_t *eq,
    const uint8_t *dquote,
    const uint8_t *squote,
    XmlStateSummary *summary,
    size_t n,
    int chunk) {
  const size_t chunk_id =
      static_cast<size_t>(blockIdx.x) * blockDim.x + threadIdx.x;
  const size_t start = chunk_id * static_cast<size_t>(chunk);
  if (start >= n)
    return;
  const size_t end = min(start + static_cast<size_t>(chunk), n);
  uint8_t s0 = 0, s1 = 1, s2 = 2, s3 = 3;
  uint8_t emit = 0;
  for (size_t i = start; i < end; ++i) {
    const bool is_lt = lt[i] != 0;
    const bool is_gt = gt[i] != 0;
    const bool is_slash = slash[i] != 0;
    const bool is_eq = eq[i] != 0;
    const bool is_dquote = dquote[i] != 0;
    const bool is_squote = squote[i] != 0;
    s0 = xml_state_step_flags(s0, is_lt, is_gt, is_slash, is_eq, is_dquote,
                              is_squote, &emit);
    s1 = xml_state_step_flags(s1, is_lt, is_gt, is_slash, is_eq, is_dquote,
                              is_squote, &emit);
    s2 = xml_state_step_flags(s2, is_lt, is_gt, is_slash, is_eq, is_dquote,
                              is_squote, &emit);
    s3 = xml_state_step_flags(s3, is_lt, is_gt, is_slash, is_eq, is_dquote,
                              is_squote, &emit);
  }
  summary[chunk_id] = xml_state_make_summary(s0, s1, s2, s3);
}

// Stage 4: apply the globally scanned incoming state and emit a packed bitmap.
__global__ void xml_state_apply_from_masks_kernel(
    const uint8_t *lt,
    const uint8_t *gt,
    const uint8_t *slash,
    const uint8_t *eq,
    const uint8_t *dquote,
    const uint8_t *squote,
    const XmlStateSummary *prefix,
    uint32_t *out,
    size_t n,
    int chunk) {
  const size_t chunk_id =
      static_cast<size_t>(blockIdx.x) * blockDim.x + threadIdx.x;
  const size_t start = chunk_id * static_cast<size_t>(chunk);
  if (start >= n)
    return;
  const size_t end = min(start + static_cast<size_t>(chunk), n);
  uint8_t state = xml_state_of(prefix[chunk_id], 0);
  uint32_t word = 0;
  size_t current_word = start >> 5;
  for (size_t i = start; i < end; ++i) {
    const size_t out_word = i >> 5;
    if (out_word != current_word) {
      out[current_word] = word;
      current_word = out_word;
      word = 0;
    }
    uint8_t emit = 0;
    state = xml_state_step_flags(state, lt[i] != 0, gt[i] != 0,
                                 slash[i] != 0, eq[i] != 0,
                                 dquote[i] != 0, squote[i] != 0, &emit);
    if (emit)
      word |= 1u << static_cast<unsigned>(i & 31u);
    if (i + 1 == end)
      out[current_word] = word;
  }
}

static std::vector<uint8_t> load_input(const std::string &path) {
  std::ifstream input(path, std::ios::binary | std::ios::ate);
  if (!input)
    throw std::runtime_error("cannot open input: " + path);

  const std::streamoff end = input.tellg();
  if (end < 0)
    throw std::runtime_error("cannot determine input size: " + path);
  if (static_cast<uintmax_t>(end) >
      static_cast<uintmax_t>(std::numeric_limits<size_t>::max()))
    throw std::runtime_error("input is too large for this host: " + path);

  std::vector<uint8_t> bytes(static_cast<size_t>(end));
  input.seekg(0, std::ios::beg);
  input.read(reinterpret_cast<char *>(bytes.data()), end);
  if (!input)
    throw std::runtime_error("failed while reading input: " + path);
  return bytes;
}

static std::vector<uint32_t>
cpu_xml_state_bitmap(const std::vector<uint8_t> &text) {
  std::vector<uint32_t> out(ceil_div(text.size(), static_cast<size_t>(32)), 0);
  uint8_t state = 0;
  for (size_t i = 0; i < text.size(); ++i) {
    uint8_t emit = 0;
    state = xml_state_step_char(state, text[i], &emit);
    if (emit)
      out[i >> 5] |= 1u << static_cast<unsigned>(i & 31u);
  }
  return out;
}

static uint64_t bitmap_count(const std::vector<uint32_t> &bitmap) {
  uint64_t count = 0;
  for (uint32_t word : bitmap)
    count += static_cast<uint64_t>(__builtin_popcount(word));
  return count;
}

static int parse_runs(const char *text) {
  char *end = nullptr;
  const long value = std::strtol(text, &end, 10);
  if (text[0] == '\0' || end == nullptr || *end != '\0' || value <= 0 ||
      value > std::numeric_limits<int>::max())
    throw std::runtime_error("runs must be a positive integer");
  return static_cast<int>(value);
}

int main(int argc, char **argv) {
  if (argc < 2 || argc > 3) {
    std::fprintf(stderr, "usage: %s <input> [runs]\n", argv[0]);
    return EXIT_FAILURE;
  }

  try {
    const std::string input_path = argv[1];
    const int runs = argc == 3 ? parse_runs(argv[2]) : 5;
    const std::vector<uint8_t> input = load_input(input_path);
    const size_t n = input.size();
    if (n == 0) {
      std::printf("method=baseline bytes=0 runs=%d avg-us=0.000 "
                  "gpu-count=0 cpu-count=0 correctness=PASS\n", runs);
      return EXIT_SUCCESS;
    }
    const size_t chunks =
        ceil_div(n, static_cast<size_t>(kChunkBytes));
    const size_t words = ceil_div(n, static_cast<size_t>(32));
    const size_t byte_blocks =
        ceil_div(n, static_cast<size_t>(kBlockSize));
    const size_t chunk_blocks =
        ceil_div(chunks, static_cast<size_t>(kBlockSize));

    uint8_t *d_input = nullptr;
    uint8_t *d_lt = nullptr;
    uint8_t *d_gt = nullptr;
    uint8_t *d_slash = nullptr;
    uint8_t *d_eq = nullptr;
    uint8_t *d_dquote = nullptr;
    uint8_t *d_squote = nullptr;
    XmlStateSummary *d_summary = nullptr;
    XmlStateSummary *d_prefix = nullptr;
    uint32_t *d_output = nullptr;
    void *d_scan_temp = nullptr;
    size_t scan_temp_bytes = 0;

    CHECK_CUDA(cudaMalloc(&d_input, n));
    CHECK_CUDA(cudaMalloc(&d_lt, n));
    CHECK_CUDA(cudaMalloc(&d_gt, n));
    CHECK_CUDA(cudaMalloc(&d_slash, n));
    CHECK_CUDA(cudaMalloc(&d_eq, n));
    CHECK_CUDA(cudaMalloc(&d_dquote, n));
    CHECK_CUDA(cudaMalloc(&d_squote, n));
    CHECK_CUDA(cudaMalloc(&d_summary, chunks * sizeof(XmlStateSummary)));
    CHECK_CUDA(cudaMalloc(&d_prefix, chunks * sizeof(XmlStateSummary)));
    CHECK_CUDA(cudaMalloc(&d_output, words * sizeof(uint32_t)));
    CHECK_CUDA(cudaMemcpy(d_input, input.data(), n, cudaMemcpyHostToDevice));

    // Stage 3 uses a device-wide exclusive scan of exact transition functions.
    CHECK_CUDA(cub::DeviceScan::ExclusiveScan(
        nullptr, scan_temp_bytes, d_summary, d_prefix,
        XmlStateSummaryMerge{}, xml_state_identity(), chunks));
    CHECK_CUDA(cudaMalloc(&d_scan_temp, scan_temp_bytes));

    cudaEvent_t start{}, stop{};
    CHECK_CUDA(cudaEventCreate(&start));
    CHECK_CUDA(cudaEventCreate(&stop));

    double elapsed_ms = 0.0;
    for (int run = 0; run < runs; ++run) {
      CHECK_CUDA(cudaEventRecord(start));
      xml_state_classify_kernel<<<byte_blocks, kBlockSize>>>(
          d_input, d_lt, d_gt, d_slash, d_eq, d_dquote, d_squote, n);
      xml_state_summary_from_masks_kernel<<<chunk_blocks, kBlockSize>>>(
          d_lt, d_gt, d_slash, d_eq, d_dquote, d_squote, d_summary, n,
          kChunkBytes);
      CHECK_CUDA(cub::DeviceScan::ExclusiveScan(
          d_scan_temp, scan_temp_bytes, d_summary, d_prefix,
          XmlStateSummaryMerge{}, xml_state_identity(), chunks));
      xml_state_apply_from_masks_kernel<<<chunk_blocks, kBlockSize>>>(
          d_lt, d_gt, d_slash, d_eq, d_dquote, d_squote, d_prefix, d_output,
          n, kChunkBytes);
      CHECK_CUDA(cudaGetLastError());
      CHECK_CUDA(cudaEventRecord(stop));
      CHECK_CUDA(cudaEventSynchronize(stop));
      float run_ms = 0.0f;
      CHECK_CUDA(cudaEventElapsedTime(&run_ms, start, stop));
      elapsed_ms += static_cast<double>(run_ms);
    }

    std::vector<uint32_t> gpu_bitmap(words);
    CHECK_CUDA(cudaMemcpy(gpu_bitmap.data(), d_output,
                          words * sizeof(uint32_t), cudaMemcpyDeviceToHost));
    const std::vector<uint32_t> cpu_bitmap = cpu_xml_state_bitmap(input);
    const bool correct = gpu_bitmap == cpu_bitmap;
    const uint64_t delimiter_count = bitmap_count(gpu_bitmap);
    const uint64_t cpu_delimiter_count = bitmap_count(cpu_bitmap);
    const double average_us = elapsed_ms * 1000.0 / static_cast<double>(runs);

    std::printf(
        "method=baseline bytes=%zu runs=%d avg-us=%.3f gpu-count=%llu "
        "cpu-count=%llu correctness=%s\n",
        n, runs, average_us,
        static_cast<unsigned long long>(delimiter_count),
        static_cast<unsigned long long>(cpu_delimiter_count),
        correct ? "PASS" : "FAIL");

    CHECK_CUDA(cudaEventDestroy(start));
    CHECK_CUDA(cudaEventDestroy(stop));
    CHECK_CUDA(cudaFree(d_scan_temp));
    CHECK_CUDA(cudaFree(d_output));
    CHECK_CUDA(cudaFree(d_prefix));
    CHECK_CUDA(cudaFree(d_summary));
    CHECK_CUDA(cudaFree(d_squote));
    CHECK_CUDA(cudaFree(d_dquote));
    CHECK_CUDA(cudaFree(d_eq));
    CHECK_CUDA(cudaFree(d_slash));
    CHECK_CUDA(cudaFree(d_gt));
    CHECK_CUDA(cudaFree(d_lt));
    CHECK_CUDA(cudaFree(d_input));

    return correct ? EXIT_SUCCESS : 2;
  } catch (const std::exception &error) {
    std::fprintf(stderr, "error: %s\n", error.what());
    return EXIT_FAILURE;
  }
}
