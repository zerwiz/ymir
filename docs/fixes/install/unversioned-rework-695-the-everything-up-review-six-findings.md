## install · unversioned · 2026-11-12 — rework of PR #695: six review findings mended

### Why
The review of PR #695 found it needed rework. (1) `bin/seat/valknut-load.sh` used `YMIR_HOME_RESOLVED`, which nothing assigned after a merge, so a generated `.pi/mcp-adapter.json` carried the literal `__YMIR_HOME__/hodd/memory/kaia.engram` and still said "seeded"; the home now resolves through `bin/vault/hoard-lib.sh`, and an unresolved home refuses with `ERROR refused: home unresolved` and writes no file. (2) The one-writer law for todos had been applied to a decoy; the live MCP face is `bin/mcp/ymir-mcp.py`, which now calls `bin/records/todos.sh` and keeps no store. The decoy `bin/seat/ymir-mcp.py` was named by no installed config and no script; Rule 11 forbids deleting it, so it is now a thin pointer that execs the live face. (3) `clear` walked a stale listing; it now removes from the highest index down and reports the true count or the failure. (4) `bin/seat/tests/test_everything_up.sh` is now a gate in `bin/gates/ci-verify.sh`. (5) `eindri-acclaim.sh` exempts `scout`, `review` and `recon` from the done-needs-PR guard, since `eindri-dispatch.sh` writes `mode=scout`. (6) The suite was run after rebasing on origin/main.

### Files
- `bin/seat/valknut-load.sh`
- `bin/mcp/ymir-mcp.py`
- `bin/seat/ymir-mcp.py` (now a thin pointer)
- `bin/records/todos.sh` (comment)
- `bin/agents/eindri-acclaim.sh`
- `bin/gates/ci-verify.sh`
- `bin/seat/tests/test_everything_up.sh`

### Tests
`bash bin/seat/tests/test_everything_up.sh` — 28 checks, now run by `ci-verify.sh`.
