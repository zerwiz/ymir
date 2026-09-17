## 2026-09-17 — the package shipped the memory well (one version, now excluded)

- **The exposure.** `@zerwiz/ymir@0.1.5` carries five files that are nobody's but
  the operator's: `.agents/memory/kaia.engram`, its `-shm` and `-wal` sidecars, and
  `.agents/memory/well/{episodes,workspace}.jsonl`. A public npm tarball contained
  the live memory well — the store and the episodes. Verified by fetching the
  published artefact and listing it; `0.1.0`–`0.1.4` are clean, and this branch's
  build is clean.
- **The cause, and it is a trap worth naming.** `.gitignore` excludes
  `.agents/memory/kaia.engram*` and `.agents/memory/well/*.jsonl`, and the repo is
  clean — but **npm does not consult `.gitignore` when `files[]` names a whole
  directory.** `files: [".agents/"]` packs that subtree *including* the ignored
  files. Nothing warned: the leak travelled in the artefact, not the repo.
- **The fix.** The manifest excludes them explicitly, because a `files[]` list
  cannot rely on the ignore file it overrides:
  `!.agents/memory/kaia.engram*`, `!.agents/memory/well/*.jsonl`,
  `!.agents/memory/*.db`, plus `!**/__pycache__/` and `!**/*.pyc` for the compiled
  junk that was travelling the same way. Verified: `npm pack --dry-run` carries
  864 files and **no** memory store — the memory README and the ledger's scaffold
  header are all that remain, as they should be.
- **The rule for every future package:** a `files[]` entry that names a directory
  overrides `.gitignore` for everything beneath it. Name what ships, or exclude
  what must not — and verify with a dry-run pack, never by assumption.
- **Remediation.** `@zerwiz/ymir@0.1.5` should be unpublished (it is inside npm's
  window); the clean build publishes as 0.1.7 and supersedes it.
