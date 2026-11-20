# The app icons open from the pin again

**2026-11-12 · component: desktop · `scripts/electron.sh` · `scripts/raise.sh` · `scripts/start.sh` · `bin/desktop/sessrumnir-launch.sh`**

## What was wrong

The launchers for Hlidskjalf, Óðrerir and Smíðja did nothing when clicked. Measured on the pinned runtime:

```
electron.sh: running from a WORKTREE — the app runtime is locked to main (/home/<user>/ymir-runtime), re-executing there
bash: /home/<user>/ymir-runtime/electron.sh: No such file or directory
```

Each launcher carries a guard that sends a worktree's copy to main's copy. The guard asked the resolver for the
canonical **root**, then compared it with the script's own **folder** (`scripts/`). A root never equals a subfolder, so
on the pin the guard always fired, and the path it re-ran dropped the `scripts/` part. Every icon died at that line.

In `bin/desktop/sessrumnir-launch.sh` the same block looked for the resolver one level too high (`bin/bin/desktop/…`),
so the guard never ran at all.

## What was done

One corrected block in all four launchers. It walks up from the script to the folder that holds
`bin/desktop/main-tree.sh`, compares that root with the canonical root, and re-runs the same relative path only when
that file exists in main.

## Proof

`bin/desktop/tests/test_launcher_worktree_guard.sh` builds a temporary repository and a worktree with the real guard
blocks: in the main tree each launcher runs in place, and from a worktree each re-runs main's copy. With the fix it
passes 8 of 8. With the old guard it passes 1 of 8.

## CHANGE LOG

- **2026-11-12** — the guard compares root with root, in all four launchers.
