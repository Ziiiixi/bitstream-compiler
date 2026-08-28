# Pristine cuJSON structural-bitmap baseline

Base revision: `2ac7d3dcd7ad1ff64ebdb14022bf94c59b3b4953`.

The vendored `cuJSON-standardjson.cu` differs from that revision only through
timing code guarded by `CUJSON_STRUCTURAL_BITMAP_TIMER`. The timer runs five
untimed warmups and ten measured repetitions. CUDA events cover the original
`checkAscii`, conditional `checkUTF8`, `bitMapCreatorSimd`,
`findEscapedQuoteMerge_NEW`, quote-count exclusive scan,
`inStringFinderBaseline`, and `findOutUsefulStringMerge` operations.

The interval excludes allocation/setup, checksum copies, the two later count
scans, and `removeCopy` compaction. No original kernel body, grid/block
expression, Thrust scan, synchronization, or workspace layout was changed.
The checksum covers all four endpoint arrays.

SHA-256 values:

- pristine source at the pinned commit:
  `5014bf8a3c22a901fda552464883196d3773760ee4fb31c3497a508a7c43a7e9`
- packaged instrumented source:
  `6b7a186e1fda840f83d7e5d43b6636ee005ffdd486ea8e6a85a8edb8060517e6`
- pristine and packaged query helper:
  `19cb48506286613d755473f024c1cef4ba0b896af69ab7078d2ba2d86d5d895a`

Build with `scripts/build.sh`, which defines
`CUJSON_STRUCTURAL_BITMAP_TIMER` for this source.
