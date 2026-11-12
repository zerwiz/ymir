#!/usr/bin/env bash
# test_no_stale_arm_door.sh — plan 272 fault 3.
# The arm's door moved to bin/pi/syn-watch.sh. The notice "bash: …/bin/syn-watch.sh: No such file" in a home's
# state/.arm.log was measured to be an old record (the log's last write is 2026-10-12, before the 2026-10-24 fix
# note); this proves no live caller, unit or generated config still names the old path, and that the door exists.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; }
[ -x "$ROOT/bin/pi/syn-watch.sh" ] && ok "the arm's door exists at bin/pi/syn-watch.sh" || bad "door missing"
hits="$(git -C "$ROOT" grep -nE '(^|[^a-z/])bin/syn-watch(-arm)?\.sh|\("bin", *"syn-watch' -- . ':!docs/fixes' ':!docs/plans' ':!*.md' ':!bin/gates/tests/test_no_stale_arm_door.sh' 2>/dev/null || true)"
[ -z "$hits" ] && ok "no tracked script, unit or config calls the old bin/syn-watch.sh path" || bad "stale caller: $hits"
ROOT="$ROOT" python3 - <<'PY' && ok "the engine's WATCH_DOOR resolves to a real file" || bad "WATCH_DOOR does not resolve"
import re, sys, os
root = os.environ["ROOT"]
s = open(os.path.join(root, "src/ymir_runtime/watch.py")).read()
m = re.search(r'WATCH_DOOR\s*=\s*\(([^)]*)\)', s)
parts = [p.strip().strip('"\'') for p in m.group(1).split(',') if p.strip()]
sys.exit(0 if os.path.isfile(os.path.join(root, *parts)) else 1)
PY
printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
