# The four guessed homes call the resolver

## Why this was needed

The defaults ward (`bin/gates/guards/defaults-guard.sh`) was red on `main`. It refuses any
executable line that guesses where the operator's home lives instead of asking the one
resolver, `bin/vault/hoard-lib.sh`. Four lines guessed it, so the ward failed on every
push and blocked every branch.

## What changed

Each file now sources `bin/vault/hoard-lib.sh` once and takes its path from the resolver.
Nothing else in those files moved.

| File | Before | After |
|---|---|---|
| `bin/agents/agent-census.sh` | a fallback `STATE` built from a guessed home when the lib was missing | sources the lib directly and calls `hoard_state_dir STATE` |
| `bin/forge/issue-watch.sh` | `STATE` built from the home, with a guessed home as fallback | `hoard_state_dir STATE` |
| `bin/forge/pr-watch.sh` | the same guess as `issue-watch.sh` | `hoard_state_dir STATE` |
| `bin/forge/review-mend.sh` | `YMIR_HOME` defaulted to a guessed home | `ymir_home_root YMIR_HOME` |

The library is part of the tree, so the old "the lib may be missing" fallbacks were
removed rather than kept as a second place that knows where the home is.

Behaviour is the same in the normal case. One small difference is deliberate: the two
watchers now honour `YMIR_STATE_DIR` when it is set, the same way every other state user
does. The recorded home from installation is now honoured by `review-mend.sh` too, where
before it only read the environment.

## How it was proved

- `bin/gates/guards/defaults-guard.sh check` exits 0, with "none" in all three classes.
- `bash -n` passes on all four files.
- `bin/gates/tests/test_review_mend.sh` passes: 2 passed, 0 failed.
- `agent-census.sh --digest`, `pr-watch.sh --status` and `issue-watch.sh --status` ran and
  printed their normal output from the resolved state directory.

## CHANGE LOG

- 2026-11-12 — four guessed home defaults replaced with calls to `bin/vault/hoard-lib.sh`; the defaults ward is green again.
