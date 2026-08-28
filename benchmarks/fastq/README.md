# FASTQ staged baseline

This directory contains only the reportable FASTQ baseline. It counts complete
four-line records by propagating the incoming line phase modulo four; it is a
front-end state benchmark, not a full FASTQ validator.

The measured GPU interval contains the complete staged pipeline:

1. materialize one newline byte per input byte in global memory;
2. compute each chunk's newline count and modulo-4 state;
3. run a CUB exclusive scan over the chunk states;
4. select a record count for every chunk from its exact incoming phase.

Allocation, host-to-device input transfer, device-to-host result transfer, and
the CPU correctness check are outside the interval. The default reportable
configuration is an 8,192-byte chunk and a 512-thread block.

## Build

CUDA Toolkit (including CUB) and a C++17-capable `nvcc` are required.

```bash
cd benchmarks
GPU_ARCH=sm_89 ./scripts/build.sh
```

Replace `sm_89` with the target GPU architecture and invoke
`./scripts/build.sh`; the default is `sm_86`. `NVCC` and `BUILD_DIR` may also
be overridden. The frozen workload defaults can be made explicit when
compiling directly with `-DFASTQ_CHUNK=8192 -DBLOCK_SIZE=512`.

## Run

```bash
./build/fastq_baseline /path/to/input.fastq
./build/fastq_baseline /path/to/input.fastq 20
```

The interface is `baseline <input> [runs]`; `runs` defaults to 5. Output
includes `avg-us`, the GPU and CPU record counts, and `correctness=PASS|FAIL`.
The process exits with status 2 if validation fails. Datasets are not bundled.

## Provenance

The workload corresponds to the public
[ALSER-Lab/FASTR](https://github.com/ALSER-Lab/FASTR) conversion code at commit
[`37f2fffa`](https://github.com/ALSER-Lab/FASTR/commit/37f2fffaef72e62326cdca45cc84d80d02b82763):

- [`find_last_fastq_record_boundary` and `chunk_generator`](https://github.com/ALSER-Lab/FASTR/blob/37f2fffaef72e62326cdca45cc84d80d02b82763/src/toFASTR_chunk_processor.py#L104-L201)
  identify complete FASTQ records at chunk boundaries and explicitly estimate
  record count as the number of newlines divided by four.
- [`parse_fastq_records_from_buffer`](https://github.com/ALSER-Lab/FASTR/blob/37f2fffaef72e62326cdca45cc84d80d02b82763/src/toFASTR_fastq_parser.py#L10-L112)
  is FASTR's full record parser and handles validation and multiline records.

The public FASTR repository is a Python/NumPy converter; it does not contain
this standalone CUDA scan. This benchmark independently isolates its canonical
four-line record-boundary state as a staged GPU pipeline: newline bitmap,
modulo-four chunk summary, global scan, and count selection. It therefore
matches the public code's four-line boundary logic, but it is not a copy or a
complete implementation of FASTR's parser, validation, or encoding. No FASTR
source code or dataset is redistributed here.
