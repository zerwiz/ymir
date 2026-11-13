# harness · 2026-11-12 — Hnoss's ensure never writes a shim over a shipped launcher

## Files
- `bin/pi/hnoss-ensure.sh`: `write_shim` refuses a path that is the launcher itself or a file git tracks

## Why
`write_shim` writes a four-line compatibility shim to whatever "old path" a config still names. On heimdall the config
named `~/ymir/bin/pi/hnoss-mcp-launch.sh`, the working tree's own shipped launcher. The update ran from the pin, so the
shim replaced the working tree's 230-line launcher with `exec "<home>/ymir/bin/pi/hnoss-mcp-launch.sh"`, which
is an `exec` of itself. The tree was then dirty, and the next update skipped it as `dirty (1)`. It happened twice on
2026-11-12, the second time during the S8b proof of plan 275.

## Fix
The shim is written only to a path that no checkout ships. A shipped launcher is left untouched, with a line saying so.

## Proof
A temporary repo with a tracked `bin/pi/hnoss-mcp-launch.sh` kept its content (`orig`); an untracked old path still
received the shim.
