# install · 2026-09-23 — the fleet raises what it materializes (%h shape)

## Why
On heimdall all four fleet units crash-looped: cards FAILED (start-limit-hit),
mill-worker "No such file or directory", ratatoskr CHDIR-failed, well-mcp EXEC
failed. The journals named the class: the unit templates hardcoded the heart's
hand-built paths (`/home/whynot/{a2a-node,mill,well,well/root,.venvs/well}`),
which only whynot ever had — the install raised units at shapes it never laid.

## What
- The unit templates are now **%h-native** (systemd's home macro) and point at
  the dirs `fleet-ensure` itself materializes: `~/.fleet/*` (server.ts,
  worker.sh), `~/.fleet/well-venv` (mcp-proxy + mcp<2 + engram-mcp — the venv is
  built by the ensure, never inherited), `~/.fleet/cards-root` (a seat agent
  card under `/.well-known`).
- The embedding stone is **heart-gated**: raised only where the model file
  exists; other seats skip with a note.
- No sed substitution; every seat gets the same portable shape.

## Files
- `tools/mill/systemd/{ratatoskr,mill-worker,well-mcp,cards,embed}.service`
- `bin/fleet-ensure.sh`
