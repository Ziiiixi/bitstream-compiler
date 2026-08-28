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

The “BitGen-style” controls under `cujson/` and `gpjson/` are independent
implementations inspired by the tile-major execution order described in the
BitGen paper.

Separately, `regex/bitgen` is an official, unmodified BitGen Git submodule from
<https://github.com/getianao/BitGen.git>, pinned at
`de7b7db0f385e21c5e6a5e2767f4264da890f9b0`. That upstream revision has no
license file. Inclusion as a pinned submodule does not grant or imply any
license rights; users must obtain any necessary permission from the upstream
rightsholders.

## CSV, XML, and FASTQ baselines

The code under `csv/`, `xml/`, and `fastq/` consists of independently written,
staged CUDA baselines for reduced state problems corresponding to public cuDF,
Parabix, and FASTR code. They preserve materialized intermediate bitstreams and
contain no proposed fused, speculative, or recovery implementation. Each
workload README pins the closest public files and documents the differences.

No source code was copied from cuDF, Parabix, or FASTR. Their documentation and
papers provide workload context only; see `REFERENCES.md`. CUB is supplied by
the CUDA Toolkit and is not redistributed here.

The FASTQ README maps its state benchmark to public FASTR commit
`37f2fffaef72e62326cdca45cc84d80d02b82763`. FASTR is MIT-licensed at that
revision; FASTR code itself is not vendored in this repository.

## Datasets

Only filenames, source links, byte sizes, hashes, and the derived-input recipe
belong in this repository. Confirm the dataset redistribution terms before
publishing any input data.
