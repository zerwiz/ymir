## runtime · unversioned · 2026-09-27 — the state shim told the ward a lie

### Why

The full-main verification (2026-09-27, the Allfather's "test all new code")
found the defaults-guard red: `bin/gleipnir-lock-lib.sh` (the merged
engine-state shim) carried the literal `${YMIR_HOME/state` in its header comment
but never called the resolver — so the ward's rule 2 ("a script that USES the
home and never RESOLVES it") fired, even though the shim never uses the home: it
delegates to `bin/ymir-state.sh`, which resolves through `bin/vault/hoard-lib.sh`. A
comment wearing the home's name is a lie the ward is built to catch.

### The fix

- The header now says the state dir "resolves from the hoard (bin/vault/hoard-lib.sh)",
  never the tree — no literal home guess, no unresolved reference.
- The shim's delegation is unchanged; the door still resolves.

galdr-reread: `runtime-compliance.md` (the defaults-guard row).

### Files

- `bin/gleipnir-lock-lib.sh`