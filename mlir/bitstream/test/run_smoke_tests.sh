#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project_root="$(cd "${repo_root}/../.." && pwd)"
opt="${project_root}/build-bitstream-mlir/tools/bitstream-opt/bitstream-opt"

polygeist_root="${POLYGEIST_ROOT:?set POLYGEIST_ROOT to the Polygeist checkout}"
export LD_LIBRARY_PATH="${polygeist_root}/x86_64-linux-gnu:${polygeist_root}/build-release/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

if [[ ! -x "${opt}" ]]; then
  echo "bitstream-opt is not built: ${opt}" >&2
  exit 1
fi

recover_output="$("${opt}" "${repo_root}/test/recover_access_graph.mlir" \
  -bitstream-recover-access-graph 2>&1)"
grep -Eq "bitstream\\.buffer @input" <<<"${recover_output}"

dependence_output="$("${opt}" "${repo_root}/test/dependence_analysis.mlir" \
  -bitstream-dependence-analysis -bitstream-dependency-classification)"
grep -q "producer = @toy_bounded_neighbor::@producer" <<<"${dependence_output}"
grep -q 'access_id = "a0"' <<<"${dependence_output}"
grep -q 'affine_map<(d0) -> (d0 \* 4, d0 \* 4 + 4)>' <<<"${dependence_output}"
grep -Eq 'bitstream\.dependency .*producer_byte_window = #[a-zA-Z0-9_]+' <<<"${dependence_output}"
grep -q 'bitstream.dependency_group kind = "bounded"' <<<"${dependence_output}"
grep -q 'bitstream.dependency_group kind = "unbounded"' <<<"${dependence_output}"
grep -Eq 'bitstream\.dependency memory = raw producer_access = "a2" consumer_access = "a3" finite_state = none \{' <<<"${dependence_output}"

structured_output="$("${opt}" "${repo_root}/test/recover_structured_coordinates.mlir" \
  -bitstream-recover-access-graph)"
grep -q "bitstream.pipeline @driver_polygeist_raised" <<<"${structured_output}"
grep -q "arith.divsi" <<<"${structured_output}"
grep -q "arith.remsi" <<<"${structured_output}"
grep -q "scf.while" <<<"${structured_output}"

canonicalize_output="$("${opt}" "${repo_root}/test/canonicalize.mlir" \
  -canonicalize)"
grep -q "bitstream.write" <<<"${canonicalize_output}"

echo "bitstream smoke tests passed"
