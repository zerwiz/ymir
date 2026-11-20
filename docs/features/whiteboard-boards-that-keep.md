# A whiteboard that keeps its board

Two things used to be true about the whiteboard, and both cost an evening's work.

A board lived only in the live session. When the last person closed the tab, the drawing was
gone — nothing on any disk held it. And there was no way to say *this board is mine*, so even if
something had been stored, there would have been no answer to who may open it.

Both are fixed on the server. The visible buttons live in the drawing app itself, which ships as a
built bundle, so they arrive separately; what follows is what is already working underneath them.

## What you get

**A room is written down while you draw.** The server saves the room's scene to disk on a cadence,
when the last person leaves, and if the service stops. A snapshot is never overwritten: a later one
supersedes an earlier one, and the time is in the file name.

**A saved board belongs to you.** The owner is the identity the gate asserts when you sign in —
never something the browser sends. So the list you see is your own boards, and asking for someone
else's is refused with a sentence: *that save is not yours*.

**The assistant can talk before it draws.** Ask it what you are trying to do, answer its questions,
and only then ask for the diagram. It holds seven tools, all of them the whiteboard's own — it can
read the canvas, place shapes, move what it just placed, check its own diagram, frame a region, save
the board, and produce a share link. It cannot reach your mail, your files, the plan ledger or the
internet.

**When the model is out of quota, it says so with a time.** Instead of a bare "error", you get a
sentence like *the model's usage limit is reached. It resets in 2 hours 15 minutes (at 02:40) — ask
again after that.*

## What you need

Nothing new to use the board: the gate login you already have is what names your saves. The
assistant needs the bridge running, which reads its model key from
`~/.config/ymir/whiteboard-bridge.env` on the machine that serves the board.

## The commands

```bash
# is the room server keeping scenes? one line at start names every store and its state
curl -s http://127.0.0.1:7312/healthz

# which boards does the gate say are mine?
curl -s -H "remote-user: <your gate name>" http://127.0.0.1:7312/saves

# is the assistant's bridge up, and what may it hold?
curl -s http://127.0.0.1:7313/healthz
```

## Where a board is kept

| What | Where |
|---|---|
| A room's snapshots | `$YMIR_HOME/life/boards/_rooms/<room>/<stamp>.scene.json` — or, where the server runs with no
`YMIR_HOME` (the heart), the shelf the registry names for the whiteboard: `~/gimle/data/whiteboard/rooms/<room>/` |
| Your saved boards | `life/boards/<your gate name>/<room>-<stamp>.excalidraw` |
| The ledger of every save, list and open | `hodd/memory/runes_audit.md` |
| The audit line for every shared or refused scene | `~/gimle/desk/data/access.jsonl` (the share door's own record) |

Snapshots are the room's encrypted bytes, exactly as the browser sent them. That means nothing on
this machine can read a saved room without the room key — including the operator. A board you saved
by hand is the app's own JSON and opens in the app directly.

## Limits

A snapshot is superseded, never deleted: the shelf grows. A save is likewise append-only, and there
is no delete — retiring one moves the file rather than removing it.

A guest who arrives by a link has no gate identity, so a guest cannot own a save yet. That is a
decision to make deliberately, not a default to inherit.

Snapshotting is a cadence, not a per-stroke history: at most one write a minute per room, plus one
when the last person leaves.

## If it does not work

Ask the room server. `GET /healthz` returns one object naming whether snapshots are on and where
they go, whether the board shelf is configured, which header it trusts for identity, and whether a
Runes door was found. A store that is off says why in a sentence; a store that is on but silent is
the fault to chase.

If the assistant answers with the Mermaid error text still, the panel is calling the old route:
`generate` is unchanged on purpose, and the conversation lives at
`/v1/ai/converse/chat-streaming`.

If a save is refused and the board is genuinely yours, the gate did not assert your name. Check
`GET /healthz` for the header it reads, and confirm your proxy sets it.

**The four points, as a command.** `node bin/gimle/whiteboard-acceptance.mjs` speaks to the running doors and
prints one `PASS` or `UNPROVED` line per point: a scene survives a reload, two clients in one room see each
other, the bridge answers a prompt, and a scene is shared out through the share door with an audit line. Pass
`--room` with `--store` then `--expect` around a `systemctl --user restart excalidraw-collab` to prove the scene
came back from **disk** rather than from memory. `--socket-io <dir>` points it at a machine's copy of
`socket.io-client`, which is the room server's dev dependency and not always on the default path.

## CHANGE LOG

- **2026-11-17** — measured on the heart: the room server had **no** snapshot shelf configured
  (`COLLAB_SNAPSHOT_DIR` unset), so a scene survived a browser reload only because it was still in memory, and every
  restart emptied every room. A drop-in now writes to `~/gimle/data/whiteboard/rooms/`; proved by storing a scene,
  restarting the service, and receiving the same bytes back. The share door's number is `8488` (it was asking for the
  mail desk's 8490 and had restarted 40,000 times against a symlink into a deleted tree). `~/gimle/bin/gimle-status.sh`
  measures the whiteboard's four units instead of reporting "no compose file". The table and the commands above carry
  the corrections.

- **2026-11-14** — written with the server half: the snapshots, the owner-asserted saves, the
  converse mode, the wall in words, and the bridge's unit. The buttons in the drawing app itself
  (Save to server, the sessions list, the assistant panel, the wider quick palette) arrive with
  the next app build, because that surface ships as a compiled bundle.
