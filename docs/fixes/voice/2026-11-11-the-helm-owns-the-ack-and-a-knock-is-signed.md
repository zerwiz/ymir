# The helm owns the ack, and a knock is signed

**Date:** 2026-11-11 · **Component:** voice / arm (`bin/time/saga-wake-drain.sh`, `bin/voice/rodd-arm.sh`)

## What was wrong

1. **Any session could acknowledge the home's wake queue.** The Allfather told the arm holder (a Claude
   session holding the Gleipnir lock) to call every herdr agent and have them answer *over the arm*. Two
   other Claude sessions on the same machine still ran a pre-#636 Stop watcher with no helm check, so a
   wake meant for the arm holder also rewoke them — and `saga-wake-drain.sh ack` let either of them drop
   the helm's wakes from the queue.
2. **Every knock was signed "Rödd (the voice)".** Nine agents answered the roll-call through
   `rodd-arm.sh tell`, and each wake arrived under the same name; only the text told them apart.

## The fix

- `saga-wake-drain.sh ack` refuses (exit 3, with the owner's pid and the door to use instead) when the
  lease names this state dir, a live session holds the lock, and the caller is not that session
  (`ymir-state.sh lock owned --shell-pid $$`). Eindri-homes keep their own state dirs and are untouched;
  `YMIR_ACK_ANY=1` is the loud override. `drain` (read-only presentation) is unchanged.
- `rodd-arm.sh tell --from <name> "<text>"` (or `RODD_FROM`) signs the knock; the default stays Rödd.

## Proven

- As the helm (the lock owner's shell): `ack` → `acknowledged`, rc 0.
- From a detached process outside the helm's tree (`setsid -f`): `ack` → `error: the arm is held by
  session 2478704 …`, rc 3. A first cut matched the lease with `grep -x`, which never fires because the
  lease is one space-separated line; it now matches `state=<dir>` as a field.
- `rodd-arm.sh --self-test`: 38 passed, 0 failed.
