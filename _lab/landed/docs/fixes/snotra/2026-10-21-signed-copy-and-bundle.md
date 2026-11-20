## snotra · unversioned · 2026-10-21 — signed certified copy and evidence bundle

### What

- `snotra-evidence.sh sign` signs `certified-copy.md` with the operator's SSH key
  (`ssh-keygen -Y sign`), stores `signer.pub`, `allowed_signers` and the key fingerprint.
- `verify-sign` checks the signature with the stored allowed signers.
- `bundle` writes `evidence-bundle.tar.gz` and its SHA-256: manifest, chained log, timestamp,
  certified copy, corrections, signature and verification note.

### Verified

- Synthetic suite **10/10**, including signature valid and bundle written.
- A self-signed operator key is not a qualified signature; it is approval by the key holder.

### Not verified

- A qualified certificate signature; that requires the QTSP.
