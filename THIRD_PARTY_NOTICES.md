# Third-party notices

The compiler implementation in `mlir/bitstream/`, the runner, and the small
parseability wrappers were written for this research project. The prepared
workload inputs contain or adapt code from the projects listed below.

## cuJSON

- Upstream: <https://github.com/AutomataLab/cuJSON>
- Audited revision: `2ac7d3dcd7ad1ff64ebdb14022bf94c59b3b4953`
- Local material: `inputs/cujson/cujson.cpp`
- Modifications: selected tokenizer and UTF-validation stages were extracted,
  made parseable as ordinary C++ for Polygeist, and connected through a small
  deterministic driver.
- License: MIT; the complete notice is in
  `third_party/licenses/cuJSON-MIT.txt`.

Copyright (c) 2024 Ashkan Vedadi Gargary, Soroosh Safari Loaliyan, and Zhijia
Zhao.

## gpJSON

- Upstream: <https://github.com/gpjson-vldb/gpjson>
- Audited revision: `c912c1f1564c8bd750765b0650f59b56d334ce71`
- Local material: `inputs/gpjson/gpjson.cpp`
- Modifications: selected CUDA kernels were extracted, made parseable as
  ordinary C++, and connected through a driver preserving kernel order.
- License: Universal Permissive License, Version 1.0; the complete notice is in
  `third_party/licenses/gpJSON-UPL-1.0.txt`.

Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.

## simdjson prefix-XOR idiom

`inputs/gpjson/gpjson.cpp` preserves an upstream gpJSON attribution to the
prefix-XOR sequence in simdjson:

- Upstream: <https://github.com/simdjson/simdjson>
- Referenced revision: `cfc965ff9ada688cf5950da829331b28dfcb949f`
- Referenced file: `include/simdjson/arm64/bitmask.h`
- License: simdjson is available under Apache-2.0 or MIT terms.

## BitGen

- Upstream: <https://github.com/getianao/BitGen>
- Audited revision: `de7b7db0f385e21c5e6a5e2767f4264da890f9b0`
- Local wrapper: `inputs/bitgen/bitgen.cpp`
- Generated/template-derived body: `inputs/bitgen/regex_0.cu`

The BitGen repository did not contain a license statement at the audited
revision. The retained `regex_0.cu` includes substantial CUDA backend-template
material. It is kept in this private research repository for internal
evaluation, but it must not be made public or redistributed further until the
authors confirm redistribution terms, or until the file is replaced by an
independently written example. This restriction also applies to generated
BitGen analysis snapshots derived from that file.

## Project license

No project-wide license has been selected for the original compiler code. In
the absence of a license, no permission to copy, modify, or redistribute that
code is granted beyond applicable law. Third-party components remain governed
by their respective notices above.
