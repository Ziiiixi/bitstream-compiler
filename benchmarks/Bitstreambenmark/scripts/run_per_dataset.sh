#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
BUILD_DIR=${BUILD_DIR:-$ROOT/build}
DATA_DIR=${DATA_DIR:-$ROOT/datasets/raw}
MANIFEST=${MANIFEST:-$ROOT/datasets/manifest.csv}
RUNS=${RUNS:-5}
VERIFY_DATASETS=${VERIFY_DATASETS:-1}
RUN_UPSTREAM_CUJSON=${RUN_UPSTREAM_CUJSON:-1}

required_binaries=(cujson_upstream_baseline cujson_bitgen_targeted_baseline cujson_bitgen_fused
    cujson_enumeration cujson_hierarchical_speculation cujson_speculation_no_validation
    gpjson_source_faithful_baseline gpjson_bitgen_targeted_baseline gpjson_bitgen_fused
    gpjson_enumeration gpjson_hierarchical_speculation gpjson_speculation_no_validation)
needs_build=0
for binary in "${required_binaries[@]}"; do [[ -x $BUILD_DIR/$binary ]] || needs_build=1; done
if [[ $needs_build == 1 ]]; then "$ROOT/scripts/build.sh"; fi
if [[ $VERIFY_DATASETS == 1 ]]; then
    DATA_DIR=$DATA_DIR MANIFEST=$MANIFEST "$ROOT/scripts/verify_datasets.sh"
fi

while IFS=, read -r dataset_id display_name filename format bytes sha256 source derivation; do
    [[ $dataset_id == dataset_id ]] && continue
    input=$DATA_DIR/$filename
    echo "[dataset] id=$dataset_id file=$input"

    if [[ $RUN_UPSTREAM_CUJSON == 1 ]]; then
        "$BUILD_DIR/cujson_upstream_baseline" -b "$input"
    fi
    for method in cujson_bitgen_targeted_baseline cujson_bitgen_fused cujson_enumeration \
                  cujson_hierarchical_speculation cujson_speculation_no_validation; do
        "$BUILD_DIR/$method" "$RUNS" "$input"
    done

    for method in gpjson_source_faithful_baseline gpjson_enumeration gpjson_hierarchical_speculation \
                  gpjson_speculation_no_validation; do
        "$BUILD_DIR/$method" "$input" "$RUNS"
    done
    "$BUILD_DIR/gpjson_bitgen_targeted_baseline" "$RUNS" "$input"
    "$BUILD_DIR/gpjson_bitgen_fused" "$RUNS" "$input"
done < "$MANIFEST"
