# runtime · 2026-09-27 — the A2A node's card follows the heart (name + tailnet URL), not a frozen box

## Why
`tools/ratatoskr-node/server.ts` hardcoded the agent card as
`name: "heart-<one box>"` and the URL as that box's LAN address. When the heart
moves to another machine, a node raised on the new heart still advertises the old
name and a LAN address no peer on the road can reach. A card that lies is Law 1's
bug; a home IP in a card is dead off-LAN. One seat's `~/.fleet` had already been
hand-patched to resolve the URL (an unlanded fix); the repo never carried it.

## What
- The card's **url resolves**: `A2A_ADVERTISE_URL` → `A2A_ADVERTISE_HOST` → the
  host's own `tailscale status --json` DNS name → loopback. (Adopted from the
  unlanded seat patch.)
- The card's **name resolves**: `A2A_AGENT_NAME` → `heart-<this host>`. So a heart
  move between boxes is a re-resolve, never a rewrite.

## Files
- `tools/ratatoskr-node/server.ts`

## Verified
After deploy on the new heart:
`curl -s http://127.0.0.1:8301/.well-known/agent-card.json` →
`name= heart-<this host>  url= http://<this host>.<tailnet>:8301/`.
