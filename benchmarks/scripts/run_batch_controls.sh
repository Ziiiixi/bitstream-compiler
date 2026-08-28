#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
BUILD_DIR=${BUILD_DIR:-$ROOT/build}
DATA_DIR=${DATA_DIR:-$ROOT/datasets/raw}
MANIFEST=${MANIFEST:-$ROOT/datasets/manifest.csv}
RUNS=${RUNS:-5}

required_binaries=(cujson_bitgen_targeted_baseline cujson_bitgen_fused
    gpjson_bitgen_targeted_baseline gpjson_bitgen_fused)
needs_build=0
for binary in "${required_binaries[@]}"; do [[ -x $BUILD_DIR/$binary ]] || needs_build=1; done
if [[ $needs_build == 1 ]]; then "$ROOT/scripts/build.sh"; fi

inputs=()
while IFS=, read -r dataset_id display_name filename format bytes sha256 source derivation; do
    [[ $dataset_id == dataset_id ]] && continue
    inputs+=("$DATA_DIR/$filename")
done < "$MANIFEST"

echo "[batch] inputs=${#inputs[@]} runs=$RUNS"
"$BUILD_DIR/cujson_bitgen_targeted_baseline" "$RUNS" "${inputs[@]}"
"$BUILD_DIR/cujson_bitgen_fused" "$RUNS" "${inputs[@]}"
"$BUILD_DIR/gpjson_bitgen_targeted_baseline" "$RUNS" "${inputs[@]}"
"$BUILD_DIR/gpjson_bitgen_fused" "$RUNS" "${inputs[@]}"
