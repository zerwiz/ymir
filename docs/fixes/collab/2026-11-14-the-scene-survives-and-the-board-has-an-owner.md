# The whiteboard keeps its scenes, and a board has an owner

**Component:** `collab` (the whiteboard's room server) · **Date:** 2026-11-14 · **Tickets:**
`feature-0033`, `feature-0036` (the server half) · **Contract:** plan 158 §appended, 2026-11-13.

## Why

Two people were drawing on the board in one evening — two people — and his words
were *"we need to store what we have"*. There was nothing to store it in. A room lived in the
collaboration session and nothing on disk held it, so the board was gone when the last tab
closed. The server's own README says it plainly: *"a room is not a database"*.

And a board that could be saved had no answer for **whose** it is. His word on that was the whole
design: *"needs to be stored on the users that made it from the gimle login. so not all users can
reach all saves."*

## What changed

**The scene is written down.** `snapshots.mjs` keeps one file per room per save, the stamp in the
name, append-only: `20261114T002534.123Z.scene.json`. The server writes on a cadence, on the last
client leaving, and on shutdown. The file is the scene's ciphertext beside its iv — exactly the
buffer pair the server would replay from memory — so the server still reads nothing, and a room
restored from disk behaves identically to a room restored from memory.

**A save has one owner, decided by the gate.** `identity.mjs` reads the header the proxy sets and
nothing else; `saves.mjs` writes `hodd/life/boards/<identity>/<room>-<stamp>.excalidraw`, mode 600,
never overwriting. Three doors — `POST /saves`, `GET /saves`, `GET /saves/<id>` — rule on that
identity. Another person's save is refused **by name**, with `reason: not-yours`, because an empty
list reads as *you saved nothing* and that is a lie. An anonymous request cannot own a board at all.

**Every door carves a Rune.** Save, list, open — and a refused open, because a refusal is an action
and the person whose board it was is owed a record that somebody asked. The line carries identity,
save id, room and time; never a scene.

## The fault found in the proof, and it was ours

The first version restored a room from disk by calling `store.join` a second time to fetch the
scene. That made the joining socket **not** the first member, so the server took the protocol's
"ask a peer for the scene" path — and there was no peer. The scene sat on disk and nobody ever
received it: a proof that would have passed a file-existence check and failed every real joiner.
The fix is one line of intent — restore into the store, then read with `getScene`, never re-join.

## Verified

Two commands, both on a scratch store, neither touching the running board:

```
node systems/whiteboard/services/collab/test/prove-live.mjs
  snapshot on last leave  room=proveroom0001 files=1 20261113T222446.345Z.scene.json
  GET  /saves/id as reygan  403 reason=not-yours "that save is not yours — a board belongs to the person who saved it"
  joiner after restart      heard=first-in-room+client-broadcast bytes=12 same-scene=true same-iv=true
  runes carved              5
  RESULT: proven

cd systems/whiteboard/services/collab && npm test
  # tests 21   # pass 21   # fail 0
```

The proof starts the real server twice: it draws, leaves, is killed with `SIGTERM`, is started
again with nothing in memory, and a joiner receives the twelve bytes it drew before, byte for byte.

## Not done, deliberately

- The **Share dialog** listing snapshots, and the **Save to server** button, are the app's own
  surface: they need the upstream source forked and built (ticket 0036's UI half). The doors are
  built first so that UI has something true to call.
- A **guest** has no hall identity, so a guest's save has no owner to inherit. That is ticket
  0034's decision, made deliberately rather than defaulted.

## Files

- `systems/whiteboard/services/collab/snapshots.mjs` — new: the append-only scene store and its writer
- `systems/whiteboard/services/collab/saves.mjs` — new: the board shelf, owner-asserted
- `systems/whiteboard/services/collab/identity.mjs` — new: the one header, and every refusal
- `systems/whiteboard/services/collab/runes.mjs` — new: one line per door, through the house's writer
- `systems/whiteboard/services/collab/index.mjs` — the join restores from disk; the three save doors; snapshots flushed on leave and on stop
- `systems/whiteboard/services/collab/test/*.test.mjs` — the unit truths
- `systems/whiteboard/services/collab/test/prove-live.mjs` — the restart proof

## CHANGE LOG

- 2026-11-13 — review-mend: added missing heading for #729

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: a person the house meets. The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).
