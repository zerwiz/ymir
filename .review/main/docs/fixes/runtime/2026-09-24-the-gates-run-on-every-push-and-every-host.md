## runtime · unversioned · 2026-09-24 — the gates run on every push, and on both hosts

### Why
The two locks existed and **nothing ran them**, which makes them wishes of a different kind. A
rule without a lock is a wish; a lock nobody invokes is a rumour.

And the checks must not live in the CI files: this repository already uses **two hosts**, GitHub
Actions and Forgejo Actions. A workflow that lists the steps is a second place for them to drift,
and two hosts listing them is a third. So the steps live in one command and both doors call it.

### What
- **`bin/guards.sh`** — every TREE ward in one command, from **one list**. Adding a ward means
  adding a line here, and nowhere else.
- **`bin/ci-verify.sh`** — what CI owes, in one command: the tree wards, the fifteen governance
  gates, and the real local npm install. `--fast` skips the heavy third.
- **the pre-push hook** now runs `guards.sh` **first**, before the branch and fix-note guards,
  because a dirty tree should fail before anything else is argued about. Re-seated by
  `bin/fixes-guard.sh --install`, which is where the hook template lives.
- **`.github/workflows/ymir-gates.yml`** and **`.forgejo/workflows/ymir-gates.yml`** — identical
  files, one job, one step, calling `bash bin/ci-verify.sh`. Two doors, one room. If a host
  needs a different runner label, that is one line in one file and no change to what is proved.

### Verified
- `bin/guards.sh` passes clean, and **fires** when a ward does
  (`RUNTIME_GUARD_ALLOW=/dev/null bin/guards.sh` reports `runtime-guard FAIL`, exit 1). A gate
  that cannot fail is theatre.
- All four scripts pass `bash -n`.
- The hook as installed names the three gates and their order.

### Files
- `bin/guards.sh`
- `bin/ci-verify.sh`
- `bin/fixes-guard.sh`
- `.github/workflows/ymir-gates.yml`
- `.forgejo/workflows/ymir-gates.yml`
