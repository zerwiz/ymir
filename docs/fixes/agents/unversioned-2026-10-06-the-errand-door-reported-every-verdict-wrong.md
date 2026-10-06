## agents · unversioned · 2026-10-06 — the errand door reported every verdict wrong, and a seat died of a missing path

### Why

Two failures, both found while filing plan 71, and both of the same species: **a broken thing
failed silently, and the silence was shaped exactly like success.**

**1. The errand tool could not report a result.** `.pi/extensions/eindri.ts` runs its child with
`stdio: "inherit"` for every `start`, `steer` and `close` — the child writes straight to the
terminal, which is deliberate, so the Allfather watches the launch happen. But
**`execFileSync` returns `null` under `stdio: "inherit"`, not a string.** The next line called
`out.trim()` on that null. The `TypeError` was caught by the surrounding catch, reported as
`rc=1`, and its own message became the tool's output:

```
dag-runes-p1: spawn rc=1
Cannot read properties of null (reading 'trim')
```

So **every non-quiet call reported failure and printed a JavaScript error, whether or not the
command had worked.** In this instance the spawn had *succeeded* — it created the meta record, the
worktree and the tmux window — while the door told Brokk it had failed. A tool that always says
"failed" is a tool nobody believes, and the real fault it reports gets dismissed as noise.

**2. The seat then died on a path that resolved to nothing.** With the errand believed dead, the
obvious repair was a fresh spawn, which found a seat record already standing and refused. The seat
was inspected directly and found to be a corpse: `bin/model/local-model-lock.sh` sourced
`bin/vault/hoard-lib.sh` through a candidate list that **omitted `$SCRIPT_DIR/../vault/hoard-lib.sh`**
— the path every sibling in `bin/agents/` uses first — and whose fallback resolved to
`bin/bin/vault/hoard-lib.sh`, which cannot exist. Both candidates missed, the loop ended,
`YMIR_HOARD_LIB_LOADED` was never set, and **nothing was raised.** The script walked on into four
`hoard_*_dir: command not found` lines and then died on `YMIR_SETTINGS_DIR: unbound variable` —
inside a seat launcher writing to a tmux scrollback nobody reads, while the record said it launched.

That is the defect `register.md` already recorded as *"the harness is being selected by a flag
rather than provisioned, and the container is never bound to the Yggdrasil worktree."* This is a
mechanism for it, found and fixed.

### Fix

- **`.pi/extensions/eindri.ts`** — `run()` now coalesces the null (`(out ?? "").trim()`), and a
  throw with **no exit status** (a `TypeError`, or a process killed by a signal) is no longer
  laundered into an exit code: it is returned as `rc: 1` with its own message, distinguished from
  a command that genuinely exited non-zero.
- **`bin/model/local-model-lock.sh`** — the correct candidate `$SCRIPT_DIR/../vault/hoard-lib.sh`
  is now tried first, and **a home that cannot be resolved is a refusal** (`exit 127`, with the
  path it looked in) rather than a shrug that continues into four unbound variables.
- **`bin/agents/einherjar-spawn.sh`** — **one identity, or a refusal.** Overrides may *move* the
  house; they may never *split* it. Each `BROKK_*_OVERRIDE` was honoured on its own, so setting
  only `BROKK_STATE_OVERRIDE` produced a `STATE` from one root while `DATA`, `CONFIG` and
  `WT_ROOT` still resolved from another. That is exactly how errand `dag-runes-p1` came to own
  **two** registered Yggdrasil worktrees, with the task record naming one and the worker seated in
  the other — so `--relaunch` and `start` disagreed about what existed. The three derived bases
  must now agree, or the spawn refuses with the three paths printed.

### A correction to what I first believed

Brokk reported this as "`ROOT` resolves one level short — a path bug". **That was wrong**, and the
correction matters more than the fix. `ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"` is `<repo>/bin`,
which is the long-standing **engine root** — the brief lives at `<root>/data/<id>/brief.md` and the
worktree at `<root>/.yggdrasil/<id>`, and the running seat writes its status there. It is not a
defect; renaming or "correcting" it would have moved live paths under a running errand.

The real defect was narrower and is the one fixed above: **the identity could be split by the
caller.** `ROOT` was never the bug. Recording this because a wrong diagnosis shipped into a fix
note is how the next reader inherits the error.

### The law this earns

> **A resolver that fails to load must fail loudly, and a caller must never report a verdict it did
> not receive.** Both halves of this note are the same law: silence shaped like success is the one
> failure mode that survives review, because every reading of the output says it worked.

### Verified

- `npx tsc --noEmit` on `eindri.ts` — clean.
- `bash bin/model/local-model-lock.sh check` — resolves the home and answers
  `local-model-lock[1]{check,slots,used,state}: "free",1,0,"go"`, where before it printed four
  `command not found` lines and exited non-zero.
- `einherjar-spawn.sh` split-house refusal — `BROKK_STATE_OVERRIDE` set alone now exits **1** and
  prints all three paths; `BROKK_HOME` set alone passes the guard and proceeds normally.
- `eindri-control.sh exit dag-runes-p1` — the corpse seat was stopped through its own door.
- **Not verified:** the errand tool itself still needs a session restart before the new return path
  reports a true verdict — the running pi process loaded the old extension. The spawn it made after
  the fix **did** succeed (the seat was verified alive in `bin/.yggdrasil/dag-runes-p1`), which is
  what proved the old `rc=1` was the lie rather than the truth.

### Blast radius

One file for each fix. `grep` for `stdio: "inherit"` across `.pi/extensions/` returns two sites:
this one and `open-editor.ts`, which uses `spawnSync` and reads `result.status` — never
`result.stdout` — so it is unaffected. Every other `.trim()` in the tree is reached with piped
stdio, where the return really is a string.