# References

- Tianao Ge, Xiaowen Chu, and Hongyuan Liu. “Interleaved Bitstream Execution
  for Multi-Pattern Regex Matching on GPUs.” *MICRO 2025*.
  <https://doi.org/10.1145/3725843.3756052>
- Ashkan Vedadi Gargary, Soroosh Safari Loaliyan, and Zhijia Zhao. “cuJSON: A
  Highly Parallel JSON Parser for GPUs.” *ASPLOS 2026*, pp. 85–100.
  <https://doi.org/10.1145/3760250.3762222>
- Sacheendra Talluri et al. “GpJSON: High-Performance JSON Data Processing on
  GPUs.” *PVLDB* 18(9), 2025, pp. 3216–3229.
  <https://doi.org/10.14778/3746405.3746439>
- NVIDIA RAPIDS. “NVIDIA cuDF Documentation.”
  <https://docs.rapids.ai/api/cudf/stable/>. Public source correspondence:
  <https://github.com/NVIDIA/cudf/tree/v26.06.01/cpp/src/io/csv>.
- Dan Lin, Nigel Medforth, Kenneth S. Herdy, Arrvindh Shriraman, and Robert D.
  Cameron. “Parabix: Boosting the Efficiency of Text Processing on Commodity
  Processors.” *18th IEEE International Symposium on High Performance Computer
  Architecture (HPCA)*, 2012, pp. 373–384.
  <https://doi.org/10.1109/HPCA.2012.6169041>
  Public implementation: <https://github.com/parabix/parabix-devel-mirror>.
- Adrian Tkachenko, Sepehr Salem, Ayotomiwa Ezekiel Adeniyi, Zulal Bingol,
  Mohammed Nayeem Uddin, Akshat Prasanna, Alexander Zelikovsky, Serghei
  Mangul, Can Alkan, and Mohammed Alser. “FASTR: Reimagining FASTQ via Compact
  Image-inspired Representation.” *arXiv:2601.17184*, 2026.
  <https://doi.org/10.48550/arXiv.2601.17184>
  Public implementation: <https://github.com/ALSER-Lab/FASTR>.

The BitGen-style controls in this artifact borrow the paper's tile-major
execution idea only; they are independent experimental CUDA implementations
for the cuJSON and GPJSON workloads. By contrast, `regex/bitgen` is the pinned
official BitGen repository.
