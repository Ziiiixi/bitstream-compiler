#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
NVCC=${NVCC:-nvcc}
GPU_ARCH=${GPU_ARCH:-sm_86}
BUILD_DIR=${BUILD_DIR:-$ROOT/build}
COMMON_FLAGS=(-O3 -std=c++17 -arch="$GPU_ARCH")

if ! command -v "$NVCC" >/dev/null 2>&1; then
    if [[ -x /usr/local/cuda/bin/nvcc ]]; then NVCC=/usr/local/cuda/bin/nvcc
    else echo "nvcc not found; set NVCC=/path/to/nvcc" >&2; exit 1
    fi
fi

mkdir -p "$BUILD_DIR"

compile() {
    local source=$1 output=$2 include_dir=$3
    echo "[build] $output"
    "$NVCC" "${COMMON_FLAGS[@]}" -I"$include_dir" "$source" -o "$BUILD_DIR/$output"
}

CUJSON=$ROOT/cujson
compile "$CUJSON/src/bitgen_targeted_baseline.cu" cujson_bitgen_targeted_baseline "$CUJSON/include"
compile "$CUJSON/src/bitgen_fused.cu" cujson_bitgen_fused "$CUJSON/include"
compile "$CUJSON/src/enumeration.cu" cujson_enumeration "$CUJSON/include"
compile "$CUJSON/src/hierarchical_speculation.cu" cujson_hierarchical_speculation "$CUJSON/include"
compile "$CUJSON/src/speculation_no_validation.cu" cujson_speculation_no_validation "$CUJSON/include"
echo "[build] cujson_upstream_baseline"
"$NVCC" "${COMMON_FLAGS[@]}" -w -DCUJSON_STRUCTURAL_BITMAP_TIMER \
    "$CUJSON/upstream/cuJSON-standardjson.cu" -o "$BUILD_DIR/cujson_upstream_baseline"

GPJSON=$ROOT/gpjson
compile "$GPJSON/src/source_faithful_baseline.cu" gpjson_source_faithful_baseline "$GPJSON/include"
compile "$GPJSON/src/bitgen_targeted_baseline.cu" gpjson_bitgen_targeted_baseline "$GPJSON/include"
compile "$GPJSON/src/bitgen_fused.cu" gpjson_bitgen_fused "$GPJSON/include"
compile "$GPJSON/src/enumeration.cu" gpjson_enumeration "$GPJSON/include"
compile "$GPJSON/src/hierarchical_speculation.cu" gpjson_hierarchical_speculation "$GPJSON/include"
compile "$GPJSON/src/speculation_no_validation.cu" gpjson_speculation_no_validation "$GPJSON/include"

echo "[build] complete: $BUILD_DIR"
