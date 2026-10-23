# Two unresolved homes, and a Gná row that named a retired copy

**Date:** 2026-10-23 · **Component:** gate · **Branch:** fix/main-green

## What main reported

`bin/gates/ci-verify.sh` on a fresh checkout of `main` failed three rows:

```
defaults-guard   "uses the home, never resolves it"  bin/mail/install.sh
defaults-guard   "uses the home, never resolves it"  bin/time/snotra/snotra-approve.sh
capability / inventory   the generated registers were stale
```

## The mends

- `bin/mail/install.sh` no longer names a guessed tree in its worktree warning (the XDG unit directory
  stays — that is the operator's config path by standard, not the hoard).
- `bin/time/snotra/snotra-approve.sh` resolves the home through `bin/vault/hoard-lib.sh` instead of
  reading `$YMIR_HOME` directly.
- `FEATURES.md` gains ONE appended row naming the paths that actually ship (`bin/mail/…`), because one
  of the two Gná rows still named `hodd/bin/gna-agent/` — the P0 home copy, retired to
  `hodd/reference/`. Append, never erase (Rule 06).
- The registers are re-rendered: `inventory --check` rc 0.

## Still red, and named

`capabilities.sh --check` reports a diff on this machine. The register reads inputs the home provides
(skills, plans), so its verdicts can differ from a clean machine — the same class the ward's own hint
describes. Not chased at 22:00; the finding is written here rather than left to be rediscovered.
