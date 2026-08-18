#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workload="${1:?usage: scripts/run-direct-index.sh <gpjson|cujson|bitgen> [out_dir]}"

case "${workload}" in
  gpjson)
    input_cpp="${repo_root}/inputs/gpjson/gpjson.cpp"
    entry_function="gpjson_driver"
    ;;
  cujson)
    input_cpp="${repo_root}/inputs/cujson/cujson.cpp"
    entry_function="cujson_tokenizer"
    recovery_driver="cujson_tokenizer"
    ;;
  bitgen)
    input_cpp="${repo_root}/inputs/bitgen/bitgen.cpp"
    entry_function="bitgen_driver"
    ;;
  *)
    echo "unknown workload: ${workload}; expected gpjson, cujson, or bitgen" >&2
    exit 2
    ;;
esac

recovery_driver="${recovery_driver:-}"

out_dir="${2:-${repo_root}/analysis/${workload}}"
polygeist_root="${POLYGEIST_ROOT:?set POLYGEIST_ROOT to the Polygeist checkout}"
polygeist="${CGEIST:-${polygeist_root}/build-release/bin/cgeist}"
bitstream_opt="${repo_root}/build-bitstream-mlir/tools/bitstream-opt/bitstream-opt"

if [[ ! -f "${input_cpp}" ]]; then
  echo "missing prepared input: ${input_cpp}" >&2
  exit 2
fi
if [[ ! -x "${polygeist}" ]]; then
  echo "missing Polygeist executable: ${polygeist}" >&2
  exit 2
fi
if [[ ! -x "${bitstream_opt}" ]]; then
  echo "build bitstream-opt first: ninja -C build-bitstream-mlir bitstream-opt" >&2
  exit 2
fi
if [[ -e "${out_dir}" ]]; then
  echo "output directory already exists: ${out_dir}" >&2
  exit 2
fi

mkdir -p "${out_dir}"

"${polygeist}" -x c++ "${input_cpp}" -S \
  "--function=${entry_function}" -std=c++17 --canonicalizeiters=0 \
  -o "${out_dir}/01_generic_mlir.mlir"

if [[ -n "${recovery_driver}" ]]; then
  env BITSTREAM_POLYGEIST_DRIVER="${recovery_driver}" \
    "${bitstream_opt}" "${out_dir}/01_generic_mlir.mlir" \
    --allow-unregistered-dialect --bitstream-recover-access-graph \
    -o "${out_dir}/02_bitstream_raised.mlir"
else
  "${bitstream_opt}" "${out_dir}/01_generic_mlir.mlir" \
    --allow-unregistered-dialect --bitstream-recover-access-graph \
    -o "${out_dir}/02_bitstream_raised.mlir"
fi
"${bitstream_opt}" "${out_dir}/02_bitstream_raised.mlir" --allow-unregistered-dialect \
  --bitstream-dependence-analysis -o "${out_dir}/03_raw_dependencies.mlir"
"${bitstream_opt}" "${out_dir}/03_raw_dependencies.mlir" --allow-unregistered-dialect \
  --bitstream-dependency-classification -o "${out_dir}/04_classified_dependencies.mlir"
"${bitstream_opt}" "${out_dir}/04_classified_dependencies.mlir" --allow-unregistered-dialect \
  --bitstream-finite-state-inference -o "${out_dir}/05_finite_state_proof.mlir"
"${bitstream_opt}" "${out_dir}/05_finite_state_proof.mlir" --allow-unregistered-dialect \
  --bitstream-speculative-fusion -o "${out_dir}/06_fusion_legality.mlir"

grep "bitstream.fusion_candidate" "${out_dir}/06_fusion_legality.mlir"
