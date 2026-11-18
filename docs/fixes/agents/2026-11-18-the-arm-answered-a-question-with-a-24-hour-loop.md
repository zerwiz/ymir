## agents · 2026-11-18 — the arm answered a question with a 24-hour loop

### Why
A hand asked `bin/agents/eindri-arm.sh --help` for its usage. The script had no `--help`: whatever
arrived first became the errand id, so `--help` was claimed as an errand, `state/--help.arm` was
written, and the `while :` cycle held the caller's turn for the full 24-hour TTL. The turn died
unanswered — the Allfather asked three questions into a session that could not speak, and the
worker it was about finished into silence.

The fault is a class, not an accident: any door that owns a long poll loop can swallow a hand that
only wanted to read it. So the fix is two-sided.

**The door answers first.** `eindri-arm.sh` now handles `-h|--help` and `--version` *before* it
claims anything, refuses any `-…` argument as "not an id" with exit 2, and carries `--once` (one
cycle, then exit) for a caller that must not block.

**The class is warded.** `bin/gates/guards/blocking-door-guard.sh` fails any tracked script that
holds a `while :` / `while true` loop without either an `-h|--help` branch before the loop or a
declaration in its first 40 lines:

```
# blocking-door: daemon — started by a unit, and it runs the loop as its job; never invoked from a hand
# blocking-door: library — sourced by a caller that owns the loop and bounds it; never run by hand
```

It runs in every pre-push and in CI (`guards.sh --full`). Forty-one scripts were judged when it was
first armed: eight doors gained a help branch, the rest are libraries and daemons that now say so.

### Files
- `bin/agents/eindri-arm.sh`
- `bin/gates/guards/blocking-door-guard.sh`
- `bin/gates/guards.sh`
- and the 41 doors and libraries the ward judged (help branch added, or a `# blocking-door:` line).

### Proof
```
bin/agents/eindri-arm.sh --help        # usage, exit 0, no arm claimed
bin/agents/eindri-arm.sh --bogus       # exit 2: "a flag can never name an errand"
bin/gates/guards/blocking-door-guard.sh --scan   # 0 findings
```

### CHANGE LOG
- 2026-11-18 — written with the fix, after a turn was lost to `eindri-arm.sh --help`.
