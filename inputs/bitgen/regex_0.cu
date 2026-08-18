// Generated/template-derived from getianao/BitGen revision
// de7b7db0f385e21c5e6a5e2767f4264da890f9b0. No upstream license was present
// at the audited revision. Keep this file private pending permission or
// replacement; see ../../THIRD_PARTY_NOTICES.md.

#define BLOCK_SIZE 512

// #include <cub/block/block_scan.cuh> // Update cub version
// #include <cooperative_groups.h>
// namespace cg = cooperative_groups;
typedef unsigned int uint32_t;

// #define DEBUG_PRINT
#define DEBUG_PRINT_UNIT 0

#define UINT32_MAX (4294967295U)

// template <typename T> struct BinaryScanFunctor {
//   __device__ T operator()(const T &a, const T &b) {
//     // (a->carry & b->max) | (b->carry)
//     return (((a & (b >> 1)) | b) & 1);
//   }
// };

extern "C" {

static __device__ __forceinline__ void swap_pointer(uint32_t **a,
                                                    uint32_t **b) {
  uint32_t *temp = *a;
  *a = *b;
  *b = temp;
}

// static __device__ __forceinline__ uint32_t swapEndian(uint32_t value) {
//   return ((value & 0x000000FF) << 24) | ((value & 0x0000FF00) << 8) |
//          ((value & 0x00FF0000) >> 8) | ((value & 0xFF000000) >> 24);
// }

// static __device__ __forceinline__ void print_uint32_binary(uint32_t n) {
//   // n = swapEndian(n);
//   for (int i = 31; i >= 0; i--) {
//     printf("%d", (n >> i) & 1);
//     if (i % 8 == 0)
//       printf(" ");
//   }
//   printf("\n");
// }

// static __device__ __forceinline__ void
// print_uint32_binary_debug(const char *msg, uint32_t n) {
// #ifdef DEBUG_PRINT
//   if (threadIdx.x == 0 && blockIdx.x == 0) {
//     printf("%-32s", msg);
//     print_uint32_binary(n);
//   }
// #endif
// }

// static __device__ __forceinline__ void print_32char_debug(const char *msg,
//                                                           char *n) {
// #ifdef DEBUG_PRINT
//   if (threadIdx.x == 0 && blockIdx.x == 0) {
//     printf("%-32s", msg);
//     for (int i = 0; i < 32; i++) {
//       printf("%c", n[i]);
//       if (i % 8 == 7)
//         printf(" ");
//     }
//     printf("\n");
//   }
// #endif
// }

// static __device__ __forceinline__ uint32_t prefix_sum(uint32_t a, uint32_t b)
// {
//   // (a->carry & b->max) | (b->carry)
//   return (((a & (b >> 1)) | b) & 1);
// };

// struct BlockPrefixCallbackOp {
//   uint32_t running_total;
//   __device__ BlockPrefixCallbackOp(uint32_t running_total)
//       : running_total(running_total) {}
//   __device__ uint32_t operator()(uint32_t block_aggregate) {
//     uint32_t old_prefix = running_total;
//     running_total += block_aggregate;
//     return old_prefix;
//   }
// };

// static __device__ __forceinline__ void
// bs_stream_add(uint32_t *op1_stream, uint32_t *op2_stream, uint32_t
// *carry_max,
//               uint32_t *result_stream, uint32_t n_unit_basic) {
//   for (uint32_t i = 0; i < ceil(1.0 * n_unit_basic / (blockDim.x)); i++) {
//     int idx = i * (blockDim.x) + threadIdx.x;
//     uint32_t op1 = __brev(swapEndian(op1_stream[idx]));
//     uint32_t op2 = __brev(swapEndian(op2_stream[idx]));
//     uint32_t r = (op1) + (op2);
//     if (idx < n_unit_basic) {
//       if (r < op1)
//         carry_max[idx] = 1;
//       if (r == UINT32_MAX)
//         carry_max[idx] = 2;
//     }
//     result_stream[idx] = r;
//   }
//   __syncthreads();

//   // https://nvidia.github.io/cccl/cub/api/classcub_1_1BlockScan.html#id8
//   using BlockScan = cub::BlockScan<uint32_t, BLOCK_SIZE>;
//   __shared__ typename BlockScan::TempStorage temp_storage;
//   BlockPrefixCallbackOp prefix_op(0);
//   BinaryScanFunctor<uint32_t> binary_op;
//   for (uint32_t i = 0; i < ceil(1.0 * n_unit_basic / (blockDim.x)); i++) {
//     int idx = i * (blockDim.x) + threadIdx.x;
//     uint32_t thread_data = carry_max[idx];
//     BlockScan(temp_storage)
//         .ExclusiveScan(thread_data, thread_data, binary_op, prefix_op);
//     __syncthreads();
//     carry_max[idx] = thread_data;
//     result_stream[idx] += swapEndian(__brev(result_stream[idx] +
//     thread_data));
//   }
//   __syncthreads();
// }

static __device__ __forceinline__ uint32_t bs_not(uint32_t bs_input) {
  uint32_t result = ~bs_input;
#ifdef DEBUG_PRINT
  print_uint32_binary_debug("    bs_not op1: ", bs_input);
  print_uint32_binary_debug("bs_not result: ", result);
#endif
  return result;
}

static __device__ __forceinline__ uint32_t bs_and(uint32_t op1, uint32_t op2) {
  uint32_t result = op1 & op2;
#ifdef DEBUG_PRINT
  print_uint32_binary_debug("    bs_and op1: ", op1);
  print_uint32_binary_debug("    bs_and op2: ", op2);
  print_uint32_binary_debug("bs_and result: ", result);
#endif
  return result;
}

static __device__ __forceinline__ uint32_t bs_or(uint32_t op1, uint32_t op2) {
  uint32_t result = op1 | op2;
#ifdef DEBUG_PRINT
  print_uint32_binary_debug("    bs_or op1: ", op1);
  print_uint32_binary_debug("    bs_or op2: ", op2);
  print_uint32_binary_debug("bs_or result: ", result);
#endif
  return result;
}

static __device__ __forceinline__ uint32_t bs_xor(uint32_t op1, uint32_t op2) {
  uint32_t result = op1 ^ op2;
#ifdef DEBUG_PRINT
  print_uint32_binary_debug("    bs_xor op1: ", op1);
  print_uint32_binary_debug("    bs_xor op2: ", op2);
  print_uint32_binary_debug("bs_xor result: ", result);
#endif
  return result;
}

// static __device__ __forceinline__ uint32_t bs_scan_thru(uint32_t op1,
//                                                         uint32_t op2) {
//   // TODO(tge): Implement this function
//   uint32_t result = op1;
//   return result;
// }

// static __device__ __forceinline__ void
// bs_scan_thru_stream(uint32_t *op1_stream, uint32_t *op2_stream,
//                     uint32_t *carry_stream, uint32_t *add_stream,
//                     uint32_t *result_stream, uint32_t n_unit_basic) {

//   bs_stream_add(op1_stream, op2_stream, carry_stream, add_stream,
//   n_unit_basic);
//   __syncthreads();
//   for (uint32_t i = 0; i < ceil(1.0 * n_unit_basic / (blockDim.x)); i += 1) {
//     int idx = i * (blockDim.x) + threadIdx.x;
//     uint32_t add = add_stream[idx];
//     uint32_t op2_not = bs_not(op2_stream[idx]);
//     uint32_t result = bs_and(add, op2_not);
//     if (idx < n_unit_basic) {
//       carry_stream[idx] = result;
//     }
//   }
//   __syncthreads();
// }

// static __device__ __forceinline__ uint32_t bs_match_star(uint32_t op1,
//                                                          uint32_t op2) {
//   // TODO(tge): Implement this function
//   uint32_t result = op1;
//   return result;
// }

static __device__ __forceinline__ uint32_t
get_value_with_bit_offset_right(uint32_t *advance_memory, int offset) {
  // if (unit_id >= advance_memory_size) {
  //   printf("ERROR: unit_id should be less than n_unit\n");
  //   return 0;
  // }
  int unit_offset = offset / 32;
  int bit_offset = offset % 32;
  if (threadIdx.x < unit_offset)
    return 0;
  uint32_t bs_value = advance_memory[threadIdx.x - unit_offset];
  if (threadIdx.x == unit_offset)
    return bs_value >> bit_offset;
  uint32_t bs_value_prev = advance_memory[threadIdx.x - unit_offset - 1];
  uint32_t bs_value_right =
      (bit_offset == 0) ? 0 : (bs_value_prev << (32 - bit_offset));
  bs_value = (bs_value >> bit_offset) | bs_value_right;
  return bs_value;
}

static __device__ __forceinline__ uint32_t
get_value_with_bit_offset_right2(uint32_t *advance_memory, int offset) {
  int unit_offset = offset >> 5;
  int bit_offset = offset & 31;
  int first_unit = unit_offset;

  uint32_t bs_value =
      threadIdx.x >= first_unit ? advance_memory[threadIdx.x - unit_offset] : 0;
  uint32_t bs_value_prev = threadIdx.x > first_unit
                               ? advance_memory[threadIdx.x - unit_offset - 1]
                               : 0;
  return __funnelshift_r(bs_value, bs_value_prev, bit_offset);
}

static __device__ __forceinline__ uint32_t BSAdvanceRightFunction(
    uint32_t bs_input, uint32_t n_bits, uint32_t *advance_memory) {
  // Write to anoterh chunk of memory, exchange data with other threads in the
  // same CTA return bs_input+1;
  // TODO(tge): Fix unit_id and advance_memory_size=
  uint32_t result = get_value_with_bit_offset_right(advance_memory, n_bits);
#ifdef DEBUG_PRINT
  print_uint32_binary_debug("    bs_advance op1: ", bs_input);
  print_uint32_binary_debug("bs_advance result: ", result);
#endif
  return result;
}
static __device__ __forceinline__ uint32_t BSAdvanceRightFunctionSync(
    uint32_t bs_input, uint32_t n_bits, uint32_t *advance_memory) {
  // Write to anoterh chunk of memory, exchange data with other threads in the
  // same CTA return bs_input+1;
  // TODO(tge): Fix unit_id and advance_memory_size
  __syncthreads();
  advance_memory[threadIdx.x] = bs_input;
  __syncthreads();
  uint32_t result = get_value_with_bit_offset_right(advance_memory, n_bits);
#ifdef DEBUG_PRINT
  print_uint32_binary_debug("    bs_advance op1: ", bs_input);
  print_uint32_binary_debug("bs_advance result: ", result);
#endif
  return result;
}

// static __device__ __forceinline__ uint32_t
// get_value_with_bit_offset_right_block(
//     uint32_t *advance_memory, const uint32_t advance_memory_size,
//     uint32_t unit_id, int offset, uint32_t *prev_block) {
//   // offset = unit_offset * 32 + bit_offset
//   int unit_offset = offset / 32;
//   int bit_offset = offset % 32;
//   int bound = (offset + 32) / 32;
//   uint32_t block_result_value = 0;
//   if (unit_id < bound) {
//     uint32_t prev_block_value =
//         prev_block[advance_memory_size - 1 - unit_offset];
//     uint32_t block_value = advance_memory[unit_id - unit_offset];
//     block_result_value =
//         (block_value >> bit_offset) | (prev_block_value << (32 -
//         bit_offset));
//   } else {
//     uint32_t block_value_prev = advance_memory[unit_id - unit_offset - 1];
//     uint32_t block_value = advance_memory[unit_id - unit_offset];
//     block_result_value =
//         (block_value >> bit_offset) | (block_value_prev << (32 -
//         bit_offset));
//   }
//   return block_result_value;
// }

// static __device__ __forceinline__ uint32_t
// BlockAdvanceRightFunction(uint32_t bs_input, uint32_t n_bits, uint32_t
// unit_id,
//                           uint32_t *advance_memory, uint32_t *prev_block) {
//   advance_memory[unit_id] = bs_input;
//   __syncthreads();
//   uint32_t result = get_value_with_bit_offset_right(
//       advance_memory, BLOCK_SIZE, unit_id, n_bits);
//   print_uint32_binary_debug("    bs_advance op1: ", bs_input);
//   print_uint32_binary_debug("bs_advance result: ", result);
//   return result;
// }

static __device__ __forceinline__ uint32_t
get_value_with_bit_offset_left(uint32_t *advance_memory, int offset) {
  int unit_offset = offset >> 5;
  int bit_offset = offset & 31;
  uint32_t last_unit = BLOCK_SIZE - unit_offset - 1;

  uint32_t bs_value =
      threadIdx.x <= last_unit ? advance_memory[threadIdx.x + unit_offset] : 0;
  uint32_t bs_value_next = threadIdx.x <= (last_unit - 1)
                               ? advance_memory[threadIdx.x + unit_offset + 1]
                               : 0;
  return __funnelshift_l(bs_value_next, bs_value, bit_offset);
}

// Only used for pass cc_advance
static __device__ __forceinline__ uint32_t BSAdvanceLeftFunction(
    uint32_t bs_input, uint32_t n_bits, uint32_t *advance_memory) {
  // Write to anoterh chunk of memory, exchange data with other threads in the
  // same CTA
  // advance_memory[unit_id] = bs_input;
  // __syncthreads();
  uint32_t result = get_value_with_bit_offset_left(advance_memory, n_bits);
#ifdef DEBUG_PRINT
  print_uint32_binary_debug("    bs_advance op1: ", bs_input);
  print_uint32_binary_debug("bs_advance result: ", result);
#endif
  return result;
}
static __device__ __forceinline__ uint32_t BSAdvanceLeftFunctionSync(
    uint32_t bs_input, uint32_t n_bits, uint32_t *advance_memory) {
  // Write to anoterh chunk of memory, exchange data with other threads in the
  // same CTA
  __syncthreads();
  advance_memory[threadIdx.x] = bs_input;
  __syncthreads();
  uint32_t result = get_value_with_bit_offset_left(advance_memory, n_bits);
#ifdef DEBUG_PRINT
  print_uint32_binary_debug("    bs_advance op1: ", bs_input);
  print_uint32_binary_debug("bs_advance result: ", result);
#endif
  return result;
}

static __device__ __noinline__ bool bs_all_zeros(uint32_t *bs,
                                                 uint32_t n_unit_basic) {
  __shared__ uint32_t result;
  result = 0;
  __syncthreads();
  for (uint32_t idx = threadIdx.x; idx < n_unit_basic; idx += blockDim.x) {
    if (bs[idx] != 0) {
      atomicOr(&result, 1);
    }
  }
  __syncthreads();
  if (result != 0) {
    return false;
  }
  return true;
}

static __device__ __forceinline__ bool block_all_zeros(uint32_t bs,
                                                       uint32_t *zero_flag) {
  __syncthreads();
  if (threadIdx.x == 0)
    *zero_flag = 0;
  __syncthreads();
  atomicOr(zero_flag, bs);
  __syncthreads();
  return *zero_flag == 0;

  // __shared__ uint32_t any_non_zero;
  // if (threadIdx.x == 0) any_non_zero = 0;
  // __syncthreads();
  // bool has_bits = (bs != 0);
  // bool warp_any = __any_sync(0xFFFFFFFF, has_bits);
  // if (warp_any && threadIdx.x % 32 == 0) atomicOr(&any_non_zero, 1);
  // __syncthreads();
  // return (any_non_zero == 0);
}

static __device__ __forceinline__ bool block_all_zeros2(uint32_t bs, uint32_t *zero_flag) {
  if (threadIdx.x == 0) {
    *zero_flag = 0;
  }
  __syncthreads();
  if (bs != 0) {
    *zero_flag = 1;
  }
  __syncthreads();
  return *zero_flag == 0;
}

// static __device__ __forceinline__ bool warp_all_zeros(uint32_t bs) {
//   return __all_sync(0xFFFFFFFF, bs == 0);
// }

// static __device__ __forceinline__ uint32_t bs_ones_num(uint32_t *bs,
//                                                        uint32_t n_unit_basic)
//                                                        {
//   __shared__ uint32_t result;
//   result = 0;
//   __syncthreads();
//   for (uint32_t i = 0; i < ceil(1.0 * n_unit_basic / (blockDim.x)); i += 1) {
//     int idx = i * (blockDim.x) + threadIdx.x;
//     if (idx < n_unit_basic && bs[idx] != 0) {
//       // printf("bs[%d]: %d\n", idx, bs[idx]);
//       atomicAdd(&result, __popc(bs[idx]));
//     }
//     __syncthreads();
//   }
//   return result;
// }

// static __device__ __forceinline__ bool match(uint32_t offset,
//                                              const uint32_t *symbol_set) {
//   int pos = (offset / 32);
//   return symbol_set[pos] & (1 << (offset % 32));
// }

// static __device__ __forceinline__ uint32_t
// bs_match(char *input, uint32_t length, const uint32_t *symbol_set) {
//   uint32_t result = 0;
// #pragma unroll 1
//   for (int i = 0; i < length; i++) {
//     char c = input[i];
//     if (match(c, symbol_set))
//       result |= (0x1 << (31 - i));
//   }
//   result = swapEndian(result);
//   print_32char_debug("bs_match input: ", input);
//   print_uint32_binary_debug("bs_match result: ", result);
//   return result;
// }

// static __device__ __forceinline__ char *
// get_char_data(uint32_t *input_stream, uint32_t unit_id, uint32_t offset) {
//   char *input_stream_char = reinterpret_cast<char *>(input_stream);
//   return input_stream_char + unit_id * 32 + offset;
// }

// static __device__ __forceinline__ void
// set_bitstream_data(uint32_t *output_stream, uint32_t unit_id,
//                    uint32_t bit_offset, uint32_t value,
//                    uint32_t n_unit_output) {

//   if (unit_id >= n_unit_output)
//     return;
//   if (bit_offset == 0) {
//     output_stream[unit_id] = value;
//   } else {
//     uint32_t mask = (0xffffffff >> bit_offset);
//     value = swapEndian(value);
//     uint32_t orig_value_1 = swapEndian(output_stream[unit_id]);
//     uint32_t value_1 =
//         swapEndian((orig_value_1 & ~mask) | (value >> bit_offset));
//     atomicOr(&output_stream[unit_id], value_1);
//     if (unit_id + 1 < n_unit_output) {
//       uint32_t orig_value_2 = swapEndian(output_stream[unit_id + 1]);
//       uint32_t value_2 = swapEndian(value << (32 - bit_offset));
//       atomicOr(&output_stream[unit_id + 1], value_2);
//     }
//   }
// }

// static __device__ __forceinline__ uint32_t
// get_idx_in_little_endian(uint32_t bit_idx_in_big_endian) {
//   return (3 - bit_idx_in_big_endian / 8) * 8 + bit_idx_in_big_endian % 8;
// }

// static __device__ __forceinline__ uint32_t *transposed_256b(char *b256) {
//   uint32_t *bs = reinterpret_cast<uint32_t *>(b256);
//   uint32_t *bs_basic = (uint32_t *)malloc(8 * sizeof(uint32_t));
//   for (int i = 0; i < 8; i++) {
//     uint32_t block_data = bs[i];
//     for (int j = 0; j < 32; j++) {
//       int real_j = get_idx_in_little_endian(j);
//       int bs_basic_id = j % 8;
//       int pos_bit_in_basic = 31 - (i * 4 + (j / 8));
//       pos_bit_in_basic = get_idx_in_little_endian(pos_bit_in_basic);
//       uint32_t *bs_basic_i = bs_basic + bs_basic_id;
//       bs_basic_i[0] |= ((block_data >> (31 - real_j)) & 1) <<
//       pos_bit_in_basic;
//     }
//   }
//   return bs_basic;
// }
}


// Regex: ["([STX])(.)([RKX])", "([GX])(.)([KRCX])([DBEZNBQZRHX])([LX])([SAX])([YX])(.)([IX])([KRNBSAX])", "([RX])([RWX])([LIVFMYWAX])([FX])([DBNBEZSITX])([WX])([EZX])([HNBX])([LIVMKX])([QZHGEZNBRAMVYLCFX])(.{4}?)", "([HX])(.)([IVX])(.)([GX])([KRX])(.)([FX])([GAX])([SX])(.)([VX])([STX])([HYX])([EZX])", "([NBX])(.)([STAGCX])([LIVMCTX])([GPX])([LIVMFYWX]{2}?)([LMFATCYVX])([RX])(.)([GSTDBNBKX])([DBNBVEZX])([LIVMFYWRCX])([LIVHX])(.)(.)([KPQZNBHARX])", "([LIVMX]{2}?)([GSAX])(.)([GX])([GX])([IVX])(.)([STGDBNBX])(.{3}?)([ACVX])(.{2}?)([^A])([^R])(.)([^L])([GX])([AX])", "([IVTPMX])([DBEZGX])(.{2,3}?)([AYEZPQZX])([GX])([PTX])([STX])([EZDBX])([LIVSTAX])([LIVMAEZCGFTX])([LIVMAX])([LIVMAYFX])([ACNBDBSTIX])(.{2,3}?)([ACNBGVSTX])(.{4,6}?)([LIVMACX])([AVLKITX])([SACLYWNBRMTVX])([DBEZGX])([LIVMFCAX])([LIVMKFRX])([SAGVIX])(.{2}?)([EZX])([HX])"]
extern "C" __noinline__ __device__ void regex_0(uint32_t* basic_stream, uint32_t n_unit_basic, uint32_t n_char, uint32_t* bs_result_stream, uint32_t* advance_memory, uint32_t* tmp_streams) {
    uint32_t* test_stream_next = tmp_streams + n_unit_basic * 0;
    uint32_t* accum_stream_next = tmp_streams + n_unit_basic * 1;
    uint32_t* CC__1_9_b_7f_stream = tmp_streams + n_unit_basic * 2;
    uint32_t* test_stream = tmp_streams + n_unit_basic * 3;
    uint32_t* alt4_stream = tmp_streams + n_unit_basic * 4;
    uint32_t* CC__48_58_stream = tmp_streams + n_unit_basic * 5;
    uint32_t* CC__45_58_5a_stream = tmp_streams + n_unit_basic * 6;
    uint32_t* at2inarow_stream = tmp_streams + n_unit_basic * 7;
    uint32_t* CC__41_47_49_53_56_58_stream = tmp_streams + n_unit_basic * 8;
    uint32_t* CC__46_49_4b_4d_52_56_58_stream = tmp_streams + n_unit_basic * 9;
    uint32_t* CC__41_43_46_49_4c_4d_56_58_stream = tmp_streams + n_unit_basic * 10;
    uint32_t* CC__42_44_45_47_58_5a_stream = tmp_streams + n_unit_basic * 11;
    uint32_t* CC__41_43_4c_4e_52_54_56_59_stream = tmp_streams + n_unit_basic * 12;
    uint32_t* CC__41_49_4b_4c_54_56_58_stream = tmp_streams + n_unit_basic * 13;
    uint32_t* CC__41_43_49_4c_4d_56_58_stream = tmp_streams + n_unit_basic * 14;
    uint32_t* within2_stream = tmp_streams + n_unit_basic * 15;
    uint32_t* accum_stream = tmp_streams + n_unit_basic * 16;
    for (uint32_t i = 0; i < ceil(1.0 * n_unit_basic / (blockDim.x - 3)); i += 1) {
        int idx = i * (blockDim.x - 3) + threadIdx.x;
        uint32_t basis0 = basic_stream[idx + 0 * n_unit_basic];
        uint32_t basis1 = basic_stream[idx + 1 * n_unit_basic];
        uint32_t basis2 = basic_stream[idx + 2 * n_unit_basic];
        uint32_t basis3 = basic_stream[idx + 3 * n_unit_basic];
        uint32_t basis4 = basic_stream[idx + 4 * n_unit_basic];
        uint32_t basis5 = basic_stream[idx + 5 * n_unit_basic];
        uint32_t basis6 = basic_stream[idx + 6 * n_unit_basic];
        uint32_t basis7 = basic_stream[idx + 7 * n_unit_basic];
        uint32_t not_ = bs_not(basis4);
        uint32_t not_1 = bs_not(basis2);
        uint32_t not_2 = bs_not(basis0);
        uint32_t and_ = bs_and(basis3, not_1);
        uint32_t and_1 = bs_and(basis1, not_2);
        uint32_t and_2 = bs_and(and_1, and_);
        uint32_t and_3 = bs_and(and_2, not_);
        uint32_t and_4 = bs_and(basis6, basis7);
        uint32_t or_ = bs_or(basis6, basis7);
        uint32_t not_3 = bs_not(or_);
        uint32_t sel_not_basis5 = bs_not(basis5);
        uint32_t sel_mask_not_3 = bs_and(basis5, not_3);
        uint32_t sel_mask_and_4 = bs_and(sel_not_basis5, and_4);
        uint32_t sel = bs_or(sel_mask_not_3, sel_mask_and_4);
        uint32_t and_5 = bs_and(and_3, sel);
        uint32_t not_6 = bs_not(basis5);
        uint32_t and_6 = bs_and(basis4, not_6);
        uint32_t and_9 = bs_and(and_6, not_3);
        uint32_t and_11 = bs_and(and_2, and_9);
        uint32_t CC__53_54_58 = bs_or(and_5, and_11);
        uint32_t or_3 = bs_or(basis2, basis3);
        uint32_t or_4 = bs_or(basis0, basis1);
        uint32_t or_5 = bs_or(or_4, or_3);
        uint32_t not_16 = bs_not(or_5);
        uint32_t or_7 = bs_or(basis5, or_);
        uint32_t or_8 = bs_or(basis5, basis6);
        uint32_t not_17 = bs_not(or_8);
        uint32_t sel_not_basis4 = bs_not(basis4);
        uint32_t sel_mask_not_17 = bs_and(basis4, not_17);
        uint32_t sel_mask_or_7 = bs_and(sel_not_basis4, or_7);
        uint32_t sel1 = bs_or(sel_mask_not_17, sel_mask_or_7);
        uint32_t and_12 = bs_and(sel1, not_16);
        uint32_t or_9 = bs_or(basis5, and_4);
        uint32_t and_14 = bs_and(basis4, or_9);
        uint32_t or_11 = bs_or(or_3, and_14);
        uint32_t or_12 = bs_or(basis1, or_11);
        uint32_t and_15 = bs_and(or_12, not_2);
        uint32_t CC__1_9_b_7f = bs_or(and_12, and_15);
        uint32_t not_23 = bs_not(or_3);
        uint32_t and_19 = bs_and(and_6, and_4);
        uint32_t and_20 = bs_and(and_1, not_23);
        uint32_t and_21 = bs_and(and_20, and_19);
        uint32_t not_24 = bs_not(basis7);
        uint32_t and_22 = bs_and(basis6, not_24);
        uint32_t or_15 = bs_or(basis4, basis5);
        uint32_t not_29 = bs_not(or_15);
        uint32_t and_25 = bs_and(and_22, not_29);
        uint32_t and_27 = bs_and(and_2, and_25);
        uint32_t or_16 = bs_or(and_21, and_27);
        uint32_t CC__4b_52_58 = bs_or(or_16, and_11);
        uint32_t and_35 = bs_and(basis5, not_);
        uint32_t and_37 = bs_and(and_35, and_4);
        uint32_t and_39 = bs_and(and_20, and_37);
        uint32_t CC__47_58 = bs_or(and_39, and_11);
        uint32_t and_48 = bs_and(and_4, not_29);
        uint32_t not_59 = bs_not(and_6);
        uint32_t and_57 = bs_and(or_15, not_59);
        uint32_t not_60 = bs_not(and_57);
        uint32_t and_58 = bs_and(and_4, not_60);
        uint32_t and_59 = bs_and(and_20, and_58);
        uint32_t or_26 = bs_or(and_59, and_27);
        uint32_t CC__43_4b_52_58 = bs_or(or_26, and_11);
        uint32_t not_81 = bs_not(basis6);
        uint32_t and_79 = bs_and(and_35, not_81);
        uint32_t or_32 = bs_or(and_25, and_79);
        uint32_t or_35 = bs_or(or_32, and_9);
        uint32_t and_90 = bs_and(basis4, basis5);
        uint32_t and_92 = bs_and(and_90, and_22);
        uint32_t or_37 = bs_or(or_35, and_92);
        uint32_t and_95 = bs_and(and_20, or_37);
        uint32_t and_99 = bs_and(and_2, not_29);
        uint32_t xor_ = bs_xor(basis6, basis7);
        uint32_t and_100 = bs_and(and_99, xor_);
        uint32_t or_39 = bs_or(and_95, and_100);
        uint32_t or_41 = bs_or(or_39, and_11);
        uint32_t and_111 = bs_and(and_6, and_22);
        uint32_t and_113 = bs_and(and_2, and_111);
        uint32_t CC__42_44_45_48_4e_51_52_58_5a = bs_or(or_41, and_113);
        uint32_t and_116 = bs_and(and_90, not_3);
        uint32_t and_118 = bs_and(and_20, and_116);
        uint32_t CC__4c_58 = bs_or(and_118, and_11);
        uint32_t and_125 = bs_and(basis7, not_81);
        uint32_t and_127 = bs_and(and_125, not_29);
        uint32_t and_129 = bs_and(and_20, and_127);
        uint32_t and_135 = bs_and(and_2, and_48);
        uint32_t or_50 = bs_or(and_129, and_135);
        uint32_t CC__41_53_58 = bs_or(or_50, and_11);
        uint32_t and_145 = bs_and(and_6, not_81);
        uint32_t CC__58_59 = bs_and(and_2, and_145);
        uint32_t and_151 = bs_and(and_6, and_125);
        uint32_t and_153 = bs_and(and_20, and_151);
        uint32_t CC__49_58 = bs_or(and_153, and_11);
        uint32_t and_162 = bs_and(and_20, not_29);
        uint32_t and_163 = bs_and(and_162, xor_);
        uint32_t or_59 = bs_or(and_163, and_21);
        uint32_t and_175 = bs_and(and_20, and_92);
        uint32_t or_61 = bs_or(or_59, and_175);
        uint32_t and_178 = bs_and(basis6, not_29);
        uint32_t and_180 = bs_and(and_2, and_178);
        uint32_t or_63 = bs_or(or_61, and_180);
        uint32_t CC__41_42_4b_4e_52_53_58 = bs_or(or_63, and_11);
        uint32_t or_68 = bs_or(and_25, and_9);
        uint32_t CC__52_58 = bs_and(and_2, or_68);
        uint32_t and_210 = bs_and(basis5, and_4);
        uint32_t not_213 = bs_not(or_7);
        sel_not_basis4 = bs_not(basis4);
        uint32_t sel_mask_not_213 = bs_and(basis4, not_213);
        uint32_t sel_mask_and_210 = bs_and(sel_not_basis4, and_210);
        uint32_t sel2 = bs_or(sel_mask_not_213, sel_mask_and_210);
        uint32_t or_72 = bs_or(and_25, sel2);
        uint32_t CC__52_57_58 = bs_and(and_2, or_72);
        uint32_t and_221 = bs_and(and_35, and_22);
        uint32_t or_76 = bs_or(and_127, and_221);
        uint32_t or_78 = bs_or(or_76, and_151);
        uint32_t and_234 = bs_and(and_90, not_81);
        uint32_t or_80 = bs_or(or_78, and_234);
        uint32_t and_237 = bs_and(and_20, or_80);
        uint32_t and_241 = bs_and(basis5, basis6);
        sel_not_basis4 = bs_not(basis4);
        sel_mask_not_17 = bs_and(basis4, not_17);
        uint32_t sel_mask_and_241 = bs_and(sel_not_basis4, and_241);
        uint32_t sel3 = bs_or(sel_mask_not_17, sel_mask_and_241);
        uint32_t and_242 = bs_and(and_2, sel3);
        uint32_t CC__41_46_49_4c_4d_56_59 = bs_or(and_237, and_242);
        uint32_t and_248 = bs_and(and_20, and_221);
        uint32_t CC__46_58 = bs_or(and_248, and_11);
        uint32_t or_91 = bs_or(or_32, and_151);
        uint32_t or_93 = bs_or(or_91, and_92);
        uint32_t and_279 = bs_and(and_20, or_93);
        uint32_t or_95 = bs_or(and_279, and_5);
        uint32_t or_97 = bs_or(or_95, and_11);
        uint32_t CC__42_44_45_49_4e_53_54_58_5a = bs_or(or_97, and_113);
        uint32_t CC__57_58 = bs_and(and_2, sel2);
        uint32_t and_308 = bs_and(and_35, and_125);
        uint32_t and_310 = bs_and(and_20, and_308);
        uint32_t or_103 = bs_or(and_310, and_11);
        uint32_t CC__45_58_5a = bs_or(or_103, and_113);
        uint32_t or_111 = bs_or(or_68, and_92);
        uint32_t and_341 = bs_and(and_20, or_111);
        uint32_t CC__42_48_4e_58 = bs_or(and_341, and_11);
        uint32_t and_356 = bs_and(and_20, basis4);
        sel_not_basis5 = bs_not(basis5);
        uint32_t sel_mask_not_81 = bs_and(basis5, not_81);
        sel_mask_and_4 = bs_and(sel_not_basis5, and_4);
        uint32_t sel6 = bs_or(sel_mask_not_81, sel_mask_and_4);
        uint32_t and_358 = bs_and(and_356, sel6);
        uint32_t or_116 = bs_or(and_153, and_358);
        uint32_t and_365 = bs_and(and_2, and_221);
        uint32_t or_117 = bs_or(or_116, and_365);
        uint32_t CC__49_4b_4d_56_58 = bs_or(or_117, and_11);
        uint32_t and_375 = bs_and(and_162, or_);
        uint32_t and_378 = bs_and(basis5, or_);
        sel_not_basis4 = bs_not(basis4);
        sel_mask_not_213 = bs_and(basis4, not_213);
        uint32_t sel_mask_and_378 = bs_and(sel_not_basis4, and_378);
        uint32_t sel7 = bs_or(sel_mask_not_213, sel_mask_and_378);
        uint32_t and_379 = bs_and(and_20, sel7);
        uint32_t or_127 = bs_or(and_375, and_379);
        uint32_t and_383 = bs_and(and_20, and_90);
        uint32_t not_378 = bs_not(and_4);
        uint32_t and_385 = bs_and(and_383, not_378);
        uint32_t or_129 = bs_or(or_127, and_385);
        uint32_t or_131 = bs_or(or_129, and_100);
        uint32_t or_132 = bs_or(or_131, and_365);
        uint32_t and_402 = bs_and(and_2, and_6);
        uint32_t and_404 = bs_and(and_402, not_378);
        uint32_t CC__41_43_45_48_4c_4e_51_52_56_58_5a = bs_or(or_132, and_404);
        uint32_t not_409 = bs_not(and_);
        uint32_t and_416 = bs_and(or_3, not_409);
        uint32_t not_410 = bs_not(and_416);
        uint32_t and_417 = bs_and(and_1, not_410);
        uint32_t CC__48_58 = bs_and(and_9, and_417);
        uint32_t or_138 = bs_or(and_153, and_365);
        uint32_t CC__49_56_58 = bs_or(or_138, and_11);
        uint32_t or_144 = bs_or(and_127, and_37);
        uint32_t and_449 = bs_and(and_20, or_144);
        uint32_t CC__41_47_58 = bs_or(and_449, and_11);
        uint32_t or_149 = bs_or(and_48, and_9);
        uint32_t CC__53_58 = bs_and(and_2, or_149);
        uint32_t or_151 = bs_or(and_221, and_9);
        uint32_t CC__56_58 = bs_and(and_2, or_151);
        uint32_t and_487 = bs_and(and_20, and_9);
        uint32_t CC__48_58_59 = bs_or(and_487, CC__58_59);
        uint32_t not_492 = bs_not(and_90);
        uint32_t and_505 = bs_and(or_15, not_492);
        uint32_t not_493 = bs_not(and_505);
        uint32_t and_506 = bs_and(and_22, not_493);
        uint32_t and_507 = bs_and(and_20, and_506);
        uint32_t CC__42_4e_58 = bs_or(and_507, and_11);
        uint32_t and_524 = bs_and(basis7, not_29);
        uint32_t or_165 = bs_or(and_524, and_37);
        uint32_t and_532 = bs_and(and_20, or_165);
        uint32_t or_167 = bs_or(and_532, and_5);
        uint32_t CC__41_43_47_53_54_58 = bs_or(or_167, and_11);
        uint32_t or_173 = bs_or(and_48, and_151);
        uint32_t or_175 = bs_or(or_173, and_234);
        uint32_t and_562 = bs_and(and_20, or_175);
        uint32_t and_566 = bs_and(and_35, not_3);
        uint32_t and_568 = bs_and(and_2, and_566);
        uint32_t or_177 = bs_or(and_562, and_568);
        uint32_t or_178 = bs_or(or_177, and_365);
        uint32_t CC__43_49_4c_4d_54_56_58 = bs_or(or_178, and_11);
        uint32_t or_184 = bs_or(or_15, or_);
        uint32_t not_578 = bs_not(or_184);
        uint32_t and_591 = bs_and(and_2, not_578);
        uint32_t or_185 = bs_or(and_39, and_591);
        uint32_t CC__47_50_58 = bs_or(or_185, and_11);
        uint32_t or_190 = bs_or(and_221, and_151);
        uint32_t or_192 = bs_or(or_190, and_234);
        uint32_t and_616 = bs_and(and_20, or_192);
        uint32_t CC__46_49_4c_4d_56_59 = bs_or(and_616, and_242);
        uint32_t or_200 = bs_or(and_524, and_221);
        uint32_t or_202 = bs_or(or_200, and_234);
        uint32_t and_646 = bs_and(and_20, or_202);
        uint32_t or_204 = bs_or(and_646, and_568);
        uint32_t or_205 = bs_or(or_204, and_365);
        uint32_t CC__41_43_46_4c_4d_54_56_58_59 = bs_or(or_205, CC__58_59);
        uint32_t or_211 = bs_or(and_25, and_566);
        uint32_t or_213 = bs_or(or_211, and_37);
        uint32_t or_215 = bs_or(or_213, and_19);
        uint32_t or_217 = bs_or(or_215, and_92);
        uint32_t and_697 = bs_and(and_20, or_217);
        uint32_t or_219 = bs_or(and_697, and_5);
        uint32_t CC__42_44_47_4b_4e_53_54_58 = bs_or(or_219, and_11);
        uint32_t or_227 = bs_or(or_32, and_92);
        uint32_t and_727 = bs_and(and_20, or_227);
        uint32_t or_228 = bs_or(and_727, and_365);
        uint32_t or_230 = bs_or(or_228, and_11);
        uint32_t CC__42_44_45_4e_56_58_5a = bs_or(or_230, and_113);
        uint32_t or_235 = bs_or(and_48, and_221);
        uint32_t or_237 = bs_or(or_235, and_151);
        uint32_t or_239 = bs_or(or_237, and_234);
        uint32_t and_772 = bs_and(and_20, or_239);
        uint32_t or_241 = bs_or(and_772, and_27);
        uint32_t CC__43_46_49_4c_4d_52_56_59 = bs_or(or_241, and_242);
        uint32_t or_247 = bs_or(and_145, and_116);
        uint32_t and_794 = bs_and(and_20, or_247);
        uint32_t or_248 = bs_or(and_794, and_365);
        uint32_t CC__48_49_4c_56_58 = bs_or(or_248, and_11);
        uint32_t or_255 = bs_or(and_163, and_487);
        uint32_t or_257 = bs_or(or_255, and_21);
        uint32_t or_259 = bs_or(or_257, and_175);
        uint32_t and_834 = bs_and(and_99, not_378);
        uint32_t or_261 = bs_or(or_259, and_834);
        uint32_t or_263 = bs_or(or_261, and_11);
        uint32_t CC__41_42_48_4b_4e_50_52_58_5a = bs_or(or_263, and_113);
        uint32_t or_267 = bs_or(and_151, and_234);
        uint32_t and_859 = bs_and(and_20, or_267);
        uint32_t or_268 = bs_or(and_859, and_365);
        uint32_t CC__49_4c_4d_56_58 = bs_or(or_268, and_11);
        uint32_t or_276 = bs_or(and_449, and_135);
        uint32_t CC__41_47_53_58 = bs_or(or_276, and_11);
        uint32_t or_287 = bs_or(or_213, and_92);
        uint32_t and_921 = bs_and(and_20, or_287);
        uint32_t or_289 = bs_or(and_921, and_5);
        uint32_t CC__42_44_47_4e_53_54_58 = bs_or(or_289, and_11);
        uint32_t and_945 = bs_and(and_20, and_524);
        uint32_t or_296 = bs_or(and_945, and_365);
        uint32_t CC__41_43_56_58 = bs_or(or_296, and_11);
        uint32_t or_312 = bs_or(or_3, or_184);
        uint32_t not_936 = bs_not(or_312);
        uint32_t sel_not_basis1 = bs_not(basis1);
        uint32_t sel_mask_not_936 = bs_and(basis1, not_936);
        uint32_t sel_mask_or_11 = bs_and(sel_not_basis1, or_11);
        uint32_t sel14 = bs_or(sel_mask_not_936, sel_mask_or_11);
        uint32_t and_962 = bs_and(sel14, not_2);
        uint32_t or_313 = bs_or(and_12, and_962);
        uint32_t or_315 = bs_or(or_15, basis6);
        uint32_t or_316 = bs_or(basis3, or_315);
        uint32_t or_317 = bs_or(basis2, or_316);
        uint32_t and_964 = bs_and(and_1, or_317);
        uint32_t CC__1_9_b_40_42_7f = bs_or(or_313, and_964);
        uint32_t and_968 = bs_and(basis3, or_315);
        uint32_t or_330 = bs_or(basis2, and_968);
        uint32_t not_947 = bs_not(or_330);
        sel_not_basis1 = bs_not(basis1);
        uint32_t sel_mask_not_947 = bs_and(basis1, not_947);
        sel_mask_or_11 = bs_and(sel_not_basis1, or_11);
        uint32_t sel16 = bs_or(sel_mask_not_947, sel_mask_or_11);
        uint32_t and_969 = bs_and(sel16, not_2);
        uint32_t or_331 = bs_or(and_12, and_969);
        uint32_t or_333 = bs_or(or_15, and_4);
        uint32_t and_972 = bs_and(basis3, or_333);
        uint32_t or_334 = bs_or(basis2, and_972);
        uint32_t and_973 = bs_and(and_1, or_334);
        uint32_t CC__1_9_b_51_53_7f = bs_or(or_331, and_973);
        uint32_t or_347 = bs_or(or_3, and_90);
        uint32_t not_958 = bs_not(or_347);
        sel_not_basis1 = bs_not(basis1);
        uint32_t sel_mask_not_958 = bs_and(basis1, not_958);
        sel_mask_or_11 = bs_and(sel_not_basis1, or_11);
        uint32_t sel18 = bs_or(sel_mask_not_958, sel_mask_or_11);
        uint32_t and_978 = bs_and(sel18, not_2);
        uint32_t or_348 = bs_or(and_12, and_978);
        uint32_t and_981 = bs_and(and_90, or_);
        uint32_t or_350 = bs_or(basis3, and_981);
        uint32_t or_351 = bs_or(basis2, or_350);
        uint32_t and_982 = bs_and(and_1, or_351);
        uint32_t CC__1_9_b_4b_4d_7f = bs_or(or_348, and_982);
        uint32_t CC__41_58 = bs_or(and_129, and_11);
        uint32_t and_1006 = bs_and(and_125, basis4);
        uint32_t and_1007 = bs_and(and_20, and_1006);
        uint32_t or_362 = bs_or(and_1007, and_591);
        uint32_t or_364 = bs_or(or_362, and_568);
        uint32_t or_365 = bs_or(or_364, and_365);
        uint32_t CC__49_4d_50_54_56_58 = bs_or(or_365, and_11);
        uint32_t or_373 = bs_or(or_32, and_37);
        uint32_t and_1048 = bs_and(and_20, or_373);
        uint32_t or_375 = bs_or(and_1048, and_11);
        uint32_t CC__42_44_45_47_58_5a = bs_or(or_375, and_113);
        uint32_t not_1054 = bs_not(and_35);
        uint32_t and_1073 = bs_and(or_15, not_1054);
        uint32_t not_1055 = bs_not(and_1073);
        uint32_t and_1074 = bs_and(and_125, not_1055);
        uint32_t and_1075 = bs_and(and_20, and_1074);
        uint32_t not_1062 = bs_not(or_315);
        uint32_t and_1079 = bs_and(and_2, not_1062);
        uint32_t or_382 = bs_or(and_1075, and_1079);
        uint32_t CC__41_45_50_51_58_5a = bs_or(or_382, and_404);
        uint32_t not_1084 = bs_not(and_566);
        uint32_t and_1097 = bs_and(or_184, not_1084);
        uint32_t not_1092 = bs_not(and_9);
        uint32_t and_1105 = bs_and(and_1097, not_1092);
        uint32_t not_1093 = bs_not(and_1105);
        uint32_t CC__50_54_58 = bs_and(and_2, not_1093);
        uint32_t and_1117 = bs_and(and_20, or_32);
        uint32_t or_394 = bs_or(and_1117, and_11);
        uint32_t CC__42_44_45_58_5a = bs_or(or_394, and_113);
        uint32_t and_1143 = bs_and(and_125, not_60);
        uint32_t or_401 = bs_or(and_1143, and_116);
        uint32_t and_1150 = bs_and(and_20, or_401);
        uint32_t or_403 = bs_or(and_1150, and_5);
        uint32_t or_404 = bs_or(or_403, and_365);
        uint32_t CC__41_49_4c_53_54_56_58 = bs_or(or_404, and_11);
        uint32_t and_1185 = bs_and(and_20, and_35);
        uint32_t and_1186 = bs_and(and_1185, or_);
        uint32_t or_413 = bs_or(and_945, and_1186);
        uint32_t or_415 = bs_or(or_413, and_153);
        uint32_t and_1197 = bs_and(and_20, and_234);
        uint32_t or_417 = bs_or(or_415, and_1197);
        uint32_t or_419 = bs_or(or_417, and_568);
        uint32_t or_420 = bs_or(or_419, and_365);
        uint32_t or_422 = bs_or(or_420, and_11);
        uint32_t CC__41_43_45_47_49_4c_4d_54_56_58_5a = bs_or(or_422, and_113);
        uint32_t or_428 = bs_or(and_1143, and_234);
        uint32_t and_1243 = bs_and(and_20, or_428);
        uint32_t or_429 = bs_or(and_1243, and_365);
        uint32_t CC__41_49_4c_4d_56_58 = bs_or(or_429, and_11);
        uint32_t and_1259 = bs_and(and_20, not_);
        uint32_t xor_4 = bs_xor(basis5, or_);
        uint32_t and_1260 = bs_and(and_1259, xor_4);
        uint32_t or_436 = bs_or(and_1260, and_153);
        uint32_t or_438 = bs_or(or_436, and_175);
        uint32_t or_440 = bs_or(or_438, and_5);
        uint32_t CC__41_44_49_4e_53_54_58 = bs_or(or_440, and_11);
        uint32_t or_447 = bs_or(and_375, and_39);
        uint32_t or_449 = bs_or(or_447, and_175);
        uint32_t or_451 = bs_or(or_449, and_5);
        uint32_t or_452 = bs_or(or_451, and_365);
        uint32_t CC__41_43_47_4e_53_54_56_58 = bs_or(or_452, and_11);
        uint32_t or_460 = bs_or(and_524, and_151);
        uint32_t or_462 = bs_or(or_460, and_234);
        uint32_t and_1344 = bs_and(and_20, or_462);
        uint32_t or_463 = bs_or(and_1344, and_365);
        uint32_t CC__41_43_49_4c_4d_56_58 = bs_or(or_463, and_11);
        uint32_t and_1371 = bs_and(and_20, and_1143);
        uint32_t and_1376 = bs_and(and_356, sel);
        uint32_t or_471 = bs_or(and_1371, and_1376);
        uint32_t or_473 = bs_or(or_471, and_568);
        uint32_t or_474 = bs_or(or_473, and_365);
        uint32_t CC__41_49_4b_4c_54_56_58 = bs_or(or_474, and_11);
        uint32_t or_481 = bs_or(and_375, and_385);
        sel_not_basis5 = bs_not(basis5);
        sel_mask_not_3 = bs_and(basis5, not_3);
        uint32_t sel_mask_basis6 = bs_and(sel_not_basis5, basis6);
        uint32_t sel23 = bs_or(sel_mask_not_3, sel_mask_basis6);
        uint32_t and_1410 = bs_and(and_3, sel23);
        uint32_t or_483 = bs_or(or_481, and_1410);
        uint32_t CC__41_43_4c_4e_52_54_56_59 = bs_or(or_483, and_242);
        uint32_t or_493 = bs_or(or_200, and_151);
        uint32_t or_495 = bs_or(or_493, and_234);
        uint32_t and_1447 = bs_and(and_20, or_495);
        uint32_t or_496 = bs_or(and_1447, and_365);
        uint32_t CC__41_43_46_49_4c_4d_56_58 = bs_or(or_496, and_11);
        uint32_t and_1473 = bs_and(and_20, or_190);
        uint32_t or_503 = bs_or(and_1473, and_358);
        uint32_t or_505 = bs_or(or_503, and_27);
        uint32_t or_506 = bs_or(or_505, and_365);
        uint32_t CC__46_49_4b_4d_52_56_58 = bs_or(or_506, and_11);
        uint32_t or_514 = bs_or(or_144, and_151);
        uint32_t and_1516 = bs_and(and_20, or_514);
        uint32_t or_516 = bs_or(and_1516, and_135);
        uint32_t or_517 = bs_or(or_516, and_365);
        uint32_t CC__41_47_49_53_56_58 = bs_or(or_517, and_11);
        uint32_t adv = BSAdvanceRightFunctionSync(CC__53_54_58, 1, advance_memory + 0);
        uint32_t m = bs_and(adv, CC__1_9_b_7f);
        uint32_t adv1 = BSAdvanceRightFunctionSync(m, 1, advance_memory + 0);
        uint32_t m1 = bs_and(adv1, CC__4b_52_58);
        uint32_t adv2 = BSAdvanceRightFunctionSync(CC__47_58, 1, advance_memory + 0);
        uint32_t m2 = bs_and(adv2, CC__1_9_b_7f);
        uint32_t adv3 = BSAdvanceRightFunctionSync(m2, 1, advance_memory + 0);
        uint32_t m3 = bs_and(adv3, CC__43_4b_52_58);
        uint32_t adv4 = BSAdvanceRightFunctionSync(m3, 1, advance_memory + 0);
        uint32_t m4 = bs_and(adv4, CC__42_44_45_48_4e_51_52_58_5a);
        uint32_t adv5 = BSAdvanceRightFunctionSync(m4, 1, advance_memory + 0);
        uint32_t m5 = bs_and(adv5, CC__4c_58);
        uint32_t adv6 = BSAdvanceRightFunctionSync(m5, 1, advance_memory + 0);
        uint32_t m6 = bs_and(adv6, CC__41_53_58);
        uint32_t adv7 = BSAdvanceRightFunctionSync(m6, 1, advance_memory + 0);
        uint32_t m7 = bs_and(adv7, CC__58_59);
        uint32_t adv8 = BSAdvanceRightFunctionSync(m7, 1, advance_memory + 0);
        uint32_t m8 = bs_and(adv8, CC__1_9_b_7f);
        uint32_t adv9 = BSAdvanceRightFunctionSync(m8, 1, advance_memory + 0);
        uint32_t m9 = bs_and(adv9, CC__49_58);
        uint32_t adv10 = BSAdvanceRightFunctionSync(m9, 1, advance_memory + 0);
        uint32_t m10 = bs_and(adv10, CC__41_42_4b_4e_52_53_58);
        uint32_t alt = bs_or(m1, m10);
        uint32_t adv11 = BSAdvanceRightFunctionSync(CC__52_58, 1, advance_memory + 0);
        uint32_t m11 = bs_and(adv11, CC__52_57_58);
        uint32_t adv12 = BSAdvanceRightFunctionSync(m11, 1, advance_memory + 0);
        uint32_t m12 = bs_and(adv12, CC__41_46_49_4c_4d_56_59);
        uint32_t adv13 = BSAdvanceRightFunctionSync(m12, 1, advance_memory + 0);
        uint32_t m13 = bs_and(adv13, CC__46_58);
        uint32_t adv14 = BSAdvanceRightFunctionSync(m13, 1, advance_memory + 0);
        uint32_t m14 = bs_and(adv14, CC__42_44_45_49_4e_53_54_58_5a);
        uint32_t adv15 = BSAdvanceRightFunctionSync(m14, 1, advance_memory + 0);
        uint32_t m15 = bs_and(adv15, CC__57_58);
        uint32_t adv16 = BSAdvanceRightFunctionSync(m15, 1, advance_memory + 0);
        uint32_t m16 = bs_and(adv16, CC__45_58_5a);
        uint32_t adv17 = BSAdvanceRightFunctionSync(m16, 1, advance_memory + 0);
        uint32_t m17 = bs_and(adv17, CC__42_48_4e_58);
        uint32_t adv18 = BSAdvanceRightFunctionSync(m17, 1, advance_memory + 0);
        uint32_t m18 = bs_and(adv18, CC__49_4b_4d_56_58);
        uint32_t adv19 = BSAdvanceRightFunctionSync(m18, 1, advance_memory + 0);
        uint32_t m19 = bs_and(adv19, CC__41_43_45_48_4c_4e_51_52_56_58_5a);
        uint32_t advance = BSAdvanceRightFunctionSync(CC__1_9_b_7f, 1, advance_memory + 0);
        uint32_t at2inarow = bs_and(CC__1_9_b_7f, advance);
        uint32_t advance1 = BSAdvanceRightFunctionSync(at2inarow, 2, advance_memory + 0);
        uint32_t at4inarow = bs_and(at2inarow, advance1);
        uint32_t advance2 = BSAdvanceRightFunctionSync(m19, 4, advance_memory + 0);
        uint32_t lowerbound = bs_and(advance2, at4inarow);
        uint32_t alt1 = bs_or(alt, lowerbound);
        uint32_t adv20 = BSAdvanceRightFunctionSync(CC__48_58, 1, advance_memory + 0);
        uint32_t m20 = bs_and(adv20, CC__1_9_b_7f);
        uint32_t adv21 = BSAdvanceRightFunctionSync(m20, 1, advance_memory + 0);
        uint32_t m21 = bs_and(adv21, CC__49_56_58);
        uint32_t adv22 = BSAdvanceRightFunctionSync(m21, 1, advance_memory + 0);
        uint32_t m22 = bs_and(adv22, CC__1_9_b_7f);
        uint32_t adv23 = BSAdvanceRightFunctionSync(m22, 1, advance_memory + 0);
        uint32_t m23 = bs_and(adv23, CC__47_58);
        uint32_t adv24 = BSAdvanceRightFunctionSync(m23, 1, advance_memory + 0);
        uint32_t m24 = bs_and(adv24, CC__4b_52_58);
        uint32_t adv25 = BSAdvanceRightFunctionSync(m24, 1, advance_memory + 0);
        uint32_t m25 = bs_and(adv25, CC__1_9_b_7f);
        uint32_t adv26 = BSAdvanceRightFunctionSync(m25, 1, advance_memory + 0);
        uint32_t m26 = bs_and(adv26, CC__46_58);
        uint32_t adv27 = BSAdvanceRightFunctionSync(m26, 1, advance_memory + 0);
        uint32_t m27 = bs_and(adv27, CC__41_47_58);
        uint32_t adv28 = BSAdvanceRightFunctionSync(m27, 1, advance_memory + 0);
        uint32_t m28 = bs_and(adv28, CC__53_58);
        uint32_t adv29 = BSAdvanceRightFunctionSync(m28, 1, advance_memory + 0);
        uint32_t m29 = bs_and(adv29, CC__1_9_b_7f);
        uint32_t adv30 = BSAdvanceRightFunctionSync(m29, 1, advance_memory + 0);
        uint32_t m30 = bs_and(adv30, CC__56_58);
        uint32_t adv31 = BSAdvanceRightFunctionSync(m30, 1, advance_memory + 0);
        uint32_t m31 = bs_and(adv31, CC__53_54_58);
        uint32_t adv32 = BSAdvanceRightFunctionSync(m31, 1, advance_memory + 0);
        uint32_t m32 = bs_and(adv32, CC__48_58_59);
        uint32_t adv33 = BSAdvanceRightFunctionSync(m32, 1, advance_memory + 0);
        uint32_t m33 = bs_and(adv33, CC__45_58_5a);
        uint32_t alt2 = bs_or(alt1, m33);
        uint32_t adv34 = BSAdvanceRightFunctionSync(CC__42_4e_58, 1, advance_memory + 0);
        uint32_t m34 = bs_and(adv34, CC__1_9_b_7f);
        uint32_t adv35 = BSAdvanceRightFunctionSync(m34, 1, advance_memory + 0);
        uint32_t m35 = bs_and(adv35, CC__41_43_47_53_54_58);
        uint32_t adv36 = BSAdvanceRightFunctionSync(m35, 1, advance_memory + 0);
        uint32_t m36 = bs_and(adv36, CC__43_49_4c_4d_54_56_58);
        uint32_t adv37 = BSAdvanceRightFunctionSync(m36, 1, advance_memory + 0);
        uint32_t m37 = bs_and(adv37, CC__47_50_58);
        uint32_t advance3 = BSAdvanceRightFunctionSync(CC__46_49_4c_4d_56_59, 1, advance_memory + 0);
        uint32_t at2inarow1 = bs_and(CC__46_49_4c_4d_56_59, advance3);
        uint32_t advance4 = BSAdvanceRightFunctionSync(m37, 2, advance_memory + 0);
        uint32_t lowerbound1 = bs_and(advance4, at2inarow1);
        uint32_t adv38 = BSAdvanceRightFunctionSync(lowerbound1, 1, advance_memory + 0);
        uint32_t m38 = bs_and(adv38, CC__41_43_46_4c_4d_54_56_58_59);
        uint32_t adv39 = BSAdvanceRightFunctionSync(m38, 1, advance_memory + 0);
        uint32_t m39 = bs_and(adv39, CC__52_58);
        uint32_t adv40 = BSAdvanceRightFunctionSync(m39, 1, advance_memory + 0);
        uint32_t m40 = bs_and(adv40, CC__1_9_b_7f);
        uint32_t adv41 = BSAdvanceRightFunctionSync(m40, 1, advance_memory + 0);
        uint32_t m41 = bs_and(adv41, CC__42_44_47_4b_4e_53_54_58);
        uint32_t adv42 = BSAdvanceRightFunctionSync(m41, 1, advance_memory + 0);
        uint32_t m42 = bs_and(adv42, CC__42_44_45_4e_56_58_5a);
        uint32_t adv43 = BSAdvanceRightFunctionSync(m42, 1, advance_memory + 0);
        uint32_t m43 = bs_and(adv43, CC__43_46_49_4c_4d_52_56_59);
        uint32_t adv44 = BSAdvanceRightFunctionSync(m43, 1, advance_memory + 0);
        uint32_t m44 = bs_and(adv44, CC__48_49_4c_56_58);
        uint32_t adv45 = BSAdvanceRightFunctionSync(m44, 1, advance_memory + 0);
        uint32_t m45 = bs_and(adv45, CC__1_9_b_7f);
        uint32_t adv46 = BSAdvanceRightFunctionSync(m45, 1, advance_memory + 0);
        uint32_t m46 = bs_and(adv46, CC__1_9_b_7f);
        uint32_t adv47 = BSAdvanceRightFunctionSync(m46, 1, advance_memory + 0);
        uint32_t m47 = bs_and(adv47, CC__41_42_48_4b_4e_50_52_58_5a);
        uint32_t alt3 = bs_or(alt2, m47);
        uint32_t advance5 = BSAdvanceRightFunctionSync(CC__49_4c_4d_56_58, 1, advance_memory + 0);
        uint32_t at2inarow2 = bs_and(CC__49_4c_4d_56_58, advance5);
        uint32_t advance23 = BSAdvanceRightFunctionSync(0xFFFFFFFF, 1, advance_memory + 0);
        uint32_t lowerbound2 = bs_and(advance23, at2inarow2);
        uint32_t adv48 = BSAdvanceRightFunctionSync(lowerbound2, 1, advance_memory + 0);
        uint32_t m48 = bs_and(adv48, CC__41_47_53_58);
        uint32_t adv49 = BSAdvanceRightFunctionSync(m48, 1, advance_memory + 0);
        uint32_t m49 = bs_and(adv49, CC__1_9_b_7f);
        uint32_t adv50 = BSAdvanceRightFunctionSync(m49, 1, advance_memory + 0);
        uint32_t m50 = bs_and(adv50, CC__47_58);
        uint32_t adv51 = BSAdvanceRightFunctionSync(m50, 1, advance_memory + 0);
        uint32_t m51 = bs_and(adv51, CC__47_58);
        uint32_t adv52 = BSAdvanceRightFunctionSync(m51, 1, advance_memory + 0);
        uint32_t m52 = bs_and(adv52, CC__49_56_58);
        uint32_t adv53 = BSAdvanceRightFunctionSync(m52, 1, advance_memory + 0);
        uint32_t m53 = bs_and(adv53, CC__1_9_b_7f);
        uint32_t adv54 = BSAdvanceRightFunctionSync(m53, 1, advance_memory + 0);
        uint32_t m54 = bs_and(adv54, CC__42_44_47_4e_53_54_58);
        uint32_t advance8 = BSAdvanceRightFunctionSync(at2inarow, 1, advance_memory + 0);
        uint32_t at3inarow = bs_and(at2inarow, advance8);
        uint32_t advance9 = BSAdvanceRightFunctionSync(m54, 3, advance_memory + 0);
        uint32_t lowerbound3 = bs_and(advance9, at3inarow);
        uint32_t adv55 = BSAdvanceRightFunctionSync(lowerbound3, 1, advance_memory + 0);
        uint32_t m55 = bs_and(adv55, CC__41_43_56_58);
        uint32_t advance11 = BSAdvanceRightFunctionSync(m55, 2, advance_memory + 0);
        uint32_t lowerbound4 = bs_and(advance11, at2inarow);
        uint32_t adv56 = BSAdvanceRightFunctionSync(lowerbound4, 1, advance_memory + 0);
        uint32_t m56 = bs_and(adv56, CC__1_9_b_40_42_7f);
        uint32_t adv57 = BSAdvanceRightFunctionSync(m56, 1, advance_memory + 0);
        uint32_t m57 = bs_and(adv57, CC__1_9_b_51_53_7f);
        uint32_t adv58 = BSAdvanceRightFunctionSync(m57, 1, advance_memory + 0);
        uint32_t m58 = bs_and(adv58, CC__1_9_b_7f);
        uint32_t adv59 = BSAdvanceRightFunctionSync(m58, 1, advance_memory + 0);
        uint32_t m59 = bs_and(adv59, CC__1_9_b_4b_4d_7f);
        uint32_t adv60 = BSAdvanceRightFunctionSync(m59, 1, advance_memory + 0);
        uint32_t m60 = bs_and(adv60, CC__47_58);
        uint32_t adv61 = BSAdvanceRightFunctionSync(m60, 1, advance_memory + 0);
        uint32_t m61 = bs_and(adv61, CC__41_58);
        uint32_t alt4 = bs_or(alt3, m61);
        uint32_t adv62 = BSAdvanceRightFunctionSync(CC__49_4d_50_54_56_58, 1, advance_memory + 0);
        uint32_t m62 = bs_and(adv62, CC__42_44_45_47_58_5a);
        uint32_t advance13 = BSAdvanceRightFunctionSync(m62, 2, advance_memory + 0);
        uint32_t lowerbound5 = bs_and(advance13, at2inarow);
        uint32_t adv63 = BSAdvanceRightFunctionSync(lowerbound5, 1, advance_memory + 0);
        uint32_t m63 = bs_and(adv63, CC__1_9_b_7f);
        uint32_t m64 = bs_or(m63, lowerbound5);
        uint32_t adv64 = BSAdvanceRightFunctionSync(m64, 1, advance_memory + 0);
        uint32_t m65 = bs_and(adv64, CC__41_45_50_51_58_5a);
        uint32_t adv65 = BSAdvanceRightFunctionSync(m65, 1, advance_memory + 0);
        uint32_t m66 = bs_and(adv65, CC__47_58);
        uint32_t adv66 = BSAdvanceRightFunctionSync(m66, 1, advance_memory + 0);
        uint32_t m67 = bs_and(adv66, CC__50_54_58);
        uint32_t adv67 = BSAdvanceRightFunctionSync(m67, 1, advance_memory + 0);
        uint32_t m68 = bs_and(adv67, CC__53_54_58);
        uint32_t adv68 = BSAdvanceRightFunctionSync(m68, 1, advance_memory + 0);
        uint32_t m69 = bs_and(adv68, CC__42_44_45_58_5a);
        uint32_t adv69 = BSAdvanceRightFunctionSync(m69, 1, advance_memory + 0);
        uint32_t m70 = bs_and(adv69, CC__41_49_4c_53_54_56_58);
        uint32_t adv70 = BSAdvanceRightFunctionSync(m70, 1, advance_memory + 0);
        uint32_t m71 = bs_and(adv70, CC__41_43_45_47_49_4c_4d_54_56_58_5a);
        uint32_t adv71 = BSAdvanceRightFunctionSync(m71, 1, advance_memory + 0);
        uint32_t m72 = bs_and(adv71, CC__41_49_4c_4d_56_58);
        uint32_t adv72 = BSAdvanceRightFunctionSync(m72, 1, advance_memory + 0);
        uint32_t m73 = bs_and(adv72, CC__41_46_49_4c_4d_56_59);
        uint32_t adv73 = BSAdvanceRightFunctionSync(m73, 1, advance_memory + 0);
        uint32_t m74 = bs_and(adv73, CC__41_44_49_4e_53_54_58);
        uint32_t advance15 = BSAdvanceRightFunctionSync(m74, 2, advance_memory + 0);
        uint32_t lowerbound6 = bs_and(advance15, at2inarow);
        uint32_t adv74 = BSAdvanceRightFunctionSync(lowerbound6, 1, advance_memory + 0);
        uint32_t m75 = bs_and(adv74, CC__1_9_b_7f);
        uint32_t m76 = bs_or(m75, lowerbound6);
        uint32_t adv75 = BSAdvanceRightFunctionSync(m76, 1, advance_memory + 0);
        uint32_t m77 = bs_and(adv75, CC__41_43_47_4e_53_54_56_58);
        uint32_t advance18 = BSAdvanceRightFunctionSync(m77, 4, advance_memory + 0);
        uint32_t lowerbound7 = bs_and(advance18, at4inarow);
        uint32_t adv76 = BSAdvanceRightFunctionSync(lowerbound7, 1, advance_memory + 0);
        uint32_t advance19 = BSAdvanceRightFunctionSync(adv76, 1, advance_memory + 0);
        uint32_t within1 = bs_or(adv76, advance19);
        uint32_t advance20 = BSAdvanceRightFunctionSync(within1, 1, advance_memory + 0);
        uint32_t within2 = bs_or(within1, advance20);
        uint32_t test = adv76;
        uint32_t accum = adv76;
        if (idx < n_unit_basic) {
            accum_stream[idx] |= accum;
            within2_stream[idx] = within2;
            CC__41_43_49_4c_4d_56_58_stream[idx] = CC__41_43_49_4c_4d_56_58;
            CC__41_49_4b_4c_54_56_58_stream[idx] = CC__41_49_4b_4c_54_56_58;
            CC__41_43_4c_4e_52_54_56_59_stream[idx] = CC__41_43_4c_4e_52_54_56_59;
            CC__42_44_45_47_58_5a_stream[idx] = CC__42_44_45_47_58_5a;
            CC__41_43_46_49_4c_4d_56_58_stream[idx] = CC__41_43_46_49_4c_4d_56_58;
            CC__46_49_4b_4d_52_56_58_stream[idx] = CC__46_49_4b_4d_52_56_58;
            CC__41_47_49_53_56_58_stream[idx] = CC__41_47_49_53_56_58;
            at2inarow_stream[idx] = at2inarow;
            CC__45_58_5a_stream[idx] = CC__45_58_5a;
            CC__48_58_stream[idx] = CC__48_58;
            alt4_stream[idx] = alt4;
            test_stream[idx] = test;
            CC__1_9_b_7f_stream[idx] = CC__1_9_b_7f;
        }
        __syncthreads();
    }
    __syncthreads();
    while (!bs_all_zeros(test_stream, n_unit_basic)) {
        for (uint32_t i = 0; i < ceil(1.0 * n_unit_basic / (blockDim.x - 1)); i += 1) {
            int idx = i * (blockDim.x - 1) + threadIdx.x;
            uint32_t accum = accum_stream[idx];
            uint32_t CC__1_9_b_7f = CC__1_9_b_7f_stream[idx];
            uint32_t test = test_stream[idx];
            uint32_t m78 = bs_and(test, CC__1_9_b_7f);
            uint32_t adv78 = BSAdvanceRightFunctionSync(m78, 1, advance_memory + 0);
            uint32_t not_1555 = bs_not(accum);
            uint32_t and_1560 = bs_and(adv78, not_1555);
            test = and_1560;
            uint32_t or_538 = bs_or(adv78, accum);
            accum = or_538;
            if (idx < n_unit_basic) {
                accum_stream_next[idx] |= accum;
                test_stream_next[idx] = test;
            }
        }
        __syncthreads();
        swap_pointer(&accum_stream, &accum_stream_next);
        swap_pointer(&test_stream, &test_stream_next);
    }
    __syncthreads();
    for (uint32_t i = 0; i < ceil(1.0 * n_unit_basic / (blockDim.x - 1)); i += 1) {
        int idx = i * (blockDim.x - 1) + threadIdx.x;
        uint32_t alt4 = alt4_stream[idx];
        uint32_t CC__48_58 = CC__48_58_stream[idx];
        uint32_t CC__45_58_5a = CC__45_58_5a_stream[idx];
        uint32_t at2inarow = at2inarow_stream[idx];
        uint32_t CC__41_47_49_53_56_58 = CC__41_47_49_53_56_58_stream[idx];
        uint32_t CC__46_49_4b_4d_52_56_58 = CC__46_49_4b_4d_52_56_58_stream[idx];
        uint32_t CC__41_43_46_49_4c_4d_56_58 = CC__41_43_46_49_4c_4d_56_58_stream[idx];
        uint32_t CC__42_44_45_47_58_5a = CC__42_44_45_47_58_5a_stream[idx];
        uint32_t CC__41_43_4c_4e_52_54_56_59 = CC__41_43_4c_4e_52_54_56_59_stream[idx];
        uint32_t CC__41_49_4b_4c_54_56_58 = CC__41_49_4b_4c_54_56_58_stream[idx];
        uint32_t CC__41_43_49_4c_4d_56_58 = CC__41_43_49_4c_4d_56_58_stream[idx];
        uint32_t within2 = within2_stream[idx];
        uint32_t accum = accum_stream[idx];
        uint32_t bounded = bs_and(accum, within2);
        uint32_t m79 = bs_and(bounded, CC__41_43_49_4c_4d_56_58);
        uint32_t adv79 = BSAdvanceRightFunctionSync(m79, 1, advance_memory + 0);
        uint32_t m80 = bs_and(adv79, CC__41_49_4b_4c_54_56_58);
        uint32_t adv80 = BSAdvanceRightFunctionSync(m80, 1, advance_memory + 0);
        uint32_t m81 = bs_and(adv80, CC__41_43_4c_4e_52_54_56_59);
        uint32_t adv81 = BSAdvanceRightFunctionSync(m81, 1, advance_memory + 0);
        uint32_t m82 = bs_and(adv81, CC__42_44_45_47_58_5a);
        uint32_t adv82 = BSAdvanceRightFunctionSync(m82, 1, advance_memory + 0);
        uint32_t m83 = bs_and(adv82, CC__41_43_46_49_4c_4d_56_58);
        uint32_t adv83 = BSAdvanceRightFunctionSync(m83, 1, advance_memory + 0);
        uint32_t m84 = bs_and(adv83, CC__46_49_4b_4d_52_56_58);
        uint32_t adv84 = BSAdvanceRightFunctionSync(m84, 1, advance_memory + 0);
        uint32_t m85 = bs_and(adv84, CC__41_47_49_53_56_58);
        uint32_t advance22 = BSAdvanceRightFunctionSync(m85, 2, advance_memory + 0);
        uint32_t lowerbound8 = bs_and(advance22, at2inarow);
        uint32_t adv85 = BSAdvanceRightFunctionSync(lowerbound8, 1, advance_memory + 0);
        uint32_t m86 = bs_and(adv85, CC__45_58_5a);
        uint32_t adv86 = BSAdvanceRightFunctionSync(m86, 1, advance_memory + 0);
        uint32_t m87 = bs_and(adv86, CC__48_58);
        uint32_t alt5 = bs_or(alt4, m87);
        uint32_t bs_result_unit = alt5;
        if (idx < n_unit_basic) {
            bs_result_stream[idx] |= bs_result_unit;
        }
        __syncthreads();
    }
    __syncthreads();
}
