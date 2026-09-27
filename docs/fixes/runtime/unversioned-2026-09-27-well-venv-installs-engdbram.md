# runtime · 2026-09-27 — the well venv installs the real engine (`engdbram`), not the Notion namesake

## Why
`bin/fleet-ensure.sh` materialized every seat's well venv with
`pip install mcp-proxy 'mcp<2' engram-mcp`. But PyPI's **`engram-mcp`** is a
different, unrelated package — the Notion bridge
(`github.com/shubhamomar/engram-mcp`), whose console script is also named
`engram-mcp` and which takes no `--db`. The fleet's `engram-mcp` is the console
script **inside `engdbram`** (`engram.mcp_server:main`). So every well MCP face
(`well-mcp.service` → `mcp-proxy … engram-mcp --db …`) started the wrong server,
while `systemctl` still reported `active (running)`. Found while standing the
record MCP faces for the 2026-09-27 heart cutover (plan 51 Part 7).

Second finding: `engdbram` needs Python `>=3.11,<3.14`. A seat whose default
`python3` is newer (some ship 3.14) cannot install it — the recorded interpreter
(`~/.config/ymir/engram-python`, written by `bin/prereq-ensure.sh engram`) must
be used instead.

## What
- `bin/fleet-ensure.sh` materializes the well venv with **`engdbram`** (plus
  `mcp-proxy` and `mcp<2`), and prefers `~/.config/ymir/engram-python` when the
  default `python3` is unsuitable.
- The venv is **rebuilt** when `"$VENV/bin/python" -c 'import engram'` fails, so
  a venv poisoned by the Notion namesake self-heals on the next ensure.

## Files
- `bin/fleet-ensure.sh`
- `.agents/skills/galdr-ymirsystem/assets/memory-well.md` (the second name trap)

## Verified
- `bash -n bin/fleet-ensure.sh` — clean.
- On a seat with a compatible python the venv builds with `engdbram`, and
  `~/.fleet/well-venv/bin/engram-mcp --db <store>` answers an MCP
  `initialize`→`tools/list` with the well's own tools (`remember`, `recall`, …).
