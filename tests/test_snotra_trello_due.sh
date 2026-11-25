#!/usr/bin/env bash
# test_snotra_trello_due.sh — trello-due.sh resolves the operator's home and says "no grant" cleanly
# (2026-11-25, found by Eir on a second machine).
#
#   1. a run never says "command not found"
#   2. with no grant it prints one state row naming the remedy, and exits 1
#   3. the Trello module, run on its own, reads the home's board file through the home resolver
#   4. its private guard reads that home's confidential markers, and refuses a marked word
#
# Fenced: a temp HOME with no mcp-auth.json and no TRELLO_TOKEN, so the script stops before any network.
set -uo pipefail
ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
CRON="$ROOT/systems/snotra/services/cron"
pass=0; fail=0
t() { local name=$1; shift; if "$@"; then printf '  ok   %s\n' "$name"; pass=$((pass+1)); else printf '  FAIL %s\n' "$name"; fail=$((fail+1)); fi; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export HOME="$T/home" XDG_CONFIG_HOME="$T/home/.config" PYTHONDONTWRITEBYTECODE=1   # allow-home-default: the test fences HOME in a temp dir
unset YMIR_HOME YMIR_CONFIG_DIR TRELLO_TOKEN 2>/dev/null || true
mkdir -p "$XDG_CONFIG_HOME/ymir" "$T/chosen/hodd/identity"
printf '%s\n' "$T/chosen" >"$XDG_CONFIG_HOME/ymir/home"
printf 'board: Vinland\n' >"$T/chosen/hodd/identity/trello.yaml"   # a marker only the chosen home carries

# 3 first: the board name is the marker, seen only if the module found the chosen home
out="$(TRELLO_TOKEN=none python3 - "$CRON/snotra-trello.py" 2>&1 <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("snotra_trello", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
print("board=" + m.CONFIG["board"])
PY
)"
t "module: no command is missing" bash -c '! grep -q "command not found" <<<"$0"' "$out"
t "module: the recorded home's board file is the one read" grep -qx 'board=Vinland' <<<"$out"

rm -f "$T/chosen/hodd/identity/trello.yaml"
out="$(bash "$CRON/trello-due.sh" --dry-run 2>&1)"; rc=$?
t "no grant: exit 1" [ "$rc" -eq 1 ]
t "no grant: no command is missing" bash -c '! grep -q "command not found" <<<"$0"' "$out"
t "no grant: one line only" [ "$(wc -l <<<"$out")" -eq 1 ]
t "no grant: the row names the grant and the remedy" grep -q '^trello-due\[1\]{state}: "no Trello grant .*connect the Trello MCP server' <<<"$out"

# 4 — the private guard reads the same home: a marked word never reaches a card (it called the resolver bare)
printf 'markers: [vinland-marker]\n' >"$T/chosen/hodd/identity/confidential.yaml"
out="$(TRELLO_TOKEN=none python3 - "$CRON/snotra-trello.py" 2>&1 <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("snotra_trello", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
m.assert_external("about the vinland-marker", "a card")
print("LEAKED")
PY
)"
t "guard: a marked word is refused" grep -q 'private-guard refused a card: classified material' <<<"$out"

printf 'test_snotra_trello_due: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
