# Prepared Source Inputs

Each directory contains one C++ source example derived from a real bitstream
workload. CUDA-specific syntax is made parseable and an ordinary C++ driver
preserves the original kernel-call order. The files are source inputs for the
compiler; Polygeist is only the frontend used to parse them.

The inputs are not covered by one project-wide license. Their exact upstream
revisions, modifications, copyright notices, and redistribution terms are
recorded in `../THIRD_PARTY_NOTICES.md`.

| Directory | File | Example |
|---|---|---|
| `gpjson/` | `gpjson.cpp` | GPJSON tokenizer kernel sequence. |
| `cujson/` | `cujson.cpp` | `cujson_tokenizer`: UTF validation followed by cuJSON bitmap stages through the structural-bitmap endpoint used by the mypc experiment. |
| `bitgen/` | `bitgen.cpp`, `regex_0.cu` | One BitGen-generated regex body. |

`bitgen/regex_0.cu` is the only generated regex body retained in this
workspace. `bitgen.cpp` is a small parseable wrapper that invokes it. There is
no all-regex dispatcher or collection of BitGen regex bodies here. The audited
BitGen revision has no stated license; keep this example private until its
redistribution terms are confirmed or replace it with independently written
code before publishing the repository.
