# GPJSON baseline provenance

The source-faithful structural-bitmap pipeline is derived from GPJSON revision
`c912c1f1564c8bd750765b0650f59b56d334ce71`.

The packaged benchmark retains the original logical grid, block size, segment
mapping, escape-state handling, and three-kernel quote-parity scan. It omits
unrelated parser stages because this artifact compares only structural-bitmap
generation.

The retained material is governed by the Universal Permissive License,
Version 1.0. The complete notice is in
`../../third_party/licenses/gpJSON-UPL-1.0.txt`. See
`../THIRD_PARTY_NOTICES.md` for benchmark-specific provenance.
