#!/usr/bin/env bash
# ui-truth-check.sh — the panel's number must equal the machine's number.
#
# The wiring order's last row, and the one that makes the rest trustworthy: a
# board can render beautifully and still lie. This compares what the UI is SERVED
# against what the machine actually holds, per source, and FAILS on a mismatch.
#
#   bin/ui-truth-check.sh          # compare, TOON, exit 0/1
#   bin/ui-truth-check.sh --help
#
# It reads endpoints as the DESKTOP SEAT (loopback + the marker), which is the
# trusted seat rule 09 allows — the web door would answer 401 and prove nothing
# about the data.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GATE="${HLIDSKJALF_API_PORT:-3889}"
# shellcheck source=bin/hoard-lib.sh
. "$SCRIPT_DIR/hoard-lib.sh"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

have() { command -v "$1" >/dev/null 2>&1; }
have curl || { printf 'error: curl is required\nhelp: install curl\n' >&2; exit 1; }

json_len() { python3 -c 'import json,sys
try: print(len(json.load(sys.stdin)))
except Exception: print(0)' 2>/dev/null || echo 0; }

verdict="PASS"; details=""

# ── the fleet: herdr vs the connector vs the endpoint ─────────────────────────
SRC_JSON="$("$SCRIPT_DIR/hlidskjalf-agents.sh" 2>/dev/null || printf '[]')"
src_n=$(printf '%s' "$SRC_JSON" | json_len)
UI_JSON="$(curl -s --max-time 8 -H 'x-ymir-surface: desktop' "http://127.0.0.1:${GATE}/api/agents" 2>/dev/null || printf '[]')"
ui_n=$(printf '%s' "$UI_JSON" | json_len)
if have "${HERDR_BIN_PATH:-herdr}"; then
  herd_n="$("${HERDR_BIN_PATH:-herdr}" pane list 2>/dev/null | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: print(0); raise SystemExit
panes=(d.get("result") or {}).get("panes") or d.get("panes") or []
print(sum(1 for p in panes if p.get("agent")))' 2>/dev/null || echo 0)"
else
  herd_n="unknown"
fi
[ "$src_n" = "$ui_n" ] || { verdict="FAIL"; details="$details fleet:connector=$src_n,served=$ui_n"; }
[ "$herd_n" = "unknown" ] || [ "$src_n" = "$herd_n" ] || { verdict="FAIL"; details="$details fleet:connector=$src_n,herdr=$herd_n"; }

# ── the ledger: the hoard's, against what the gate serves ─────────────────────
hoard_root _hoard
LEDGER="$_hoard/memory/runes_audit.md"
ledger_n=0
[ -r "$LEDGER" ] && ledger_n=$(grep -c '^[[:space:]]*{' "$LEDGER" 2>/dev/null || echo 0)
UI_RUNES="$(curl -s --max-time 8 -H 'x-ymir-surface: desktop' "http://127.0.0.1:${GATE}/api/runes" 2>/dev/null || printf '[]')"
ui_runes_n=$(printf '%s' "$UI_RUNES" | json_len)
[ "$ledger_n" = "$ui_runes_n" ] || { verdict="FAIL"; details="$details ledger=$ledger_n,served=$ui_runes_n"; }

printf 'ui_truth[6]{source,count,note}:\n'
printf '  "herdr panes","%s","what the machine holds"\n' "$herd_n"
printf '  "the connector","%s","bin/hlidskjalf-agents.sh"\n' "$src_n"
printf '  "the endpoint","%s","/api/agents as the desktop seat"\n' "$ui_n"
printf '  "ledger entries","%s","the hoard'"'"'s ledger"\n' "$ledger_n"
printf '  "ledger served","%s","/api/runes as the desktop seat"\n' "$ui_runes_n"
printf '  "verdict","%s","%s"\n' "$verdict" "$([ -n "$details" ] && printf 'mismatch:%s' "$details" || printf 'the board may be believed')"

[ "$verdict" = "PASS" ] || { printf 'error: the UI and the machine disagree\nhelp: %s\n' "${details:-see the rows above}" >&2; exit 1; }
exit 0
