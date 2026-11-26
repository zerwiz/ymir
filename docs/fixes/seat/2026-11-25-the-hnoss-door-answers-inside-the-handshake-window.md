# The hnoss door answers inside the MCP handshake window

**Component:** seat (plan 373, item 2)

## What was wrong

`claude mcp list` reported `hnoss` as `connection timed out after 30000ms`. A client waits 30 seconds for the handshake, and `bin/pi/hnoss-mcp-launch.sh` spent about three of its four seconds before the server even started. Most of that was `pi auth print-api-key`, which starts a whole node runtime, and it ran first. The box was at a load average near 30 (video renders), where each of those starts is several times slower.

I could not reproduce the timeout at the moment I looked (the door answered in 4 seconds, cold or concurrent), so this is a measured cause of slowness and not a recorded hang.

## What changed

- The key is read from pi's `auth.json` and `models.json` first; `pi auth` is the last resort and is bounded at 8 seconds.
- `docker ps` is bounded at 5 seconds.
- The launcher's own time before the server starts fell from 2.6 s to 1.2 s.

## Proof

`hnoss-mcp-launch.sh --resolve` took 1.2 s after the change, and the door answered an MCP initialize.
