# bridge · 2026-11-23 — a seat reaches the heart's record doors over ssh

## What was wrong

On every seat that is not the heart, three MCPs were dead:

| Door | Symptom on a dev seat |
|---|---|
| Bölþorn (skills, `:8319`) | the gateway reported `upstream.bolthorn  unreachable` and served a stale catalog |
| Skuld (tickets, `:8320`) | the gateway reported `upstream.skuld  unreachable`; writes queued in the journal and never flushed |
| Snotra (meetings, `:8321`) | the harness entry pointed straight at the heart's tailnet name and got `ECONNREFUSED` |

The cause was two correct decisions that never met. On 2026-11-12 the heart's doors were bound to loopback
(`docs/fixes/fleet/2026-11-12-the-fleet-doors-face-loopback-and-skuld-can-start.md`). On 2026-11-16 the ward began
rating an MCP that answers a tailnet peer without a token as HIGH. But the gateway still dialled the heart's tailnet
address, and Snotra was not behind the gateway at all. So a seat had no road left.

## The fix

- **`bin/bridge/heart-doors.sh`** holds one ssh connection to the heart as a user unit (`heart-doors.service`,
  `Restart=always`). It forwards each heart door to this seat's loopback on `<port> + 10000`. ssh is the
  credential, so no port is opened and nothing is widened. On the heart it is a clean skip.
- **The gateway tries that forward first** on a seat that is not the heart. The tailnet URLs stay as a fallback, for
  a heart that chose to widen its bind in `fleet.env`.
- **Snotra stands behind the gateway**, like the other record doors. It is in `RECORD_DOORS`, so every harness
  (pi, Claude Code, OpenCode, Codex, Hermes) is seated with `http://127.0.0.1:<gateway>/mcp/snotra`.
- **`fleet-ensure.sh` raises the door** on a non-heart seat, and `--check` names it when it is down.

Configuration, one default each: `HEART_DOOR_PORTS` (`8319 8320 8321`), `YMIR_HEART_DOOR_OFFSET` (`10000`, read by
the door and the gateway alike), `YMIR_HEART` (else the fleet registry's heart).

## Verified

- A hand-made forward of the same shape, from the dev machine to the heart: `initialize` answered through it as
  `skills-mcp 1.30.0`, `skuld 2.0.0` and `snotra 0.1.0`.
- `bash tests/test_heart_doors.sh`: 16 ok (dev seat goes ssh-first for all three; the heart stays on loopback; the
  offset is configuration; Snotra is a record door; the door never opens a network port; a clean skip on the heart).
- `bash tests/test_fleet_doors_loopback.sh`: 34 ok. `bash bin/bridge/tests/test_mcp_pi_union.sh`: 12 ok.

## Owed

The unit is installed from the release pin, never from a worktree. After the merge: build a release, then run
`bin/fleet/fleet-ensure.sh` (or `bin/bridge/heart-doors.sh ensure`) on each seat that is not the heart, and re-seat
the harnesses with `bin/bridge/mcp-config.sh seat`. Then `bin/bridge/mcp-gateway.sh status` must show all three
upstreams `ok`.

## CHANGE LOG

- **2026-11-23** — note written with the fix.
