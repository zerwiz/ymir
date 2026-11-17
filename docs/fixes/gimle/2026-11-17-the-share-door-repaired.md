# The share door stopped its 40,001st restart — a symlink into a tree that is gone, and a port that was never its own

**Component:** `gimle` (the share door, `gimle-share.service`, and the whiteboard's four surfaces).
**Date:** 2026-11-17. **Plan:** `hodd/machines/example-heart/plans/005-the-blunt-loop.md` (§2 and §3).

## What was wrong

`gimle-share.service` had restarted **39,999 times** (39,803 when the plan was written; it gained 196 in the
hours between). Every five seconds, since long before today, and the reason was in one line of the journal:

```
/usr/bin/python3: can't open file '/home/example-heart/gimle/desk/share-scene.py':
[Errno 2] No such file or directory
```

The file was a symlink — and so was the kit's own copy under `~/gimle/systems/desk/` — into
`~/gimle/src/ymir/bin/gimle/`, a tree that no longer exists. Both links resolved to nothing (empty `readlink -f`).

The unit also asked for **`:8490`**, the mail desk's number. Measured on the day: `gna-desk` listens on `8494`
(it moved there on 2026-11-06), `gimle-brokk` on `8492`, and 8490 was free but *owned by name* — two doors,
one number, which is a collision waiting for the next restart of either.

## What was changed

| Change | Where | Why |
|---|---|---|
| Both symlinks repointed at the pinned runtime | `~/gimle/desk/share-scene.py`, `~/gimle/systems/desk/share-scene.py` → `~/ymir-runtime/bin/gimle/share-scene.py` | the kit's deployed code is the pin, the same road `desk.py` already took; the kit's own copy and the ymir tree's carry identical bytes (sha256 `90acff65…`) |
| The port moved to `8488` | the unit, the registry row (`services.yaml`, `id: share`), the tunnel's `/share.*` ingress | one number, named once, and not the mail desk's |
| The code's default stopped being a landmine | `bin/gimle/share-scene.py` — `--port` defaults to `$GIMLE_SHARE_PORT`, else `8488` | a default that is another door's number is how this started |
| The loop can no longer run forever | `StartLimitIntervalSec=300`, `StartLimitBurst=5`, `RestartSec=10` | a door that cannot start says so once and stops; five-second respawns for a year is noise holding a port |
| The deploy probe follows the door | `bin/gimle/deploy.sh` probes `:8488 /health` | a deploy that probes the old number reports a false red |
| The status door measures units | `~/gimle/bin/gimle-status.sh`, plus `~/gimle/apps/whiteboard/units.txt` | "whiteboard — no compose file" was a red that was never measured |
| The room server writes its scenes down | drop-in `excalidraw-collab.service.d/10-snapshots.conf` → `COLLAB_SNAPSHOT_DIR=~/gimle/data/whiteboard/rooms` | `snapshots.enabled` was `false`: a scene lived in memory only and a restart emptied every room |

## The proofs, quoted

Stopping the loop — the counter is gone because the unit is not starting any more, and a quarter-hour of
silence follows:

```
$ systemctl --user disable --now gimle-share.service
Removed "/home/example-heart/.config/systemd/user/default.target.wants/gimle-share.service".
$ systemctl --user show gimle-share.service -p NRestarts --value   # before: 39999 · after: 0
0
```

The script parses, from the path the unit runs:

```
$ python3 -c 'import ast,sys; ast.parse(open(sys.argv[1]).read()); print(sys.argv[1], "parses")' \
    /home/example-heart/gimle/desk/share-scene.py
/home/example-heart/gimle/desk/share-scene.py parses
```

The door answers on its own number, and the ward still refuses what it should:

```
$ curl -s http://127.0.0.1:8488/health
{"status": "ok", "server": {"name": "gimle-share", "version": "0.1.0"}}

$ curl -X POST http://127.0.0.1:8488/share -H "Authorization: Bearer <token>" -d '{"scene":"eindri-proof-20261117",…}'
{"ok": true, "scene": "eindri-proof-20261117", "owner": "zerwiz", "path": "…/shared-scenes/zerwiz/eindri-proof-20261117.json"}

$ curl -o /dev/null -w '%{http_code}' -X POST http://127.0.0.1:8488/share -d '{"scene":"anon-probe"}'
401

$ tail -1 ~/gimle/desk/data/access.jsonl
{"at": "…", "subject": "zerwiz", "tool": "share_scene", "action": "share", "verdict": "allowed", "why": ""}
```

The public road reaches the door rather than a dead port (`whiteboard-ai.zerwiz.org/share` is the tunnel's
`/share.*` ingress; with no identity it is refused *by the door*, which is a 401 and an audit line, not a 502):

```
$ curl -o /dev/null -w 'http=%{http_code}\n' -X POST https://whiteboard-ai.zerwiz.org/share -d '{"scene":"public-probe"}'
http=401
```

The whiteboard's four acceptance points, on the live doors:

```
$ node bin/gimle/whiteboard-acceptance.mjs --socket-io …/socket.io-client
PASS     1 scene survives a reload — the room handed 24 identical bytes back to a fresh client
PASS     2 two clients see each other — the room listed 2 members at once · the second hand received 40 bytes
PASS     3 the bridge answers a prompt — http=200 · 5 frames · data: {"type":"content","delta":"flowchart T"}
PASS     4 a scene is shared out and audited — http=200 subject=zerwiz audit lines 154→155 at …/acceptance-…json
ACCEPTANCE green — every point answered
```

And the point a reload cannot prove — a scene coming back from **disk** after the process is gone:

```
$ node whiteboard-acceptance.mjs --room disk-proof-1 --store "the scene the disk is supposed to keep"
stored   room "disk-proof-1" with 38 bytes
$ systemctl --user restart excalidraw-collab.service && sleep 3
$ node whiteboard-acceptance.mjs --room disk-proof-1 --expect "the scene the disk is supposed to keep"
PASS     1 scene survives a reload — room "disk-proof-1" handed back 38 identical bytes (iv 00000000)
```

The status door, before and after:

```
before:  whiteboard             no compose file
after:   whiteboard             up (units: excalidraw-app.service=active excalidraw-board.service=active
                          excalidraw-bridge.service=active excalidraw-collab.service=active )
```

## What this does not claim

**The browser's Share button is not proved.** The door's own docstring expects `Remote-User`, asserted by a
proxy in front of it (Authelia-`forward_auth`, as the whiteboard's proxy already does for the app). The tunnel
routes `/share.*` straight at the door, so a browser POST carries no `Remote-User` and no token — and the door
refuses it, correctly, with a 401 and an audit line. A share from the panel therefore still needs either a
proxy in front of the door or a token in the app; both are wiring decisions, and the second one is the
Allfather's (who may share).

**The board shelf is still off.** `saves.enabled` is `false` with its reason in `/healthz` ("the board shelf is
unset — `/saves` refuses rather than writing a board somewhere arbitrary"). Turning it on is one env line, but
it was not proved in this errand, so it is not claimed.

**The share door's number is on the heart, not in the pin.** `share-scene.py`'s new default takes effect where
the pin is next fast-forwarded; the live unit names `--port 8488` explicitly, so the door is right today either
way.

## CHANGE LOG

- 2026-11-17 — review-mend: added missing heading for #814
