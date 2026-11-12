# fleet · 2026-11-12 — the heart stays reachable for its fleet: loopback and the tailnet, never the LAN

## Files
- `bin/fleet/fleet-ensure.sh`: `heart_bind()` — on a heart whose registry lists other hosts and a tailnet address,
  writes `YMIR_FLEET_BIND="127.0.0.1 <tailnet IP>"` and `YMIR_FLEET_BIND_SHARED=<tailnet IP>` to
  `~/.config/ymir/fleet.env`; a lone machine or a heart without a tailnet stays on loopback and says so; an operator's
  own bind is never overwritten; nothing is written under `--check`
- `tools/tickets-mcp/server.mjs`, `tools/snotra/server.mjs`: the bind is a list; one listener per address
- `packages/a2a/ratatoskr/server.ts`: one `Bun.serve` per address
- `tools/mill/systemd/cards.service`, `skills-mcp.service`: one listener on `YMIR_FLEET_BIND_SHARED`
- `bin/bridge/mcp-gateway.sh`: the heart's own gateway tries loopback, then its tailnet address
- `tests/test_fleet_doors_loopback.sh`: +8 checks (34); registered in `tests/run.sh`

## Why
Ticket ymir/80. The loopback default of the note before this one (same day) is right for a single machine, but our
hands (every role but the heart) reach the heart's Skuld, skills, Snotra and Ratatoskr over the tailnet through
`mcp-gateway.sh`, and the heart had no `fleet.env`: the next deploy would have cut every hand off. One address could not
serve both the heart's own loopback clients and its hands. Collaborators are not affected either way: they come through
Gimlé's Cloudflare tunnel and sign-in (plan 192), never these doors. The operator's word: *"we need to have the heart
functional ... we fix his pr before we merging"*.

## Proof
34/34 in the test. In a scratch home with the real fleet registry: the heart wrote loopback + its tailnet IP; a lone
heart stayed on loopback and said so; a second run left the operator's file alone.

## CHANGE LOG

- 2026-11-12 — review-mend: added missing heading for #712
