# The watchdog that never woke — an armed condition that always errored

**2026-10-24.** Component: `bin/agents/eindri-watch.sh` (arm-silence), `bin/agents/eindri-heartbeat.sh`.

## The fault

Every errand is supposed to be watched: `einherjar-spawn.sh` arms a silence watch, and if the worker stops
writing for the window (default 1800 s) the watch fires and wakes Brokk. The arm was:

```bash
--condition bash "$SCRIPT_DIR/eindri-heartbeat.sh" "$name" --window "$window"
```

`eindri-heartbeat.sh` has verbs — its own help is `eindri-heartbeat.sh check <agent> [--window N]`. Called without
the verb it answers, on every evaluation:

```
error: agent id required
help: bin/agents/eindri-heartbeat.sh check <agent> [--window N]
```

and exits **2**. A non-zero exit is "the condition is not met", so the watch never fired. It could not fire: the
condition was malformed from the day it was armed.

## The evidence

- `eindri-watch.sh list` showed `when-clients-128-silent · pending 0` — armed, waiting.
- The specs existed (`state/procevent/when/when-*-silent.spec`, 149 entries in that directory), so arming worked.
- `bash bin/agents/eindri-heartbeat.sh reachable-126 --window 1800` → `exit 2, "error: agent id required"`.
- With the verb added, the same call answers truthfully: `"reachable-126","terminal","6764"` → exit 1 (silent).
- Consequence, measured: **18 errand statuses said "working" while nothing ran**, the oldest by 719 hours.

## The fix

```bash
--condition bash "$SCRIPT_DIR/eindri-heartbeat.sh" check "$name" --window "$window"
```

Proven in the same minute: `eindri-heartbeat.sh check reachable-126 --window 1800` returns a verdict and exit 1
(silent) instead of a usage error.

## Owed, and why it matters more than the one line

1. **Arming is still best-effort.** `einherjar-spawn.sh` calls `arm-silence … >/dev/null 2>&1 || true`. A silence
   watch that cannot be armed must fail the spawn — a seat without a watchdog is exactly what this incident was.
2. **A condition's exit code must be audited.** Exit 2 means *error*, not *false*: the runner should treat
   "condition errored" as a fault to report, never as "nothing to do". This one bug hid for weeks behind that
   conflation.
3. **The watch needs a self-test**: arm a fake errand, force its status old, and assert the wake fires. Without it,
   the next malformed condition is invisible again.

## How to see it

```bash
bin/agents/eindri-watch.sh list | grep silent        # what is armed
bin/agents/eindri-heartbeat.sh check <agent> --window 1800 ; echo $?   # 0 fresh · 1 silent · 2 error
```
