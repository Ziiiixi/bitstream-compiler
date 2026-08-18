// Prepared from gpjson-vldb/gpjson at revision
// c912c1f1564c8bd750765b0650f59b56d334ce71.
// Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License, Version 1.0; see
// ../../third_party/licenses/gpJSON-UPL-1.0.txt.

using uint8_t = unsigned char;
using uint32_t = unsigned int;
using uint64_t = unsigned long long;

#define __global__
#define __device__
#define __host__
#define __forceinline__ inline
#define assert(x) ((void)0)

struct Dim3 { int x; };
Dim3 blockIdx, blockDim, threadIdx, gridDim;

#line 1 "upstream/gpJSON/kernels/uncombined/escape-carry-index.cu"
__global__ void gpjson_escape_carry(char *file, int fileSize, char *escapeCarryIndex) {
  int index = blockIdx.x * blockDim.x + threadIdx.x;
  int stride = blockDim.x * gridDim.x;

  int charsPerThread = (fileSize+stride-1) / stride;
  int bitmapAlignedCharsPerThread = ((charsPerThread + 64 - 1) / 64) * 64;
  int start = index * bitmapAlignedCharsPerThread;
  int end = start + bitmapAlignedCharsPerThread;

  int carry = 0;

  for (int i = start; i < end && i < fileSize; i += 1) {
    if (file[i] == '\\') {
      carry = 1 ^ carry;
    } else {
      carry = 0;
    }
  }

  escapeCarryIndex[index] = (char)carry;
}


#line 1 "upstream/gpJSON/kernels/uncombined/escape-index.cu"
__global__ void gpjson_escape_index(char *file, long fileSize, bool *escapeCarryIndex, long *escapeIndex) {
  int index = blockIdx.x * blockDim.x + threadIdx.x;
  int stride = blockDim.x * gridDim.x;

  int charsPerThread = (fileSize+stride-1) / stride;
  int bitmapAlignedCharsPerThread = ((charsPerThread + 64 - 1) / 64) * 64;
  int start = index * bitmapAlignedCharsPerThread;
  int end = start + bitmapAlignedCharsPerThread;

  int carry = index == 0 ? 0 : (int)escapeCarryIndex[index - 1];

  long escape = 0;

  int escapeCount = 0;
  int totalCount = end - start;

  for (long i = start; i < end && i < fileSize; i += 1) {
    if (carry == 1) {
      escape = escape | (1L << (i % 64));
    }

    if (file[i] == '\\') {
      escapeCount++;
      carry = carry ^ 1;
    } else {
      carry = 0;
    }

    if (i % 64 == 63) {
      escapeIndex[i / 64] = escape;
      escape = 0;
    }
  }

  if (fileSize <= end && (fileSize - 1) % 64 != 63L && fileSize - start > 0) {
    escapeIndex[(fileSize - 1) / 64] = escape;
  }

  assert(escapeCount != totalCount);
}


#line 1 "upstream/gpJSON/kernels/quote-index.cu"
__global__ void gpjson_quote_index(char *file, int fileSize, long *escapeIndex, long *quoteIndex, char *quoteCarryIndex) {
  int index = blockIdx.x * blockDim.x + threadIdx.x;
  int stride = blockDim.x * gridDim.x;

  int charsPerThread = (fileSize+stride-1) / stride;
  int bitmapAlignedCharsPerThread = ((charsPerThread + 64 - 1) / 64) * 64;
  int start = index * bitmapAlignedCharsPerThread;
  int end = start + bitmapAlignedCharsPerThread;

  long escaped = 0;
  long quote = 0;
  int quoteCount = 0;

  int final_loop_iteration = end;
  if (fileSize < end) {
    final_loop_iteration = fileSize;
  }

  for (long i = start; i < end && i < fileSize; i += 1) {
    long offsetInBlock = i % 64;

    if (offsetInBlock == 0) {
      escaped = escapeIndex[i / 64];
    }

    if (file[i] == '"') {
      if ((escaped & (1L << offsetInBlock)) == 0) {
        quote = quote | (1L << offsetInBlock);
        quoteCount++;
      }
    }

    if (offsetInBlock == 63L) {
      quoteIndex[i / 64] = quote;
      quote = 0;
    }
  }

  if (fileSize <= end && (fileSize - 1) % 64 != 63L && fileSize - start > 0) {
    quoteIndex[(fileSize - 1) / 64] = quote;
  }

  quoteCarryIndex[index] = quoteCount & 1;
}


#line 1 "upstream/gpJSON/kernels/xor-pre-scan.cu"
__global__ void gpjson_xor_pre_scan(char *charArr, int n) {
    int index = blockIdx.x * blockDim.x + threadIdx.x;
    int stride = blockDim.x * gridDim.x;
    long elemsPerThread = (n+stride-1) / stride;

    long start = index * elemsPerThread;
    long end = start + elemsPerThread;

    int prev = 0;
    for (long i = start; i < end && i < n; i++) {
        prev = prev ^ ((int)charArr[i]);
        charArr[i] = (char)prev;
    }
}

#line 1 "upstream/gpJSON/kernels/xor-post-scan.cu"
__global__ void gpjson_xor_post_scan(char *charArr, int n, int stride, char *base) {
    long elemsPerThread = (n+stride-1) / stride;
    int prev = 0;
    for (long i = 0; i < stride-1; i++) {
        base[i] = (char)prev;
        prev = prev ^ ((int)charArr[elemsPerThread * (i+1) - 1]);
    }
    base[stride-1] = (char)prev;
}

#line 1 "upstream/gpJSON/kernels/xor-rebase.cu"
__global__ void gpjson_xor_rebase(char *charArr, int n, char *base) {
    int index = blockIdx.x * blockDim.x + threadIdx.x;
    int stride = blockDim.x * gridDim.x;
    long elemsPerThread = (n+stride-1) / stride;

    long start = index * elemsPerThread;
    long end = start + elemsPerThread;

    for (long i = start; i < end && i < n; i++) {
        charArr[i] = (char)(((int)charArr[i]) ^ ((int)base[index]));
    }
}

#line 1 "upstream/gpJSON/kernels/string-index.cu"
__global__ void gpjson_string_index(long *stringIndex, int stringIndexSize, char *quoteCarryIndex) {
  int index = blockIdx.x * blockDim.x + threadIdx.x;
  int stride = blockDim.x * gridDim.x;

  int elemsPerThread = (stringIndexSize + stride - 1) / stride;
  int start = index * elemsPerThread;
  int end = start + elemsPerThread;

  long bitString = index > 0 && quoteCarryIndex[index - 1] == 1 ? 0xffffffffffffffffL : 0;

  for (int i = start; i < end && i < stringIndexSize; i += 1) {
    long quotes = stringIndex[i];

    // https://github.com/simdjson/simdjson/blob/cfc965ff9ada688cf5950da829331b28dfcb949f/include/simdjson/arm64/bitmask.h
    quotes ^= quotes << 1;
    quotes ^= quotes << 2;
    quotes ^= quotes << 4;
    quotes ^= quotes << 8;
    quotes ^= quotes << 16;
    quotes ^= quotes << 32;

    quotes = quotes ^ bitString;

    stringIndex[i] = quotes;

    bitString = quotes >> 63;
  }
}


__global__ void gpjson_structural_bitmap(char *file, int fileSize, long *stringIndex, long *structuralBitmap) {
  int index = blockIdx.x * blockDim.x + threadIdx.x;
  int stride = blockDim.x * gridDim.x;

  int charsPerThread = (fileSize + stride - 1) / stride;
  int bitmapAlignedCharsPerThread = ((charsPerThread + 64 - 1) / 64) * 64;
  int start = index * bitmapAlignedCharsPerThread;
  int end = start + bitmapAlignedCharsPerThread;

  long string = 0;
  long bitmap = 0;

  for (int i = start; i < end && i < fileSize; i += 1) {
    long offsetInBlock = i % 64;
    if (offsetInBlock == 0) {
      string = stringIndex[i / 64];
      bitmap = 0;
    }

    if ((string & (1L << offsetInBlock)) != 0) {
      if (offsetInBlock == 63L) {
        structuralBitmap[i / 64] = bitmap;
      }
      continue;
    }

    char value = file[i];
    if (value == '{' || value == '}' || value == '[' || value == ']' || value == ':' || value == ',') {
      bitmap |= (1L << offsetInBlock);
    }

    if (offsetInBlock == 63L) {
      structuralBitmap[i / 64] = bitmap;
    }
  }

  if (fileSize <= end && fileSize > start && ((fileSize - 1) % 64) != 63L) {
    structuralBitmap[(fileSize - 1) / 64] = bitmap;
  }
}


extern "C" void gpjson_driver(char *file,
                             int fileSize,
                             char *escapeCarryIndex,
                             long *escapeIndex,
                             long *quoteAndStringIndex,
                             char *quoteCarryIndex,
                             char *xorBase,
                             long *structuralBitmap,
                             int levelSize,
                             int stringCarrySize,
                             int xorBaseSize) {
  gpjson_escape_carry(file, fileSize, escapeCarryIndex);
  gpjson_escape_index(file, fileSize, reinterpret_cast<bool *>(escapeCarryIndex), escapeIndex);
  gpjson_quote_index(file, fileSize, escapeIndex, quoteAndStringIndex, quoteCarryIndex);
  gpjson_xor_pre_scan(quoteCarryIndex, stringCarrySize);
  gpjson_xor_post_scan(quoteCarryIndex, stringCarrySize, xorBaseSize, xorBase);
  gpjson_xor_rebase(quoteCarryIndex, stringCarrySize, xorBase);
  gpjson_string_index(quoteAndStringIndex, levelSize, quoteCarryIndex);
  gpjson_structural_bitmap(file, fileSize, quoteAndStringIndex, structuralBitmap);
}
