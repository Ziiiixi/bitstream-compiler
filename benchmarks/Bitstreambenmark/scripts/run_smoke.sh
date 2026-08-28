#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
BUILD_DIR=${BUILD_DIR:-$ROOT/build}
INPUT=${1:-$ROOT/tests/data/smoke.json}
RUNS=${RUNS:-1}
RUN_UPSTREAM=${RUN_UPSTREAM:-1}

core_binaries=(cujson_bitgen_targeted_baseline cujson_bitgen_fused cujson_enumeration
    cujson_hierarchical_speculation cujson_speculation_no_validation
    gpjson_source_faithful_baseline gpjson_bitgen_targeted_baseline gpjson_bitgen_fused
    gpjson_enumeration gpjson_hierarchical_speculation gpjson_speculation_no_validation)
if [[ $RUN_UPSTREAM == 1 ]]; then core_binaries+=(cujson_upstream_baseline); fi
needs_build=0
for binary in "${core_binaries[@]}"; do [[ -x $BUILD_DIR/$binary ]] || needs_build=1; done
if [[ $needs_build == 1 ]]; then "$ROOT/scripts/build.sh"; fi

echo "[smoke] input=$INPUT runs=$RUNS"
if [[ $RUN_UPSTREAM == 1 ]]; then
    "$BUILD_DIR/cujson_upstream_baseline" -b "$INPUT"
fi

for method in cujson_bitgen_targeted_baseline cujson_bitgen_fused cujson_enumeration \
              cujson_hierarchical_speculation cujson_speculation_no_validation; do
    "$BUILD_DIR/$method" "$RUNS" "$INPUT"
done

for method in gpjson_source_faithful_baseline gpjson_enumeration gpjson_hierarchical_speculation \
              gpjson_speculation_no_validation; do
    "$BUILD_DIR/$method" "$INPUT" "$RUNS"
done
"$BUILD_DIR/gpjson_bitgen_targeted_baseline" "$RUNS" "$INPUT"
"$BUILD_DIR/gpjson_bitgen_fused" "$RUNS" "$INPUT"

echo "[smoke] complete"
