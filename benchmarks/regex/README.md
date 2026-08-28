# Regex matching baseline (BitGen)

This workload uses the public optimized BitGen implementation directly. The
official repository is retained as the `bitgen/` Git submodule at commit:

```text
de7b7db0f385e21c5e6a5e2767f4264da890f9b0
```

No BitGen compiler or generated CUDA source is modified. The pinned revision
is the one tested on the RTX 6000 Ada server with the ten official 1 MB regex
applications.

The upstream repository does not contain a redistribution license file, so it
is referenced as a submodule instead of being copied into this repository.

## Setup

```bash
git submodule update --init --recursive benchmarks/regex/bitgen
cd benchmarks/regex/bitgen
source ./env.sh
./1_download_benchmark.sh
./4_build_all.sh
```

## Run the retained baseline configuration

From `benchmarks/regex/`:

```bash
./run.sh
```

The runner uses the official ten-application configuration and two unmodified
BitGen schemes: the Figure 12 `Base` configuration and the final optimized
BitGen configuration. Compilation and input transpose are excluded from the
reported `run_regex` timing, matching the official artifact methodology.
