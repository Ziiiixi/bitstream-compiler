#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
BITGEN_ROOT=$ROOT/bitgen

if [[ ! -f $BITGEN_ROOT/scripts/run_config.py ]]; then
    echo "BitGen submodule is missing; run: git submodule update --init --recursive benchmarks/regex/bitgen" >&2
    exit 1
fi

source "$BITGEN_ROOT/env.sh"
python -u "$BITGEN_ROOT/scripts/run_config.py" \
    --app="$BITGEN_ROOT/configs/app/full/app_full.yaml" \
    --exec="$ROOT/configs/exec_bitgen_vs_base.yaml" \
    --options=""
