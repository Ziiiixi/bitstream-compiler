# JSON GPU fusion-strategy artifact

This directory packages the CUDA code used to compare scheduling and fusion
strategies on the bitstream workloads.
For JSON parsing, It is intentionally limited to the tokenization/structural-bitmap stage; it is
not a complete JSON parser distribution.


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


## Layout

```text
cujson/                  cuJSON computation and UTF-validation workload
gpjson/                  GPJSON structural-bitmap workload
datasets/                dataset contract; large inputs are not committed
scripts/                 portable build and run scripts
results/                 placeholder for results generated after source freeze
```


## Quick start

```bash
GPU_ARCH=sm_86 ./scripts/build.sh
```

For the large inputs:

```bash
DATA_DIR=/path/to/datasets RUNS=5 ./scripts/run_per_dataset.sh
```

The one-CTA controls can also process all inputs in one launch:

```bash
DATA_DIR=/path/to/datasets RUNS=5 ./scripts/run_batch_controls.sh
```

The per-dataset runner executes all six retained controls. The per-thread
enumeration controls are intentionally slow on the large inputs.

Build products go to `build/` by default and are ignored by Git.


