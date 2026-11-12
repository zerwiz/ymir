## agents · unversioned · 2026-11-12 — the finishing step names the real shelf, and a worker's leftovers are carried up

### Why
eindri-acclaim.sh claimed it had filed state/eindri-reports/<id>.md with a path relative to the repo, while the shelf lives in the home's state dir; a write that did not land was never noticed. It now names the absolute shelf, fails loudly (rc 1) when the report or the wake did not land, and refuses a shipping errand's done line that carries no PR (batch, local-only and scouts exempt). The brief template greps the home's wake queue, not <repo>/state. Carried from old worktrees: Groa's agent writes what it did to the daily log, Runes and the well (groa-quiet); the MCP todo face calls bin/records/todos.sh, which gains reopen (fix-order-ear).

### Files
- `bin/agents/eindri-acclaim.sh`
- `bin/agents/erindi-brief.sh`
- `bin/agents/groa-agent/groa-agent.sh`
- `bin/records/todos.sh`
- `bin/seat/ymir-mcp.py`
- `bin/seat/tests/test_everything_up.sh`

## CHANGE LOG

- 2026-11-12 — filed with the errand `everything-up`.
