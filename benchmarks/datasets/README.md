# Dataset setup

Place the seven large inputs in a directory outside the repository and pass it
as `DATA_DIR`. The expected names, byte sizes, and SHA-256 hashes are recorded
in `manifest.csv` for manual integrity checks.

The files total 8,074,397,402 bytes (7.520 GiB). They are not committed because
of their size and unresolved redistribution terms. The six `*_large_record`
files come from the dataset folder linked by cuJSON; the base GPJSON input comes
from the dataset folder linked by GPJSON.

`twitter_small_records_2x.json` is exactly two byte-identical copies of
`twitter_small_records.json` concatenated in order:

```bash
cat twitter_small_records.json twitter_small_records.json > twitter_small_records_2x.json
```

The base file is 873,102,675 bytes with SHA-256
`89285e84f5002fd8da82fafc2adb3a7d40b5be8be492cde8a5bdbbaafa3e3b02`.
The manifest records the exact derived file hash.
