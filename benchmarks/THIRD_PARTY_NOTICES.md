# Third-party provenance and release checks

## cuJSON

- Upstream project: <https://github.com/AutomataLab/cuJSON>
- Pinned base revision: `2ac7d3dcd7ad1ff64ebdb14022bf94c59b3b4953`
- License: MIT; retained in `../third_party/licenses/cuJSON-MIT.txt`
- Vendored files:
  - `cujson/upstream/cuJSON-standardjson.cu`
  - `cujson/upstream/query/query_iterator_standard_json.cpp`

The baseline source differs from the pinned revision only through timing code
guarded by `CUJSON_STRUCTURAL_BITMAP_TIMER`. Its event interval ends after the
structural and filtered open/close bitmaps and excludes later compaction.

The other files under `cujson/src`, `cujson/include`, and `cujson/experimental`
are research harnesses written for this artifact. They reproduce cuJSON's
structural-bitmap computation while changing execution organization.

## GPJSON

- Upstream project: <https://github.com/gpjson-vldb/gpjson>
- Inspected source tree revision: `c912c1f1564c8bd750765b0650f59b56d334ce71`
- License: Universal Permissive License, Version 1.0; retained in
  `../third_party/licenses/gpJSON-UPL-1.0.txt`.
- `gpjson/include/original_gpjson.cuh` is a reduced,
  source-faithful structural-bitmap implementation used for comparison.

The GPJSON sources under `src`, `include`, and `experimental` adapt that
workload into the compared execution organizations; they are not copies of the
complete upstream application.

## simdjson prefix-XOR idiom

The GPJSON workload retains the six-shift prefix-XOR sequence attributed by
upstream GPJSON to simdjson revision
`cfc965ff9ada688cf5950da829331b28dfcb949f`. simdjson is available under the
Apache License 2.0 or MIT license.

## BitGen

The “BitGen-style” controls are independent implementations inspired by the
tile-major execution order described in the BitGen paper. No official BitGen
source or generated kernel is vendored in this artifact. See `REFERENCES.md`.

## Datasets

Only filenames, source links, byte sizes, hashes, and the derived-input recipe
belong in this repository. Confirm the dataset redistribution terms before
publishing any input data.
