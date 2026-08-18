# Bitstream Compiler

An MLIR research compiler for analyzing multi-kernel GPU bitstream programs.
Starting from CUDA/C++ lowered by Polygeist, it reconstructs byte-indexed
memory accesses, discovers cross-kernel dependencies, proves when an
unbounded dependency reduces to a finite state, and emits a speculative-fusion
legality descriptor.

> **Status:** research prototype. The current endpoint is fusion legality and
> a fused-kernel descriptor. It does not yet generate executable fused CUDA,
> validation/recovery kernels, or hierarchical speculation.

## Research question

Bitstream pipelines commonly split parsing or regular-expression work across
multiple GPU kernels. Fusing those kernels is straightforward when every
consumer needs a finite, statically known window of producer bytes. Prefix
scans and data-dependent predecessor walks are harder: the set of possible
producer locations grows with the logical position, even when the information
crossing the boundary is only a few bits.

This compiler separates four questions:

1. **Where does every stage read and write in bytes?**
2. **Does a consumer require a finite producer byte window?**
3. **If no finite window exists, can the dependency be projected to a finite
   state?**
4. **Do those facts make the complete pipeline legal to fuse?**

The analysis compares the recovered SSA indices directly. It does not create a
second textual access-summary language or infer legality from source variable
names.

## Pipeline

```text
prepared CUDA/C++ workload
        │
        │ Polygeist / cgeist
        ▼
01  Generic MLIR
        │ bitstream-recover-access-graph
        ▼
02  Conservative bitstream access-set IR
        │ bitstream-dependence-analysis
        ▼
03  RAW dependencies and finite byte-window witnesses
        │ bitstream-dependency-classification
        ▼
04  Bounded and unbounded presentation groups
        │ bitstream-finite-state-inference
        ▼
05  Explicit finite-state proofs
        │ bitstream-speculative-fusion
        ▼
06  Fusion-legality and fused-kernel descriptors
```

The numbered files are deliberately committed under `analysis/`. A reader can
inspect the compiler transformation step by step without first building LLVM,
MLIR, or Polygeist.

## A complete cuJSON example

The prepared cuJSON pipeline contains UTF validation, bitmap construction,
escaped-quote detection, a quote-prefix scan, in-string detection, and the
structural-bitmap endpoint.

For an ordinary pointwise dependency, a producer writes the same logical word
that a later stage reads. Dependence analysis records the exact half-open byte
window:

```mlir
bitstream.dependency memory = raw
  producer_access = "a8" consumer_access = "a12"
  finite_state = none
  producer_byte_window = affine_map<(d0) -> (d0 * 4, d0 * 4 + 4)>
```

The escaped-quote stage also walks backward through predecessor words. The
consumer address is the block argument of an `scf.while`, so there is no fixed
producer byte window:

```mlir
bitstream.dependency memory = raw
  producer_access = "a7" consumer_access = "a11"
  finite_state = none
```

Recovery preserves an exact domain-2 projection of that read. Finite-state
inference then changes only that concrete dependency:

```mlir
bitstream.dependency memory = raw
  producer_access = "a7" consumer_access = "a11"
  finite_state = proven finite_state_domain = 2
  {states = [@cujson_tokenizer_polygeist_raised::...::@state0]}
```

The quote scan-to-in-string edge is treated similarly: its index arithmetic is
regular, but a scan result incorporates an arbitrarily long prefix, so the edge
has no finite producer byte window. Its binary state projection makes the edge
fusible.

The final pass reports the whole seven-stage cuJSON region as legal because
every producer edge either has a finite byte window or an exact finite-state
proof. See:

- `analysis/cujson/02_bitstream_raised.mlir`
- `analysis/cujson/03_raw_dependencies.mlir`
- `analysis/cujson/05_finite_state_proof.mlir`
- `analysis/cujson/06_fusion_legality.mlir`

## Repository structure

```text
bitstream-compiler/
├── inputs/                         # Prepared CUDA/C++ examples
│   ├── cujson/cujson.cpp           # cuJSON tokenizer and UTF validation
│   ├── gpjson/gpjson.cpp           # gpJSON kernel pipeline
│   └── bitgen/
│       ├── bitgen.cpp              # Parseable one-regex driver
│       └── regex_0.cu              # One BitGen-generated regex body
│
├── mlir/bitstream/
│   ├── include/Bitstream/
│   │   ├── BitstreamDialect.td     # Dialect declaration
│   │   ├── BitstreamTypes.td       # Types
│   │   ├── BitstreamOps.td         # IR operation definitions
│   │   └── BitstreamPasses.td      # Pass names and registration metadata
│   │
│   ├── lib/Dialect/Bitstream/
│   │   ├── IR/                     # Dialect, type, and verifier code
│   │   └── Transforms/             # Compiler-pass implementations
│   │
│   ├── tools/bitstream-opt/
│   │   └── bitstream-opt.cpp       # Command-line compiler entry point
│   └── test/                       # MLIR unit and integration tests
│
├── scripts/run-direct-index.sh     # Reproducible end-to-end driver
├── analysis/{cujson,gpjson,bitgen} # Numbered pass-by-pass IR snapshots
└── THIRD_PARTY_NOTICES.md          # Workload provenance and licenses
```

Generated build trees and Lit output are intentionally excluded from version
control.

## Pass-to-code map

| Step | Command-line flag | C++ implementation | Output |
|---|---|---|---|
| Frontend | `cgeist` | Polygeist, external dependency | `01_generic_mlir.mlir` |
| Recover semantics | `--bitstream-recover-access-graph` | `Transforms/RecoverSemantics.cpp` | `02_bitstream_raised.mlir` |
| Discover dependencies | `--bitstream-dependence-analysis` | `Transforms/DependenceAnalysis.cpp` | `03_raw_dependencies.mlir` |
| Group dependencies | `--bitstream-dependency-classification` | `Transforms/DependencyClassification.cpp` | `04_classified_dependencies.mlir` |
| Prove finite state | `--bitstream-finite-state-inference` | `Transforms/FiniteStateInference.cpp` | `05_finite_state_proof.mlir` |
| Check fusion legality | `--bitstream-speculative-fusion` | `Transforms/SpeculativeFusion.cpp` | `06_fusion_legality.mlir` |

All implementation paths in the table are relative to
`mlir/bitstream/lib/Dialect/Bitstream/`.

### How a command-line pass reaches its implementation

```text
BitstreamPasses.td
  declares the flag and createBitstream...Pass() constructor
        │
        ▼
MLIR TableGen generates BitstreamPasses.h.inc
        │
        ▼
bitstream::registerPasses() exposes the command-line flag
        │
        ▼
bitstream-opt.cpp registers the passes and required dialects
        │
        ▼
MLIR constructs the pass and invokes runOnOperation()
        │
        ▼
Transforms/<Pass>.cpp performs the transformation
```

`bitstream-opt` registers the available passes; it does not hardcode their
order. `scripts/run-direct-index.sh` invokes them one at a time and saves the
IR after each step.

## Core IR contract

Each stage has a nameless `bitstream.logical_index`. Each real memory operation
contains its SSA index, byte width, byte-address map, and stable identity:

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

The physical interval is
`[byte_index(index), byte_index(index) + bytes)`. A dependency points directly
to the IDs of the real producer write and consumer read. There is no separate
`bitstream.access`, dimension, iteration-domain, extent, or footprint summary.

`producer_byte_window` is a two-result affine map describing the finite
half-open producer interval needed by a consumer. Its presence is the bounded
witness. Dependencies with a scan producer or loop-carried predecessor read
have no such map and appear in the unbounded group.

Every dependency also has an independent finite-state status:

- `finite_state = none`
- `finite_state = proven finite_state_domain = N`

`proven` requires a concrete `bitstream.project_state` linked to the same
consumer `access_id`, buffer, SSA address, and finite domain. A projection on
one read cannot legalize another read of the same buffer.

More detailed operation contracts are documented in
`mlir/bitstream/README.md`.

## Assumptions and safety boundary

- Kernel stages are modeled as parallel loops over an explicit logical
  coordinate recovered from source SSA provenance.
- Regular addresses must be expressible with the supported affine arithmetic.
  The compiler never treats a variable as logical merely because it is named
  `i`, `j`, `k`, or `index`.
- `02_bitstream_raised.mlir` is conservative access-analysis IR, not executable
  replacement code. Reconstructed loops over-approximate possible addresses.
- A finite byte-window witness establishes ordinary local fusion legality.
  An edge without a finite window requires an exact finite-state proof.
- The current compiler does not prove arbitrary transducer associativity. It
  preserves and verifies the concrete projected state used for validation.
- The endpoint is a legality descriptor, not final CUDA code generation.

## Workloads and current trace results

| Workload | Dependency edges | Dependency finite-state proofs | Final result |
|---|---:|---:|---|
| cuJSON tokenizer | 14 | 2 | legal speculative-fusion descriptor |
| gpJSON | 13 | 1 bounded descriptive proof | legal finite-window descriptor |
| BitGen regex example | 27 | 0 dependency proofs | legal regex-state descriptor |

These counts describe the committed prepared inputs and should be regenerated
when the compiler or inputs change.

## Build and run

### Prerequisites

- LLVM/MLIR compatible with the checked-out Polygeist build
- Polygeist with `cgeist`
- CMake and Ninja
- A C++17 compiler

Set `POLYGEIST_ROOT` to the Polygeist checkout used for the build:

```bash
git clone <this-repository-url> bitstream-compiler
cd bitstream-compiler

export POLYGEIST_ROOT=/path/to/Polygeist

cmake -S mlir/bitstream -B build-bitstream-mlir \
  -DMLIR_DIR="${POLYGEIST_ROOT}/build-release/lib/cmake/mlir"
ninja -C build-bitstream-mlir bitstream-opt
```

Run one prepared workload into a new output directory:

```bash
bash scripts/run-direct-index.sh cujson /tmp/bitstream-cujson-run
bash scripts/run-direct-index.sh gpjson /tmp/bitstream-gpjson-run
bash scripts/run-direct-index.sh bitgen /tmp/bitstream-bitgen-run
```

The output directory must not already exist so that a previous compiler trace
cannot be overwritten accidentally.

### Tests

```bash
ninja -C build-bitstream-mlir check-bitstream
bash mlir/bitstream/test/run_smoke_tests.sh
```

## Relationship to related systems

- **BitGen** compiles specialized bitstream/regex programs into GPU kernels.
- **MPK** constructs and schedules mega-kernels for tensor programs.
- **This project** starts from existing CUDA/C++ kernel pipelines and asks
  whether their recovered cross-kernel memory dependencies permit ordinary or
  finite-state speculative fusion.

The project is therefore currently a dependence-and-legality compiler, not a
replacement for the complete BitGen backend or MPK runtime.

## Licensing and provenance

No project-wide license has been selected yet. The prepared workload inputs
come from or are adapted from third-party research systems with different
licensing status. See `THIRD_PARTY_NOTICES.md` before redistributing the
repository. In particular, the retained BitGen-generated CUDA body should not
be published in a public repository until its redistribution terms are
confirmed or it is replaced by an independently written example.
