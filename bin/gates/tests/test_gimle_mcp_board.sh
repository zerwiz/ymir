#!/usr/bin/env bash
# test_gimle_mcp_board.sh — the hall's board door, proved where its code now lives (Gimlé's own repository).
#
# Until 2026-11-19 this test drove Ymir's copy of the door (bin/gimle/mcp-read.py). That copy left for
# Gimlé's repository; its verbatim last version waits in the operator's home under
# hodd/reference/ymir-moved/gimle-bin-2026-11-19/. Ymir carries no Gimlé code, so this gate no longer
# tests a file of its own: it finds Gimlé the way every split app is found (bin/apps/app-path.sh — the dev
# road YMIR_APP_GIMLE_DIR, or the app's own home when it is installed there) and runs Gimlé's own door
# suites from it. Where no Gimlé copy is on this machine, it skips cleanly and says how to name one.
#
#   bin/gates/tests/test_gimle_mcp_board.sh
#   YMIR_APP_GIMLE_DIR=~/src/gimle bin/gates/tests/test_gimle_mcp_board.sh
#
# Exit: 0 green or a named skip · 1 a Gimlé suite failed.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

# shellcheck source=/dev/null
. "$ROOT/bin/apps/app-path.sh"
dir="" road=""
if ! app_path gimle dir road 2>/dev/null || [ -z "$dir" ]; then
  echo "skip: no Gimlé copy on this machine — name one with YMIR_APP_GIMLE_DIR=<a gimle checkout>"
  exit 0
fi

suites=(
  "systems/mcp/tests/test_write_grant.py"
  "systems/mcp/test_plane_tools.py"
  "desk/tests/test_plane_reader.py"
)
fail=0 ran=0
for s in "${suites[@]}"; do
  if [ ! -f "$dir/$s" ]; then
    echo "skip: $s is not in the Gimlé copy at $dir ($road) — that copy predates it"
    continue
  fi
  ran=$((ran + 1))
  if out="$(timeout 180 python3 "$dir/$s" 2>&1)"; then
    echo "ok    $s ($road) — $(printf '%s\n' "$out" | grep -E 'passed|^OK|^Ran' | tail -1)"
  else
    echo "FAIL  $s ($road)"
    printf '%s\n' "$out" | tail -15
    fail=1
  fi
done
echo "gimle board door: $ran suite(s) run from $dir ($road), $([ "$fail" = 0 ] && echo green || echo red)"
exit "$fail"
