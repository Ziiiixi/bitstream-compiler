# Results policy

Historical and preliminary measurements were removed because they predate the
current fused kernels. Regenerate results only after freezing the source, and
record:

- the exact commit and source hashes;
- captured GPU/driver/CUDA environment;
- verified dataset hashes;
- one fixed warmup and timed-run protocol;
- both execution policies reported separately;
- correctness status and output hashes for every correct method.

Do not commit generated results under `results/local/`.
