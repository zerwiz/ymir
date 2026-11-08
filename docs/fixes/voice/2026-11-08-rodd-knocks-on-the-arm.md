# Rödd knocks on the arm — `bin/voice/rodd-arm.sh`, and two hands in the voice

**Date:** 2026-11-08 · **Plan:** 223 — *Rödd speaks to the arm holder* · **Law:** `RULES/06-append-only.md`,
`RULES/07-config.md`, `RULES/25-agnostic-by-construction.md`, `RULES/39-the-manner.md`

## What was wrong

Rödd could **do** things — it had `search_home`, `ls`, `read`, `edit`, `bash`, `mcp` and `hand_over` — but
it could not **knock**. It drives its own pi session (`apps/rodd/src/main.js` spawns the engine's server and
the engine drives its own agent), so the one mind that plans, drains wakes and dispatches errands was
unreachable from the voice. Two sessions, no wire.

The house already had the wire: the **arm lease** (`$YMIR_HOME/state/.arm.lease`, whose `state=` names the
queue the arm actually drains) and the **durable wake queue** (`bin/time/brokk-wake-lib.sh`,
`src/ymir_runtime/state/queue.py`, drained by `bin/time/saga-wake-drain.sh`). What was missing was a door with
a refusal in it, and a shelf for the answer.

## What was built

**`bin/voice/rodd-arm.sh`** — one door, six verbs:

```
who · tell <text> · hear [n] · room · --check · --self-test
```

- **`who`** resolves the lease and prints one TOON block: holder pid, gen, mode, session, **the state dir the
  lease names**, the heartbeat's age and the stale threshold. A missing lease, a dead pid, a **reused** pid
  (starttime mismatch, `/proc` field 22), a heartbeat older than `BROKK_WATCH_HEARTBEAT_STALE_SECONDS`
  (default 60 — the watcher's own number, not a second one) or a `state=` that is not a directory all print
  `no arm is held` and exit **3**.
- **`tell <text>`** appends a wake of kind `signal`, key `rodd-<epoch>` (a suffix when a second message lands
  inside the same second), payload `Rödd (the voice) to the arm holder: <text>`, into `<lease state>/.wake-queue`
  — through `bin/records/ymir-state.sh queue append`, the module's own lock and line format, never a second
  implementation. It **refuses** (exit 3) with no arm held, and writes nothing.
- **`hear [n]`** reads `<lease state>/rodd/room.jsonl`, prints the unread replies, and advances a **byte
  cursor** (`rodd/.cursor`) — the room is never truncated, so a reply is never destroyed by being heard, and a
  limited read stops at the first unprinted line.
- **`room`** says where the room is and how many lines it holds; **`--check`** prints the one-line verdict.

**Rödd's hands.** `bin/voice/voice_tools.py` gains `talk_to_arm` and `hear_from_arm` (its real tool shelf —
`TOOLS` + `NEW_TOOLS`, so the smoke suite judges them by name), and `apps/rodd/src/main.js` gains the prompt
that names them plus the voice rule: hand a message over only when the door returned `delivered=yes`, read an
answer only from `hear_from_arm`, and say **"the arm has not written back yet"** rather than "sent" or "done".

## The three laws these hold, and why each was paid for

1. **The lease is the authority, not a path.** The house recorded on 2026-11-05 that two `state/` shelves
   exist on both seats and only the one in `.arm.lease` (`state=`) is read. A door that hardcodes a state dir
   reaches a session that is not armed — the exact false green this house keeps buying.
2. **One writer per file.** The arm writes `rodd/room.jsonl`; Rödd reads it and writes only its cursor. Room
   collisions cost three hours on 2026-11-05 (plan 188 §14–16).
3. **A green must be earned by a door.** `delivered=yes` is only printed after the queue append returned 0; a
   refusal exits 3 and writes nothing, so the voice cannot report a message it did not hand over.

## Verified

```
bin/voice/rodd-arm.sh --self-test       → 38 passed, 0 failed
bin/voice/tests/test_rodd_arm.sh        → 28 passed, 0 failed
```

The test proves, with commands: no lease → `who` 3 and `tell` REFUSES with no queue written; a dead pid and a
stale heartbeat are not arms; a live lease names its own state dir; `tell` lands one line with kind `signal`,
key `rodd-<epoch>`, the text intact and tabs flattened; a second and third `tell` never overwrite the first; a
lease naming an absent state dir is refused and the directory is **not** created; `hear` reads a reply the arm
wrote, leaves the room byte-identical (`cksum`), advances the cursor, and does not repeat a heard reply.

The live seat was measured, not assumed: `rodd-arm.sh who` on this box returned pid `1405`, gen `29`, mode
`systemd`, state `…/ymirhome/state`, heartbeat age `2 s`. Both hands were then called through
`voice_tools.execute_tool` against a synthetic lease and answered correctly — `hear_from_arm` (nothing yet,
then one reply), `talk_to_arm` (delivered, one queue line).

**Local-only.** The work sits on `eindri/rodd-arm`; no PR was opened (mode `local-only`).

## CHANGE LOG

- **2026-11-08** — the door, the two hands, the tests and the page. Plan 223.
