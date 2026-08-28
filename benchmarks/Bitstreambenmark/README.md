# JSON GPU fusion-strategy artifact

This directory packages the CUDA code used to compare scheduling and fusion
strategies on two structural-bitmap workloads derived from cuJSON and GPJSON.
It is intentionally limited to the tokenization/structural-bitmap stage; it is
not a complete JSON parser distribution.

This is the cleaned, self-contained benchmark tree. Generated build products,
datasets, and historical result bundles are not included.

## Compared methods

Both workloads retain the same six conceptual controls:

| Method | Purpose | Correctness |
|---|---|---|
| Upstream/source-faithful baseline | Original multi-stage pipeline | Correct |
| BitGen-targeted baseline | Stage-major execution with one CTA per input | Correct |
| BitGen-style fused | Tile-major fusion with intermediates retained on chip | Correct |
| Per-thread enumeration | Enumerate states, then resolve them through global-memory readiness | Correct, experimental scheduling caveat |
| Hierarchical speculation | Speculate, validate, compact true misses, and recover sparsely | Correct |
| Speculation without validation | Optimistic runtime lower bound (performance upper bound) | Intentionally incorrect |

`benchmarks/*/experimental/` additionally retains the hierarchical-enumeration
work: both boundary states are represented before validation and the resolved
state selects a result, so there is no recovery replay.

“BitGen-targeted” and “BitGen-style” name the execution organization being
studied. These binaries are experimental controls, not the official BitGen
implementation.

## Layout

```text
benchmarks/cujson/       cuJSON computation and UTF-validation workload
benchmarks/gpjson/       GPJSON structural-bitmap workload
datasets/                dataset contract; large inputs are not committed
scripts/                 portable build, verification, and run scripts
tests/data/              small correctness fixture
results/                 placeholder for results generated after source freeze
licenses/                third-party license text where available
```

## Requirements

- Linux x86-64
- NVIDIA GPU and driver
- CUDA Toolkit with C++17 support (tested with CUDA 12.9)
- A GPU supporting `cuda::atomic_ref`; the reference machine used an RTX A4000
  (`sm_86`)
- Cooperative-kernel launch support for the cuJSON per-thread enumeration
  control
- Bash, `awk`, and `sha256sum` for the reproduction scripts

The seven-input batch requires substantially more GPU memory than a single
input: approximately 10.34 GiB for the GPJSON targeted baseline and 8.46 GiB
for GPJSON fused.

## Quick start

```bash
GPU_ARCH=sm_86 ./scripts/build.sh
CUDA_VISIBLE_DEVICES=0 RUNS=1 ./scripts/run_smoke.sh
```

For the large inputs:

```bash
DATA_DIR=/path/to/datasets ./scripts/verify_datasets.sh
DATA_DIR=/path/to/datasets RUNS=5 ./scripts/run_per_dataset.sh
```

The one-CTA controls can also process all inputs in one launch:

```bash
DATA_DIR=/path/to/datasets RUNS=5 ./scripts/run_batch_controls.sh
```

The per-dataset runner executes all six retained controls. The per-thread
enumeration controls are intentionally slow on the large inputs.

Build products go to `build/` by default and are ignored by Git.

## Timing and correctness

Every experimental executable performs CUDA-event timing around GPU work and
prints an output checksum or an independent CPU-reference comparison. The
upstream cuJSON timer has its original fixed five warmups and ten measured
runs. Other binaries accept a run count; see the workload READMEs for their
different command-line contracts.

Do not combine per-dataset sequential numbers with the concurrent multi-input
batch numbers. The scheduling policy is part of each experiment.

## Important limitations

- The no-validation binaries are intentionally incorrect and are only an
  optimistic performance bound.
- GPJSON's retained carry rule assumes that a complete logical segment is not
  made entirely of backslashes. The seven retained datasets satisfy this.
- The literal per-thread enumeration control can theoretically wait for an
  unscheduled predecessor block; CUDA does not promise increasing block order.
- Dataset files are not redistributed here. Verify their source and
  redistribution terms separately.

## Provenance and licensing

Read [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) before publishing. cuJSON
is retained under the MIT license and GPJSON-derived material under the
Universal Permissive License 1.0. Both pinned revisions and complete notices
are recorded in the artifact.
The papers motivating and defining the workloads are listed in
[REFERENCES.md](REFERENCES.md).
