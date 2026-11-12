## seat · unversioned · 2026-11-12 — a worker seat never takes the Stop-hook arm, and a rendered config resolves the home through hoard-lib

### Why
The repo's .claude/hooks/ymir-arm.sh (the source the installer seats) lacked the worker guard the installed copy carries, and claude-stop-arm.sh armed any seat that owned its own Gleipnir lock, so a worker's every stop printed 'stale: no live lease' and blocked in a loop. Both now exit 0 inside a /.yggdrasil/ worktree or a seat directory; the helm is still woken. valknut-load.sh rendered __YMIR_HOME__ as the user's HOME, so a generated .pi/mcp-adapter.json pointed engram at ~/hodd/memory/kaia.engram; it now resolves the home once through bin/vault/hoard-lib.sh.

### Files
- `.claude/hooks/ymir-arm.sh`
- `bin/gates/checks/claude-stop-arm.sh`
- `bin/seat/valknut-load.sh`
- `bin/seat/tests/test_everything_up.sh`