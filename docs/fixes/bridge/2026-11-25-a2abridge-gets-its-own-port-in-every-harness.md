# The a2abridge door gets its own port in every harness

**Component:** bridge (plan 373, item 3)

## What was wrong

`claude mcp list` showed `a2abridge` as `CONNECTION_CLOSED`. Every harness is seated from pi's MCP files, and those held the raw entry `a2abridge bridge -bind <tailnet address>:8391`. Every session was therefore given the same port, id and state folder. The first session took port 8391, and the bridge of every later session could not bind and closed. The repository already had the answer, `bin/bridge/a2a-bridge-session.sh`, which gives each session its own identity, a free port and its own inbox. Only the pi and OpenCode installer seated it, and the next seat run copied the raw entry back over it.

## What changed

`bin/bridge/mcp-config-seat.py` now rewrites a raw `a2abridge bridge …` spec to the session wrapper, with its environment kept, before it seats any harness. The same set reaches Claude Code, Cursor, Codex and OpenCode.

## Proof

With port 8391 held by another session's bridge, the raw command gave no MCP answer to an `initialize`. `a2a-bridge-session.sh`, run at the same moment, answered it as `a2abridge 3.0.0` on a free port. The seat writer now emits the wrapper path for Claude.
