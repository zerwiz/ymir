## agents · 2026-11-20 — the watch extension stops writing the lock

### Why

The Pi watch extension (`.pi/extensions/gna-pi-watch.ts`) was the **second writer** of
`brokk.lock`, and its rule for taking the helm from another session was the road by which
a live helm lost the arm on 2026-11-20:

```ts
// before
if (!/^[0-9]+$/.test(childPid)) return "missing";   // no verifiable supervisor
if (!pidAlive(childPid, "")) return "missing";      // supervisor gone — reclaim it
```

`lockOwnership()` answered **"missing"** — "the helm is vacant, take it" — whenever
`<lock>.child` named no pid or a dead one, even though the lock's owner was alive and
well. A claude helm never writes `.child` at all, so the next pi that booted reclaimed a
live claude's helm. That is the measured transition at 01:05, and the dead `.child` on
this seat has been `1591446` (a pid from 2026-11-12) for eight days.

`reclaimStaleLock()` then wrote `brokk.lock` and `brokk.lock.starttime` itself, with no
guard and no record — the same silence in a second place, and the reason a reader could
catch a new pid beside a stale starttime.

### What changed

- **The `.child` steal is gone.** A live owner is `other`, full stop: the arm changes hands
  when it is released or when its owner dies. `.child` is still written as information and
  decides nothing. (The 2026-10-03 fault it was written for — an idle window holding the
  helm with a dead arm child — is now covered by the hand-over record and the session
  start's free-arm guard, not by taking a live process's lock.)
- **No lock writes left in the extension.** Both `reclaimStaleLock()` and
  `releaseLockIfOwned()` now call the ONE implementation, `bin/records/ymir-state.sh lock
  acquire|release`, with `BROKK_SESSION_PID` and `BROKK_MACHINE_STATE_DIR` set so the door
  resolves exactly the lock the extension resolved. A door refusal means a live session
  holds the arm, and the session stands read-only — it never writes the lock anyway.
- **The hand-over is recorded and announced**, because the change now happens inside
  `lock.py` (`docs/fixes/runtime/2026-11-20-the-arm-is-never-lost-without-a-word.md`).

### Files

- `.pi/extensions/gna-pi-watch.ts`
- `bin/seat/tests/test_arm_never_lost.sh` — asserts, by source and by behaviour, that the
  extension writes no lock, that it takes a vacant helm through the door, and that the
  `.child` steal rule is gone.

### Proved

`bash bin/seat/tests/test_arm_never_lost.sh` → `49 passed, 0 failed`. A live owner with no
`.child`, and a live owner with a DEAD `.child`, both keep the arm; a second live session is
refused and the lock file is byte-identical afterwards.

> [!IMPORTANT]
> The live proof is owed: this fix reaches the running helm only when the pin is built from
> a merges that carries it (`bin/engine/release.sh build --ref main`, then `flip`). Until
> then the live extension is still the old one.

## CHANGE LOG

- 2026-11-20 — filed with the errand `arm-never-lost`.
