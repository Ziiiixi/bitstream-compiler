// Wrapper for exactly one real BitGen-generated regex body: regex_0.cu.
// The definitions below only make the CUDA source parseable as C++ for the
// compiler frontend; they do not change the regex program.
// Upstream BitGen revision: de7b7db0f385e21c5e6a5e2767f4264da890f9b0.
// See ../../THIRD_PARTY_NOTICES.md before redistributing the included body.
using uint32_t = unsigned int;

#define __global__
#define __device__
#define __host__
#define __forceinline__ inline
#define __noinline__
#define __shared__

struct Dim3 { int x; int y; int z; };
Dim3 blockIdx, blockDim, threadIdx, gridDim;

extern "C" double ceil(double);
extern "C" int printf(const char *, ...);
extern "C" uint32_t atomicOr(uint32_t *, uint32_t);
extern "C" uint32_t atomicAdd(uint32_t *, uint32_t);
#define __syncthreads() ((void)0)
#define __threadfence() ((void)0)
inline uint32_t __funnelshift_r(uint32_t lo, uint32_t hi, int shift) {
  return shift == 0 ? lo : ((lo >> shift) | (hi << (32 - shift)));
}
inline uint32_t __funnelshift_l(uint32_t lo, uint32_t hi, int shift) {
  return shift == 0 ? lo : ((lo << shift) | (hi >> (32 - shift)));
}

#include "regex_0.cu"

extern "C" void bitgen_driver(uint32_t *input_stream,
                               uint32_t n_unit_basic,
                               uint32_t n_char,
                               uint32_t *result_stream,
                               uint32_t *advance_memory,
                               uint32_t *temporary_streams) {
  regex_0(input_stream, n_unit_basic, n_char, result_stream,
          advance_memory, temporary_streams);
}
