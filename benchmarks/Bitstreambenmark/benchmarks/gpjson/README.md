# GPJSON structural-bitmap workload

This workload produces GPJSON's 64-bit structural bitmap. It excludes UTF-8
validation, newline indexing, and nesting/index construction.

## Core sources

| Source | Executable name | Execution policy |
|---|---|---|
| `src/source_faithful_baseline.cu` | `gpjson_source_faithful_baseline` | Reduced source-faithful fixed 16,384 x 1,024 pipeline |
| `src/bitgen_targeted_baseline.cu` | `gpjson_bitgen_targeted_baseline` | Stage-major, one 1,024-thread CTA per input |
| `src/bitgen_fused.cu` | `gpjson_bitgen_fused` | BitGen-style tile-major, one 1,024-thread CTA per input |
| `src/enumeration.cu` | `gpjson_enumeration` | One 64-byte word per thread, GM readiness |
| `src/hierarchical_speculation.cu` | `gpjson_hierarchical_speculation` | Coalesced F1, compact recovery, original quote scan |
| `src/speculation_no_validation.cu` | `gpjson_speculation_no_validation` | F1-only, intentionally incorrect |

Batch controls accept:

```text
EXECUTABLE RUNS file1 [file2 ...]
```

Per-input controls accept:

```text
EXECUTABLE INPUT [RUNS]
```

## Hierarchical enumeration

- `experimental/hierarchical_enumeration_literal.cu`: full `E=0/E=1`
  candidate materialization.
- `experimental/hierarchical_enumeration_original_scan.cu`: selects parity in
  a high-TLP pass, then retains GPJSON's original three-kernel quote scan.
- `experimental/hierarchical_enumeration_compact_delta.cu`: represents the
  exact alternative as the first affected quote position rather than a second
  full bitmap.

These are experimental controls, not part of the frozen six-method figure yet.

This directory's “BitGen” names describe the scheduling organization and do
not denote code from the official BitGen implementation.
