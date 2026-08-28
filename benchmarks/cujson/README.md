# cuJSON structural-bitmap workload

This workload validates UTF-8 and produces structural and filtered open/close
bitmaps using one 32-byte word per ordinary experimental thread.

## Core sources

| Source | Executable name | Execution policy |
|---|---|---|
| `upstream/cuJSON-standardjson.cu` | `cujson_upstream_baseline` | Original cuJSON pipeline; one input |
| `src/bitgen_targeted_baseline.cu` | `cujson_bitgen_targeted_baseline` | Four kernels, one 256-thread CTA per input |
| `src/bitgen_fused.cu` | `cujson_bitgen_fused` | BitGen-style fused 256-thread CTA per input |
| `src/enumeration.cu` | `cujson_enumeration` | One word per thread, GM readiness |
| `src/hierarchical_speculation.cu` | `cujson_hierarchical_speculation` | Many-CTA hierarchy, compact recovery |
| `src/speculation_no_validation.cu` | `cujson_speculation_no_validation` | F1-only, intentionally incorrect |

The canonical hierarchy is the packed quote-parity-mask version. Older slash
scan and parity-word ablations are deliberately excluded from the core tree.

## Hierarchical enumeration

- `experimental/hierarchical_enumeration_literal.cu` materializes complete
  `E=0` and `E=1` candidates.
- `experimental/hierarchical_enumeration_compact.cu` stores only the exact
  one-byte position at which the two candidates begin to differ. It performs
  selection without input rereading or a recovery kernel.

All non-upstream programs use:

```text
EXECUTABLE RUNS file1.json [file2.json ...]
```

The upstream timer uses:

```text
cujson_upstream_baseline -b input.json
```

This directory's “BitGen” names describe the scheduling organization and do
not denote code from the official BitGen implementation.
