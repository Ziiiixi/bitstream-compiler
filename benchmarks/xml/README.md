# XML lexical-state baseline

This standalone CUDA benchmark emits a packed bitmap of active XML lexical
delimiters. It contains only the reportable staged four-state baseline:

1. materialize `<`, `>`, `/`, `=`, double-quote, and single-quote masks;
2. compute each 1,024-byte chunk's exact transition for all four input states;
3. run a device-wide exclusive prefix scan over those transitions; and
4. apply each chunk's exact incoming state to emit the delimiter bitmap.

The four states are text, tag, double-quoted attribute, and single-quoted
attribute. The executable compares the complete GPU bitmap with an independent
serial CPU implementation and reports their delimiter counts.

## Build and run

Requirements are an NVIDIA GPU and a CUDA Toolkit with C++17 and CUB support.
The default target is `sm_86`; override it for another GPU.

```bash
cd benchmarks
GPU_ARCH=sm_86 ./scripts/build.sh
./build/xml_baseline <input.xml> [runs]
```

`NVCC` and `BUILD_DIR` may be overridden. Build products default to the
ignored `benchmarks/build/` directory.

The default is five measured runs. `avg-us` covers the full GPU pipeline:
classification, exact chunk summarization, global prefix scan, and bitmap
application. Allocation, input transfer, result transfer, and CPU validation
are outside the timed region. Empty input produces an empty bitmap. A
successful run prints `correctness=PASS` and returns zero.

## Provenance

The closest public semantic reference is the XML pipeline in the
[Parabix development mirror](https://github.com/parabix/parabix-devel-mirror)
at commit
[`6ff6d71e`](https://github.com/parabix/parabix-devel-mirror/commit/6ff6d71e0df3906e94f14dc0f14125fdf98e1025):

- [`Lex` and `ClassifyBytesValidateUtf8`](https://github.com/parabix/parabix-devel-mirror/blob/6ff6d71e0df3906e94f14dc0f14125fdf98e1025/tools/xml/xml.pablo#L29-L109)
  define the exact `<`, `>`, `/`, `=`, single-quote, and double-quote streams
  represented by this benchmark's six masks.
- [`Preprocess`](https://github.com/parabix/parabix-devel-mirror/blob/6ff6d71e0df3906e94f14dc0f14125fdf98e1025/tools/xml/xml.pablo#L264-L370)
  builds XML lexical scopes, while
  [`ParseTags`](https://github.com/parabix/parabix-devel-mirror/blob/6ff6d71e0df3906e94f14dc0f14125fdf98e1025/tools/xml/xml.pablo#L402-L530)
  performs quote-aware attribute and tag scans.
- [`xmlPipelineGen`](https://github.com/parabix/parabix-devel-mirror/blob/6ff6d71e0df3906e94f14dc0f14125fdf98e1025/tools/xml/xml.cpp#L57-L156)
  wires the public XML stages through Parabix's CPU driver.
- [`CarryManager`](https://github.com/parabix/parabix-devel-mirror/blob/6ff6d71e0df3906e94f14dc0f14125fdf98e1025/include/pablo/carry_manager.h#L30-L102)
  is the generic cross-bitblock carry mechanism used by Pablo scan/advance
  operations.

The public Parabix XML tool is CPU-oriented and has no corresponding CUDA
module. Its carry manager is not this benchmark's four-state transition
monoid. The explicit four-state FSM, byte-per-position masks, per-chunk
four-entry summaries, CUB scan, and combined delimiter bitmap here are an
independently written CUDA staging of the smaller lexical-state problem.
It intentionally omits Parabix's UTF-8 and name validation, comments, CDATA,
processing instructions, references, and structural tag checks. It is neither
a source extraction nor a complete behavior-equivalent Parabix port; no
Parabix source code or dataset is redistributed here.
