## seat · 2026-11-17 — a spawn says which authority it used

### What was wrong

`bin/seat/herdr-run.sh` and `bin/agents/einherjar-spawn.sh` seated workers without asking whose right it was to act on this machine. A hand that acts on nothing is how a supervisor came to hold an arm with no mind behind it.

### What the doors do now

Both doors ask the lease door **before** they create anything, print the answer as a row, and are refused when it is `none`:

```
authority[1]{verdict,source,scope,machine,detail}:
  "granted","lease","ymir","heimdall","lease 3 — arms-and-crown on heimdall, scope ymir, 2 hand(s), 58m left, heartbeat 2s"
```

The authority is the narrower grant first — a **lease** for this project — and then the **machine arm**, which is an authority only when a hand that can speak is behind it: the session asking, the machine's own hand, or (named as borrowed) a speaking harness elsewhere on the box. An arm held by a watcher grants nothing when no harness on the machine can speak, and the refusal says exactly that.

A **refused** spawn exits 3 and launches nothing: no worktree, no pane, no state file. The refusal names the reason and the road out (`bin/voice/arm-lease.sh grant <scope> --holder <name>`).

`einherjar-spawn.sh --dry-run` **reports** the authority and is never refused by it: a dry run launches nothing, and the plan must stay printable on a machine with no arm (the CI of every fork is such a machine).

### Files

- `bin/seat/herdr-run.sh` (the gate, before the brief is written)
- `bin/agents/einherjar-spawn.sh` (the gate, before the engine handoff and the dry-run)
- `bin/voice/tests/test_arm_authority.sh` (new)

## CHANGE LOG

- **2026-11-17** — Opened: both spawn doors name their authority, and refuse a spawn that has none.
