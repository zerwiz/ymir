# Transcript provenance — proving a meeting record has not changed

**What it is.** `bin/time/snotra/snotra-provenance.sh` seals every meeting artifact with
a SHA-256 manifest and a hash-chained, append-only log, and verifies it later. It is the
local, cryptographic half of the evidence chain; it is **not** a qualified eIDAS
timestamp and does not by itself make a transcript legally certified.

## Use it

```sh
bin/time/snotra/snotra-provenance.sh seal   <meeting-dir> --note "after sign-off"
bin/time/snotra/snotra-provenance.sh verify <meeting-dir>
bin/time/snotra/snotra-provenance.sh status <meeting-dir>
```

`seal` writes `provenance.json` (the manifest) and appends one entry to
`provenance.jsonl`; both are mode 0600. A legitimate change is a **new seal**, never a
rewrite. `verify` recomputes every file and fails on any mismatch or added/removed file.

## What the law and the patent process actually require

- **EPO:** evidence is weighed by free evaluation; a dated internal paper marked
  confidential and unsigned was not enough in T 332/87. What persuades is a **dated,
  reproducible record** with context and custody, not a hash alone.
- **UPC:** electronic files and audio/video recordings are means of evidence; their
  probative value depends on integrity and chain of custody.
- **eIDAS:** an electronic time stamp is data binding a time to data; a **qualified**
  time stamp from a qualified trust service provider has the strongest cross-EU effect.
  A local clock is not a qualified timestamp.
- **Trade Secrets Directive (EU) 2016/943:** confidentiality must be actively maintained;
  access control, need-to-know and records of disclosure are part of the protection.
- **AI transcription:** a transcript relied on independently of the recording should have
  **qualified human review**; the degree of review rises when it is filed or certified.
  Record the model, version, settings and the human corrections.
- **GDPR:** recording and transcript are personal data; define purpose, retention,
  access, erasure and a DPIA where required.

## The evidence chain to build

1. **Capture** — raw audio and the source file, device, capture time, operator, model and
   settings. Never transcribe from a re-encoded copy.
2. **Seal** — SHA-256 of every artifact, a manifest root, a chained append-only log.
3. **Timestamp** — send the root to a **qualified timestamp authority** (RFC 3161) or a
   QTSP; store the token and certificate chain with the record. OpenTimestamps is a
   useful secondary, not a substitute for a qualified timestamp.
4. **Human certification** — the sign-off sheet, the reviewer, the corrections appended,
   and a certified PDF; the machine transcript remains the evidence, not the certified
   text.
5. **Custody** — directory 0700, files 0600, WORM/object-lock storage or an immutable
   backup, an access log, and a legal-hold switch.
6. **Export control** — the private guard (paths, secrets, NDA) plus a provenance
   `verify` before any external surface; a failed verify stops the send.
7. **Verification package** — manifest, log, timestamp token, certificate chain, the
   tool and hash algorithm, and a plain-language verification note.
8. **Retention and incident** — a defined retention period, secure deletion, and a
   recorded incident path if a hash ever fails.

## What is implemented, and what is not

Implemented: `seal`, `verify`, `status`; hash-chained log; mode 0600; NDA/path/secret
guard; human sign-off; the record and transcript are local.

Not implemented, and needed before calling it court-grade: a **qualified eIDAS
timestamp**, WORM storage, an access log, a certified-copy workflow, retention/legal
hold, key custody, and an independent verification note. Those are operational and
contractual controls, not regexes.

## The evidence bundle — timestamp, immutable copy, certification, retention

```sh
# 1. seal the artifact set
bin/time/snotra/snotra-provenance.sh seal <meeting-dir>

# 2. timestamp the root (with a QTSP/RFC 3161 authority if you have one)
bin/time/snotra/snotra-evidence.sh timestamp <meeting-dir> --tsa https://tsa.example/rfc3161

# 3. a local read-only copy (not object-lock, but tamper-resistant)
bin/time/snotra/snotra-evidence.sh worm <meeting-dir>

# 4. human certification
bin/time/snotra/snotra-evidence.sh certify <meeting-dir> --reviewer "Reviewer Name" --note "corrections"

# 5. retention policy (enforce moves, never deletes)
bin/time/snotra/snotra-evidence.sh retention <meeting-dir> --days 365
bin/time/snotra/snotra-evidence.sh enforce <meeting-dir> --dry-run
```

Without `--tsa`, the timestamp is stored as **local-unqualified** and labelled as such.
With a TSA, the token and response text are stored; `verify-ts` checks the token against
the provider CA (`SNOTRA_TSA_CA` or `timestamp/ca.pem`).

## WORM upload

```sh
SNOTRA_WORM_ENDPOINT=https://s3.eu-central-2.wasabisys.com \
SNOTRA_WORM_BUCKET=evidence \
SNOTRA_WORM_MODE=COMPLIANCE \
SNOTRA_WORM_RETENTION_DAYS=3650 \
bin/time/snotra/snotra-evidence.sh worm-s3 <meeting-dir> [--dry-run]
```

`worm-s3` uploads every artifact except the mutable access log with S3 Object Lock in
COMPLIANCE mode, a SHA-256 checksum and the manifest root as metadata. It needs
`SNOTRA_WORM_ACCESS_KEY` / `SNOTRA_WORM_SECRET_KEY` from the vault. Without credentials,
`--dry-run` prints the endpoint, bucket, prefix, file count and retention.
A local read-only copy is **not** object-lock WORM; it is a second copy with permissions
removed. Neither is a substitute for a qualified timestamp or a WORM store.

The gate (`bin/gates/guards/sensitive-gate.sh`) checks classification, hold, access list,
provenance and the NDA/private guard before any external surface.
