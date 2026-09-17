## 2026-09-17 — the hoard encrypts its secrets at rest

- **`bin/hodd.sh` decrypts transparently.** `load`, `emit`, and `tenant` now
  accept a plaintext file *or* an `.age` ciphertext with the sibling plaintext
  absent. A shared `resolve_secret` finds the readable form; when it decrypts,
  it uses a mode-600 temp and removes it afterward. An agent asks for the
  resolved path and never handles ciphertext directly.
- **Secrets stay encrypted at rest.** `hodd/secrets/platform.env.age` is the
  committed form; the plaintext is scratch and gitignored. Round-trip verified
  byte-identical before the plaintext was untracked.
- **The vault invariant, written down.** The age key and the ciphertext travel
  together in the private `ymirhome` repo, so a dead disk loses nothing — and
  `ymirhome` **must never be made public**. Stated in `hodd/docs/secrets-vault.md`.
- **The honest limit.** This is encryption-at-rest, not encryption-against-yourself:
  on a single-user machine, a process running as the operator can read what the
  operator can read. What it buys is the *file* and the *repo*, not the *account*.
