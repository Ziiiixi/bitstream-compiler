# GPU bitstream benchmark suite

This directory packages CUDA bitstream workloads. The cuJSON and GPJSON
directories compare scheduling and fusion strategies for structural-bitmap
stages. CSV, XML, and FASTQ contain baseline-only staged CUDA workloads, while
regex points to the official BitGen implementation.

The JSON workloads stop at tokenization/structural bitmaps and are not complete
parser distributions.

## JSON compared methods

The cuJSON and GPJSON workloads retain the same six conceptual controls. They
are intentionally limited to the tokenization/structural-bitmap stage and are
not complete JSON parser distributions.

| Method | Purpose | Correctness |
|---|---|---|
| Upstream/source-faithful baseline | Original multi-stage pipeline | Correct |
| BitGen-targeted baseline | Stage-major execution with one CTA per input | Correct |
| BitGen-style fused | Tile-major fusion with intermediates retained on chip | Correct |
| Per-thread enumeration | Enumerate states, then resolve them through global-memory readiness | Correct, experimental scheduling caveat |
| Hierarchical speculation | Speculate, validate, compact true misses, and recover sparsely | Correct |
| Speculation without validation | Optimistic runtime lower bound (performance upper bound) | Intentionally incorrect |


## Baseline-only workloads

CSV, XML, and FASTQ are standalone staged CUDA baselines for reduced state
problems corresponding to public applications. Each retains materialized
intermediate bitstreams, chunk summaries, global state propagation, final
output or count, CUDA-event timing, and an independent CPU correctness check.
These directories contain no fused, speculative, recovery, or other proposed
method.

They are not copied source modules. Their READMEs pin the closest public code,
name the corresponding functions, and state exactly what was simplified:

| Workload | Public code anchor | Relationship of this baseline |
|---|---|---|
| CSV | [cuDF v26.06.01 CSV reader](https://github.com/NVIDIA/cudf/tree/v26.06.01/cpp/src/io/csv) | Isolates binary quote-context propagation and outside-quote delimiter recognition; cuDF's row-context algorithm is richer. |
| XML | [Parabix XML Pablo pipeline](https://github.com/parabix/parabix-devel-mirror/blob/6ff6d71e0df3906e94f14dc0f14125fdf98e1025/tools/xml/xml.pablo) | Uses the same six lexical classes and reduced quote-aware tag states; the public implementation is CPU/Pablo, not CUDA. |
| FASTQ | [FASTR chunk/parser code](https://github.com/ALSER-Lab/FASTR/tree/37f2fffaef72e62326cdca45cc84d80d02b82763/src) | Isolates the canonical four-line record phase; it omits FASTR conversion and its more general parser. |
| Regex | [official BitGen](https://github.com/getianao/BitGen/tree/de7b7db0f385e21c5e6a5e2767f4264da890f9b0) | Unmodified official source, pinned as a submodule. |

The regex workload is different: `regex/bitgen` is the official, unmodified
BitGen repository pinned as a Git submodule. It is not one of the independent
“BitGen-style” controls in the JSON directories.

## Layout

```text
cujson/                  cuJSON computation and UTF-validation workload
gpjson/                  GPJSON structural-bitmap workload
csv/                     staged CSV quote-context baseline only
xml/                     staged XML lexical-state baseline only
fastq/                   staged FASTQ line-phase baseline only
regex/                   official pinned BitGen regex submodule and runner
datasets/                dataset contract; large inputs are not committed
scripts/                 portable build and run scripts
results/                 placeholder for results generated after source freeze
```


## CUDA benchmark build

```bash
GPU_ARCH=sm_86 ./scripts/build.sh
```

This builds the cuJSON and GPJSON controls plus the standalone CSV, XML, and
FASTQ baselines. BitGen has its own official build flow under `regex/`.

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

The standalone CSV, XML, and FASTQ baselines and the official BitGen workload
have workload-specific build and run commands in their own READMEs. Initialize
the regex source with:

```bash
git submodule update --init --recursive benchmarks/regex/bitgen
```
