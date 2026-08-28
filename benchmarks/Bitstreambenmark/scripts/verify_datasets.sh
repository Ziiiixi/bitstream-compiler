#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
DATA_DIR=${DATA_DIR:-$ROOT/datasets/raw}
MANIFEST=${MANIFEST:-$ROOT/datasets/manifest.csv}

if command -v sha256sum >/dev/null 2>&1; then
    hash_file() { sha256sum "$1" | awk '{print $1}'; }
elif command -v shasum >/dev/null 2>&1; then
    hash_file() { shasum -a 256 "$1" | awk '{print $1}'; }
else
    echo "sha256sum or shasum is required" >&2
    exit 1
fi

status=0
while IFS=, read -r dataset display_name filename format bytes sha256 source derivation; do
    [[ $dataset == dataset_id ]] && continue
    path=$DATA_DIR/$filename
    if [[ ! -f $path ]]; then
        echo "MISSING $dataset $path"
        status=1
        continue
    fi
    actual_bytes=$(wc -c < "$path" | tr -d ' ')
    if [[ $actual_bytes != "$bytes" ]]; then
        echo "SIZE_MISMATCH $dataset expected=$bytes actual=$actual_bytes"
        status=1
        continue
    fi
    if [[ -n $sha256 && $sha256 != TBD ]]; then
        actual_sha256=$(hash_file "$path")
        if [[ $actual_sha256 != "$sha256" ]]; then
            echo "HASH_MISMATCH $dataset expected=$sha256 actual=$actual_sha256"
            status=1
            continue
        fi
    fi
    echo "PASS $dataset bytes=$actual_bytes"
done < "$MANIFEST"
exit "$status"
