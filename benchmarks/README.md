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

They are not copied source modules. The table pins the closest public code,
names the corresponding functions, and states exactly what was simplified.

## Public source correspondence

| Workload | Public project and revision | Corresponding public code | Relationship of this benchmark |
|---|---|---|---|
| cuJSON | [AutomataLab/cuJSON](https://github.com/AutomataLab/cuJSON/tree/2ac7d3dcd7ad1ff64ebdb14022bf94c59b3b4953), commit `2ac7d3dc` | [`paper_reproduced/src/cuJSON-standardjson.cu`](https://github.com/AutomataLab/cuJSON/blob/2ac7d3dcd7ad1ff64ebdb14022bf94c59b3b4953/paper_reproduced/src/cuJSON-standardjson.cu) | `cujson/upstream/cuJSON-standardjson.cu` retains the upstream tokenizer and differs only by timing code guarded by `CUJSON_STRUCTURAL_BITMAP_TIMER`; measurement stops after structural and filtered open/close bitmaps. |
| GPJSON | [gpjson-vldb/gpjson](https://github.com/gpjson-vldb/gpjson/tree/c912c1f1564c8bd750765b0650f59b56d334ce71), commit `c912c1f1` | [`combined-escape-carry-newline-count-index.cu`](https://github.com/gpjson-vldb/gpjson/blob/c912c1f1564c8bd750765b0650f59b56d334ce71/language/src/main/resources/it/necst/gpjson/kernels/combined-escape-carry-newline-count-index.cu); [`quote-index.cu`](https://github.com/gpjson-vldb/gpjson/blob/c912c1f1564c8bd750765b0650f59b56d334ce71/language/src/main/resources/it/necst/gpjson/kernels/quote-index.cu); [`xor-pre-scan.cu`](https://github.com/gpjson-vldb/gpjson/blob/c912c1f1564c8bd750765b0650f59b56d334ce71/language/src/main/resources/it/necst/gpjson/kernels/xor-pre-scan.cu), [`xor-post-scan.cu`](https://github.com/gpjson-vldb/gpjson/blob/c912c1f1564c8bd750765b0650f59b56d334ce71/language/src/main/resources/it/necst/gpjson/kernels/xor-post-scan.cu), and [`xor-rebase.cu`](https://github.com/gpjson-vldb/gpjson/blob/c912c1f1564c8bd750765b0650f59b56d334ce71/language/src/main/resources/it/necst/gpjson/kernels/xor-rebase.cu); [`string-index.cu`](https://github.com/gpjson-vldb/gpjson/blob/c912c1f1564c8bd750765b0650f59b56d334ce71/language/src/main/resources/it/necst/gpjson/kernels/string-index.cu) | The packaged baseline retains the structural-bitmap stages, fixed launch geometry, escape state, and three-kernel quote-parity scan; later newline and nesting/index construction is outside this benchmark. |
| CSV | [NVIDIA/cuDF v26.06.01](https://github.com/NVIDIA/cudf/tree/v26.06.01), commit [`77ced62c`](https://github.com/NVIDIA/cudf/commit/77ced62cd91993510ea4a83c611caed64a319d1c) | [`csv_gpu.hpp`: row contexts and block summaries](https://github.com/NVIDIA/cudf/blob/77ced62cd91993510ea4a83c611caed64a319d1c/cpp/src/io/csv/csv_gpu.hpp#L22-L152); [`gather_row_offsets_gpu`](https://github.com/NVIDIA/cudf/blob/77ced62cd91993510ea4a83c611caed64a319d1c/cpp/src/io/csv/csv_gpu.cu#L626-L800); [two-pass orchestration](https://github.com/NVIDIA/cudf/blob/77ced62cd91993510ea4a83c611caed64a319d1c/cpp/src/io/csv/reader_impl.cu#L275-L365); [`seek_field_end`](https://github.com/NVIDIA/cudf/blob/77ced62cd91993510ea4a83c611caed64a319d1c/cpp/src/io/utilities/parsing_utils.cuh#L203-L262) | Independently isolates binary quote-context propagation and outside-quote comma recognition. cuDF instead uses richer multi-context row maps, custom block composition, host prefix resolution, and row-offset emission; there is no exact public cuDF counterpart to this CUB-based CUDA program. |
| XML | [Parabix development mirror](https://github.com/parabix/parabix-devel-mirror/tree/6ff6d71e0df3906e94f14dc0f14125fdf98e1025), commit `6ff6d71e` | [`Lex` and `ClassifyBytesValidateUtf8`](https://github.com/parabix/parabix-devel-mirror/blob/6ff6d71e0df3906e94f14dc0f14125fdf98e1025/tools/xml/xml.pablo#L29-L109); [`Preprocess`](https://github.com/parabix/parabix-devel-mirror/blob/6ff6d71e0df3906e94f14dc0f14125fdf98e1025/tools/xml/xml.pablo#L264-L370); [`ParseTags`](https://github.com/parabix/parabix-devel-mirror/blob/6ff6d71e0df3906e94f14dc0f14125fdf98e1025/tools/xml/xml.pablo#L402-L530); [`CarryManager`](https://github.com/parabix/parabix-devel-mirror/blob/6ff6d71e0df3906e94f14dc0f14125fdf98e1025/include/pablo/carry_manager.h#L30-L102) | Uses the same six punctuation classes and a reduced quote-aware tag state. The public XML tool is CPU/Pablo; no public Parabix CUDA XML module was found. The four-state summary and CUB scan are independently derived and omit full XML validation. |
| FASTQ | [ALSER-Lab/FASTR](https://github.com/ALSER-Lab/FASTR/tree/37f2fffaef72e62326cdca45cc84d80d02b82763), commit `37f2fffa` | [`find_last_fastq_record_boundary` and `chunk_generator`](https://github.com/ALSER-Lab/FASTR/blob/37f2fffaef72e62326cdca45cc84d80d02b82763/src/toFASTR_chunk_processor.py#L104-L201); [`parse_fastq_records_from_buffer`](https://github.com/ALSER-Lab/FASTR/blob/37f2fffaef72e62326cdca45cc84d80d02b82763/src/toFASTR_fastq_parser.py#L10-L112) | Isolates canonical four-line record phase as newline materialization, modulo-four summaries, and a CUB scan. It omits FASTR conversion, validation, and its more general multiline parser; FASTR has no corresponding CUDA scan. |
| Regex | [getianao/BitGen](https://github.com/getianao/BitGen/tree/de7b7db0f385e21c5e6a5e2767f4264da890f9b0), commit `de7b7db0` | Official compiler and benchmark scripts retained under `regex/bitgen` as a Git submodule | Unmodified official BitGen source rather than an independently derived baseline. |

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

The standalone baseline interfaces are:

```bash
./build/csv_baseline <input.csv> [runs]
./build/xml_baseline <input.xml> [runs]
./build/fastq_baseline <input.fastq> [runs]
```

Initialize and run the regex source with:

```bash
git submodule update --init --recursive benchmarks/regex/bitgen
cd benchmarks/regex && ./run.sh
```
