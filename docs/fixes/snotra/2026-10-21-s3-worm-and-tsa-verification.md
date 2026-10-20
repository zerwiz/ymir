## snotra · unversioned · 2026-10-21 — S3 WORM upload and TSA verification

### What

- `snotra-evidence.sh worm-s3 <dir>` uploads the evidence set to an S3-compatible bucket
  with Object Lock COMPLIANCE, a retention date, a SHA-256 checksum and the manifest root
  as metadata. `--dry-run` prints the destination without credentials.
- `snotra-evidence.sh verify-ts <dir>` verifies an RFC 3161 token against the provider CA
  (`SNOTRA_TSA_CA` or `timestamp/ca.pem`).

### Verified

- FreeTSA: query → token → `verify-ts` **valid** against the FreeTSA CA on a synthetic
  fixture. Not a qualified timestamp.
- `worm-s3 --dry-run` against the Wasabi Frankfurt endpoint prints the prefix, 8 files and
  COMPLIANCE/3650 days.

### Not verified

- A real Wasabi bucket upload and restore; no credentials/bucket yet.
- A qualified provider token (Signicat/Datasure); the client is standard RFC3161.

### Appended 2026-10-21 — access log chain

The gate's `access.jsonl` is now hash-chained: each entry carries `prev` and `entry`, and
`snotra-evidence.sh verify-access` recomputes the chain. The synthetic test verifies a
valid chain and refuses a tampered entry (8/8 tests pass). Legacy unchained entries are
counted, not silently accepted as chained.
