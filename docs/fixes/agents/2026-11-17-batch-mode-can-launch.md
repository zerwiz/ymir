# Batch mode could not launch: `REUSE_PANE` was declared inside the relaunch branch

**2026-11-17 · component `agents` · found while dispatching eight errands for the Allfather's order**

## What was wrong

`bin/agents/einherjar-spawn.sh` declares the reuse-seat variables where the double-agent guard lives:

```
REUSE_PANE=""
REUSE_WS=""
if command -v herdr …        # the guard that refuses a second agent in one worktree
```

That block sits **inside** `if [ "$RELAUNCH" -eq 1 ]; then … fi`. On a fresh spawn the branch is
skipped, so `REUSE_PANE` is never set — and both `launch_herdr` (line 1163) and the `--dry-run`
printer (line 883) test it with `[ -n "$REUSE_PANE" ]` under `set -eu`. The result is not a
refusal, it is a crash:

```
bin/agents/einherjar-spawn.sh: line 1163: REUSE_PANE: unbound variable
```

## Why it mattered

`--mode batch` is owned by the old road: the engine refuses it (`engine-cannot-own: unsupported
mode 'batch'`) and falls through to that road, which then died. **Every batch errand was
unlaunchable**, and the mistake was invisible before because the engine owns `direct-PR` — the
mode the recent errands used — and returns before the old road is reached.

## The fix

The two assignments move above the `if [ "$RELAUNCH" -eq 1 ]`, where they belong: the variable is
part of the launcher's contract, not of one branch of it. Nothing else changes; a relaunch still
sets both from the pane it reuses.

## Proof

```
$ bash bin/agents/einherjar-spawn.sh heart-estate /home/heimdall/ymir --mode batch \
    --harness pi --model opencode-go/deepseek-v4.1-flash --dry-run
preflight[1]{…,worktree,brief,mode,…}:
  "…","/home/heimdall/ymir/.yggdrasil/heart-estate","…/data/heart-estate/brief.md","batch","off","yes","no"
```

Before the fix the same command printed `line 883: REUSE_PANE: unbound variable` and exited 1.
After it, eight batch errands were seated in one afternoon.

## What is still owed

The **guard itself** (the block that refuses a second agent in one worktree) is still inside the
relaunch branch, so a fresh spawn does not run it. That is a second defect and it is not mended
here: hoisting it changes when a spawn refuses, which wants its own test — an errand, not a
two-line repair made in the middle of a dispatch.
