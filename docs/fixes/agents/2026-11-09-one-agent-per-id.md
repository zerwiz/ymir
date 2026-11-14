## agents · 2026-11-09 — one agent per id, and the guard that says so

### The fault, in one line

A spawn that fails **after** the engine has launched a pane leaves that agent alive. Retrying then put a second agent in the same
worktree — and herdr will happily run both. Seven agents ended up alive for three tasks: `rodd-hands` in three panes, `context-left`
in two, `fix-order` in two, two of them standing on worktrees that no longer existed.

### Why nothing caught it

Nothing counted **agents**. The estate view counts ids, so two panes on one id were invisible; the sweep reports finished seats, so
two *running* seats on one id were invisible too. My own remedy made it worse: each failed seat I deleted the worktree and re-spawned,
which orphaned a live agent every time.

### The guard

Before anything is created, the spawn asks herdr whether an agent already stands in this errand's worktree:

```
refused: an agent already stands in /home/heimdall/ymir/.yggdrasil/near-loop-panel/.yggdrasil/rodd-hands
  pane: "pi","working","w49:p1",…
help: talk to it (bin/agents/eindri-send.sh rodd-hands "…"), or close that pane first.
note: a second agent in one worktree overwrites the first — the 2026-11-09 audit.
```

It matches on the worktree path, ignores panes already marked `(deleted)`, and exits 3. A deliberate relaunch passes
`FORCE_RELAUNCH=1`, which is recorded rather than silent.

### What this does NOT fix, and is named rather than implied

- **A failed seat still leaves its pane.** This guard makes the *next* spawn refuse; it does not reap the ghost. The engine should
  close what it started (audit link 3).
- **`worktree.ensure()` still creates a tree the launcher refuses** — the reason the seating dance existed at all.
- **Status is still written at launch, not derived from liveness** — three dead agents read `working` tonight.

### Verified

`bash -n bin/agents/einherjar-spawn.sh` — syntax clean; the guard evaluates against the live estate and exits 3 when a pane claims
the id.

## CHANGE LOG

- **2026-11-09** — Carved: the duplicate-spawn guard, with the three neighbours it does not cover named.

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: a dev machine (this seat). The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).
