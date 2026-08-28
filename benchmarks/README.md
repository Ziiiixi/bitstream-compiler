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

CSV, XML, and FASTQ are independently written standalone CUDA baselines, not
copied source modules. Their public correspondence and measured scope are
listed below.

## Public source correspondence

| Workload | Code origin in this repository | Public correspondence | Focused pipeline | Other full-pipeline stages excluded |
|---|---|---|---|---|
| cuJSON | Vendored public CUDA source plus local CUDA methods; not a Git submodule | [cuJSON tokenizer, `2ac7d3dc`](https://github.com/AutomataLab/cuJSON/blob/2ac7d3dcd7ad1ff64ebdb14022bf94c59b3b4953/paper_reproduced/src/cuJSON-standardjson.cu) | UTF-8 validation and tokenization through structural/open-close bitmaps | Structural-index compaction and JSON parsing |
| GPJSON | CUDA baseline derived from public GPU kernels; not a Git submodule | [escape](https://github.com/gpjson-vldb/gpjson/blob/c912c1f1564c8bd750765b0650f59b56d334ce71/language/src/main/resources/it/necst/gpjson/kernels/combined-escape-carry-newline-count-index.cu), [quote](https://github.com/gpjson-vldb/gpjson/blob/c912c1f1564c8bd750765b0650f59b56d334ce71/language/src/main/resources/it/necst/gpjson/kernels/quote-index.cu), [XOR scan](https://github.com/gpjson-vldb/gpjson/blob/c912c1f1564c8bd750765b0650f59b56d334ce71/language/src/main/resources/it/necst/gpjson/kernels/xor-pre-scan.cu), and [string](https://github.com/gpjson-vldb/gpjson/blob/c912c1f1564c8bd750765b0650f59b56d334ce71/language/src/main/resources/it/necst/gpjson/kernels/string-index.cu) kernels, `c912c1f1` | Escape carry, quote parity, in-string state, and structural bitmap | Newline indexing, nesting indexes, and later parsing |
| CSV | Independent CUDA baseline derived from a public GPU cuDF module; not a Git submodule | [row-context kernel](https://github.com/NVIDIA/cudf/blob/77ced62cd91993510ea4a83c611caed64a319d1c/cpp/src/io/csv/csv_gpu.cu#L626-L800) and [two-pass driver](https://github.com/NVIDIA/cudf/blob/77ced62cd91993510ea4a83c611caed64a319d1c/cpp/src/io/csv/reader_impl.cu#L275-L365), `77ced62c` | Quote-context propagation and outside-quote delimiter recognition | Row-offset generation, field decoding, and type conversion |
| XML | Independent CUDA baseline derived from a public CPU/Pablo module; not a Git submodule | Parabix [`Lex`](https://github.com/parabix/parabix-devel-mirror/blob/6ff6d71e0df3906e94f14dc0f14125fdf98e1025/tools/xml/xml.pablo#L29-L109), [`Preprocess`](https://github.com/parabix/parabix-devel-mirror/blob/6ff6d71e0df3906e94f14dc0f14125fdf98e1025/tools/xml/xml.pablo#L264-L370), and [`ParseTags`](https://github.com/parabix/parabix-devel-mirror/blob/6ff6d71e0df3906e94f14dc0f14125fdf98e1025/tools/xml/xml.pablo#L402-L530), `6ff6d71e` | Punctuation bitstreams and quote-aware tag state | UTF-8/name/reference validation, comments, CDATA, and full structural checks |
| FASTQ | Independent CUDA baseline derived from public CPU/Python code; not a Git submodule | FASTR [chunk boundaries](https://github.com/ALSER-Lab/FASTR/blob/37f2fffaef72e62326cdca45cc84d80d02b82763/src/toFASTR_chunk_processor.py#L104-L201) and [record parser](https://github.com/ALSER-Lab/FASTR/blob/37f2fffaef72e62326cdca45cc84d80d02b82763/src/toFASTR_fastq_parser.py#L10-L112), `37f2fffa` | Four-line record phase and boundary propagation | Full record parsing, validation, and FASTR conversion |
| Regex | Official public GPU implementation included as a Git submodule | [BitGen, `de7b7db0`](https://github.com/getianao/BitGen/tree/de7b7db0f385e21c5e6a5e2767f4264da890f9b0) | Complete official BitGen regex benchmark | None; upstream source is unmodified |

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
