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

The BitGen-style controls in this artifact borrow the paper's tile-major
execution idea only; they are independent experimental CUDA implementations
for the cuJSON and GPJSON workloads.
