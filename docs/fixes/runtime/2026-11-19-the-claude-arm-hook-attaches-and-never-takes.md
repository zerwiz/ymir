# The Claude arm hook attaches; it never takes the helm

**Date:** 2026-11-19 · **Component:** runtime · **Doors:** `bin/pi/syn-watch-arm.sh`, `.claude/hooks/ymir-arm.sh`,
`bin/gates/checks/claude-stop-arm.sh`

## What was wrong

The global Claude Stop hook (`~/.claude/hooks/ymir-arm.sh`) ran `bin/pi/syn-watch-arm.sh --restart`. That client
enters a VACANT helm by design. A Stop hook runs at every turn end, so any Claude seat became the primary whenever
it found no live owner. Measured on 2026-11-19: the lock went from 2243828 to 1557290 at 03:02 while 2243828 was
still alive.

The installed copy had been patched by hand with an owner test. The template the installer copies
(`.claude/hooks/ymir-arm.sh`) had not, so the next install or update would have put the fault back.

## What was forged

- `syn-watch-arm.sh` has an **attach-only** contract: `--attach-only` (or `BROKK_ARM_ATTACH_ONLY=1`). It attaches
  when this session already holds the helm, and exits 0 otherwise. It never acquires, not even a vacant helm. The
  check runs before the catch-up sweep and the seat reap, so a non-holder touches nothing.
- The template hook carries the owner test and runs the client with `--attach-only`. The owner test stays as a
  guard for an older pin whose client predates the flag.
- The house's project Stop hook (`claude-stop-arm.sh`) passes `--attach-only` too.
- Taking the helm stays a deliberate act: `bin/voice/rodd-arm.sh hold`.

## Proof (measured, fenced state)

Session A holds the lock; session B runs the hook's client. Then A dies and B runs again on a vacant helm.

```
owner before: 3458771  (A=3458771, B=3458772)
watcher: attach-only - this session does not hold the helm (owner=3458771); nothing taken
B attach-only rc=0
owner after B attach-only: 3458771
watcher: attach-only - this session does not hold the helm (owner=3458771); nothing taken
B attach-only on a vacant helm rc=0
owner after vacant + B attach-only: '3458771' (must not be 3458772)
```

## CHANGE LOG

- **2026-11-19** — written with the change it describes.
