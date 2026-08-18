# Direct-Index Bitstream MLIR

This directory contains the dialect and C++ passes used by the isolated
direct-index compiler. The runner writes the current trace in this order:

| File | Producer | Contents |
|---|---|---|
| `01_generic_mlir.mlir` | Polygeist frontend | Generic MLIR for the prepared C++/CUDA input. |
| `02_bitstream_raised.mlir` | `bitstream-recover-access-graph` | Conservative, non-executable access-set IR with stages, parameters, control flow, and real reads/writes. |
| `03_raw_dependencies.mlir` | `bitstream-dependence-analysis` | RAW edges referring to producer and consumer operations by `access_id`. |
| `04_classified_dependencies.mlir` | `bitstream-dependency-classification` | Edges grouped as bounded or unbounded. |
| `05_finite_state_proof.mlir` | `bitstream-finite-state-inference` | Explicit `none` or exact finite-state proofs for every dependency; the proof itself is sufficient for fusion legality. |
| `06_fusion_legality.mlir` | `bitstream-speculative-fusion` | Legal or illegal fusion descriptors. |

## Core IR contract

Every stage owns a nameless `bitstream.logical_index`. A read or write uses an
ordinary SSA index, a byte width, and a unique `access_id`; an optional
`byte_index` affine map overrides the default `index * bytes` address rule. For
example:

```mlir
%logical = bitstream.logical_index : index
%c1 = arith.constant 1 : index
%previous = arith.subi %logical, %c1 : index
bitstream.read %buffer[%previous] {
  access_id = "a1",
  byte_index = affine_map<(d0) -> (d0 * 4)>,
  bytes = 4 : i64
} : !bitstream.buffer
```

Dependence analysis composes the SSA expression with `byte_index` and compares
physical byte intervals. A dependency points directly at a producer write ID
and consumer read ID. There is no parallel `bitstream.access` summary and no
textual domain, dimension, footprint, extent, or source-variable identity.

Each dependency carries `memory = input | raw`. A RAW edge names both concrete
operations through `producer_access` and `consumer_access`; an input edge names
its consumer. There is no separate boundedness attribute.

An ordinary dependency requires a two-result `producer_byte_window` map, which
is itself the witness that the producer footprint is finite:

```mlir
bitstream.dependency memory = raw
  producer_access = "a0" consumer_access = "a1"
  finite_state = none
  producer_byte_window = affine_map<(d0) -> (d0 * 4, d0 * 4 + 4)>
  {buffer = @pipeline::@buffer,
   producer = @pipeline::@producer,
   consumer = @pipeline::@consumer}
```

The map is over the consumer read's existing access-index operand and denotes
the half-open physical-byte interval `[first, end)`. The read's SSA index and
its own `byte_index` map retain the details of a same-index access, fixed
offset, neighbor, or mixed-width repack. The dependency does not duplicate
those facts as point, affine, offset, repack, or overlap labels. An unbounded
dependency must not carry a byte-window map.

The classification pass places dependencies in `bounded` or `unbounded`
groups. This is a presentation view derived from the byte-window witness and
source structure, not another dependency attribute.

Every dependency has a required, orthogonal proof status:

```mlir
finite_state = none
```

or, when exact projection evidence exists:

```mlir
finite_state = proven finite_state_domain = 2
{states = [@pipeline::@stage::@state0]}
```

`proven` requires a matching `project_state`, a positive domain, and state
references with that same domain. A bounded edge may carry this information,
but its byte window already establishes ordinary fusion legality. An unbounded
producer edge requires the exact proof.

Logical-index provenance is structural. A variable named `i`, `k`, or `index`
is an ordinary unresolved value unless its source SSA is the selected stage
coordinate. Conversely, a CUDA coordinate with any source name becomes the
logical index.

When recovery traces a source SSA value to an argument of the selected driver,
it materializes one pipeline-scoped `bitstream.parameter`. Stages receiving the
same source argument capture that same SSA result; separate parameter operations
remain distinct regardless of spelling. The operation makes input provenance
explicit without treating a parameter as a logical iteration dimension or an
extent.

Any remaining stage-region arguments printed as `%arg0`, `%arg1`, and so on are
opaque local scalar operands retained conservatively for address expressions.
Unlike `bitstream.parameter`, they carry no recovered source-parameter identity.
Their numbers are local SSA-printer names, not source CUDA argument numbers, and
they have no cross-stage identity. An address using one remains unknown unless
its SSA provenance connects it to `bitstream.logical_index` or another explicit
IR value.

## Conservative control-flow recovery

The raised file is conservative access-analysis IR, not executable program IR.
In the cuJSON predecessor walk, `scf.while` exposes the loop-carried address and
the dependence pass sees that its producer set is not statically bounded. The
reconstructed loop intentionally over-approximates the original access set and
omits the full value computation and early termination, while retaining the
minimal domain-2 projection derived from the source `~value`, `ctlz`, and
low-bit SSA slice. That dependency has no byte-window map; this describes its
growing producer set, not an infinite source execution. A scan-to-consumer
dependency also has no window because a scan result incorporates a growing
prefix. Later passes distinguish these causes structurally from the
loop-carried read and the `bitstream.scan` producer, not from a dependency-kind
label.

Later legality can use an explicit minimal projection:

```mlir
bitstream.project_state %buffer[%address] {
  domain = 2 : i64,
  read_access = "a1",
  projection_kind = "low_bit",
  modulus = 2 : i64
} : !bitstream.buffer
```

The buffer, matching SSA address, and finite `domain` are the core facts;
`read_access` links the projection to the real read, while `projection_kind`,
`modulus`, or `projected_bits` may refine it. There is no duplicate access range,
source-variable identity, stage extent, or predecessor-walk tag on this
operation.

The projection proves only the dependency whose `consumer_access` equals its
`read_access` and whose buffer and SSA address match. Finite-state inference
records a proof for either bounded or unbounded RAW edges when that exact
evidence exists. A bounded proof is descriptive and does not alter its fusion
strategy; an unbounded proof is required for speculative fusion.

Finite-state inference proves the escaped-quote predecessor edge and the quote
scan-to-in-string edge independently by attaching exact state references and a
finite domain. Fusion legality consumes those proofs directly; no separate
dependency-reduction marker is required.

## Passes

- `bitstream-recover-access-graph` builds the conservative access-set IR.
- `bitstream-dependence-analysis` creates direct ID-to-ID dependencies and
  attaches an explicit byte-window witness whenever the producer set is
  finite.
- `bitstream-dependency-classification` groups dependencies by whether they
  carry a finite byte-window witness.
- `bitstream-finite-state-inference` writes `none` or proves an exact projected
  finite domain for each dependency.
- `bitstream-speculative-fusion` checks that every producer edge has either a
  finite byte window or an exact finite-state proof, then emits the terminal
  legality and fused-kernel descriptors. It does not select a library kernel.

## Build and test

```bash
export POLYGEIST_ROOT=/path/to/Polygeist
cmake -S mlir/bitstream -B build-bitstream-mlir \
  -DMLIR_DIR="${POLYGEIST_ROOT}/build-release/lib/cmake/mlir"
ninja -C build-bitstream-mlir bitstream-opt
bash mlir/bitstream/test/run_smoke_tests.sh
ninja -C build-bitstream-mlir check-bitstream
```

The full compiler runner is documented in the repository-level `README.md`.
