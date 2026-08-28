# CSV staged baseline

This directory contains only the reportable baseline for the CSV finite-state
workload. It does not include a fused, speculative, recovered, or other
proposed implementation.

## Semantics

Every `"` byte toggles a two-state quote context. A `,` byte is counted when
that context is outside quotes. The GPU pipeline uses 256-byte chunks and
preserves all four baseline stages:

1. materialize one-byte-per-input-byte quote and comma masks;
2. materialize one quote-parity summary per chunk;
3. compute every chunk's incoming quote context with a device-wide CUB
   exclusive XOR scan; and
4. materialize per-chunk outside-quote comma counts, which the host sums for
   the reported delimiter count.

The CUDA-event interval covers all four GPU stages. File I/O, allocation, the
host-to-device input copy, device-to-host result copy, and the independent CPU
correctness check are outside that interval.

## Public source correspondence

The closest public source reference is the CSV reader in
[NVIDIA/cuDF v26.06.01](https://github.com/NVIDIA/cudf/tree/v26.06.01), commit
[`77ced62c`](https://github.com/NVIDIA/cudf/commit/77ced62cd91993510ea4a83c611caed64a319d1c):

- [`csv_gpu.hpp`](https://github.com/NVIDIA/cudf/blob/77ced62cd91993510ea4a83c611caed64a319d1c/cpp/src/io/csv/csv_gpu.hpp#L22-L152)
  defines the quote/comment row contexts, packed block summaries, and row-offset
  pass interface.
- [`gather_row_offsets_gpu`](https://github.com/NVIDIA/cudf/blob/77ced62cd91993510ea4a83c611caed64a319d1c/cpp/src/io/csv/csv_gpu.cu#L626-L800)
  evaluates multiple incoming quote contexts and emits row offsets.
- [`reader_impl.cu`](https://github.com/NVIDIA/cudf/blob/77ced62cd91993510ea4a83c611caed64a319d1c/cpp/src/io/csv/reader_impl.cu#L275-L365)
  shows the two GPU passes separated by block-summary prefix resolution.
- [`seek_field_end`](https://github.com/NVIDIA/cudf/blob/77ced62cd91993510ea4a83c611caed64a319d1c/cpp/src/io/utilities/parsing_utils.cuh#L203-L262)
  ignores delimiters while a quoted field is active.

The shared semantic is that quote context crosses input regions and determines
whether delimiters or terminators are structural. There is no exact public
cuDF counterpart to this standalone program: cuDF uses four-context local row
maps, custom CTA composition, a host block-prefix step, and a second GPU pass;
it does not materialize global quote/comma byte masks or use a CUB XOR scan.
cuDF also supports comments, configurable delimiters, quote placement, and
doubled quotes, whereas this deliberately simplified workload toggles on every
`"` and only counts commas outside that binary context.

`src/baseline.cu` is therefore an independently written, staged CSV
quote-context benchmark inspired by those public parsing stages—not an
extraction of, or official baseline from, cuDF. No cuDF source is copied here.

## Build and run

From the benchmark root, with a CUDA toolkit providing CUB:

```sh
cd benchmarks
GPU_ARCH=sm_86 ./scripts/build.sh
./build/csv_baseline input.csv
./build/csv_baseline input.csv 20
```

The optional run count defaults to 5. Output is one concise line containing
the average full-pipeline time in microseconds, input size, run count, GPU and
CPU counts, and `correctness=PASS|FAIL`.
