#!/usr/bin/env bash
# hall-snapshot.sh — the planning feed for the Óðrerir Live Hall.
#
# Reads the REAL system state and emits a public-safe livehall.json the Hall
# fetches (same origin) and renders: the tally of the hall, the deal-stack of
# planned errands (the armed when-sources and their smiths), and the carved
# ledger (underway / landed / charted). The Hall becomes the full planning
# glass: every errand Brokk arms appears there; every smith's state is live.
#
# PUBLIC-SAFE BY LAW: only Norse worker names, counts, and job ids — never a
# private name, path, secret, or command (the PLAN §12 gate).
#
# Usage:
#   bin/hall-snapshot.sh [<output.json>]
#   default output: apps/odrerir/public/livehall.json
#   (the Live Hall's own deck; the merged public site takes it from its build).
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# The operator's settings and secrets live in the home they chose, never in the
# code tree — a packaged install replaces its tree on upgrade, and a credential
# must never sit in a tree that ships (Rule 04).
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _yr="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _yc in "$_yr/hoard-lib.sh" "$(dirname "$_yr")/bin/hoard-lib.sh"; do
    [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yr _yc
fi
hoard_settings_dir YMIR_SETTINGS_DIR
hoard_local_env YMIR_ENV_FILE
hoard_state_dir YMIR_STATE_DIR
hoard_data_dir YMIR_DATA_DIR

# The roots that live OUTSIDE the code tree: this machine's records and the
# runtime state belong to the home the operator chose at installation, never in
# the tree — a packaged install replaces its tree on upgrade (Rule 04).
STATE="${BROKK_STATE_OVERRIDE:-$YMIR_STATE_DIR}"
OUT="${1:-$ROOT/apps/odrerir/public/livehall.json}"

runes_file="${BROKK_RUNES_FILE:-${YMIR_HOME:-$HOME/Documents/Ymir}/hodd/memory/runes_audit.md}"
PROJECTS_FILE="${YMIR_HOME:-$HOME/Documents/Ymir}/hodd/identity/projects.yaml"
projects_file="$PROJECTS_FILE"
cron_file="$YMIR_SETTINGS_DIR/cron.yaml"

# --- tally the pieces ---
runes=$(grep -c '^{' "$runes_file" 2>/dev/null || echo 0)
projects=$(grep -E '^  - id:' "$projects_file" 2>/dev/null | sed -E 's/^  - id: *([^ ]+).*/\1/' | tr '\n' ' ')
loom=$(grep -cE '^[0-9]{2}:[0-9]{2} ' "$cron_file" 2>/dev/null || echo 0)
wake=$(wc -l <"$STATE/.wake-queue" 2>/dev/null | tr -d '[:space:]'); [ -n "$wake" ] || wake=0

# --- the smiths and their errands (herdr x when-sources) ---
SMITHS_JSON="$(herdr agent list 2>/dev/null | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    out=[]
    for a in d['result']['agents']:
        n=a.get('name')
        if n in ('odrerir','sessrumnir-cloth','hall-button'):
            out.append({'smith':n,'state':a.get('agent_status','unknown'),'pane':a.get('pane_id','')})
    print(json.dumps(out))
except Exception:
    print('[]')
" 2>/dev/null)"
[ -n "$SMITHS_JSON" ] || SMITHS_JSON='[]'

errands=""
if [ -x "$ROOT/.agents/backend/fm-procevent.sh" ]; then
  errands=$("$ROOT/.agents/backend/fm-procevent.sh" list 2>/dev/null | awk '{print $1}' | grep '^when-' | sed 's/^when-//' | sort -u | tr '\n' ' ')
fi

err=$(printf '%s\n' "$errands" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read().split()))" 2>/dev/null)
[ -n "$err" ] || err='[]'
proj=$(printf '%s\n' "$projects" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read().split()))" 2>/dev/null)
[ -n "$proj" ] || proj='[]'
underway=$(printf '%s' "$SMITHS_JSON" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(json.dumps([x['smith'] for x in d if x['state']=='working']))")
landed=$(ls "$STATE/eindri-reports/archive/" 2>/dev/null | sed 's/-.*//' | sort -u | tr '\n' ' ')
landed_json=$(printf '%s\n' "$landed" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read().split()))" 2>/dev/null || echo '[]')

OUT_JSON="$(RUNE_C="$runes" PROJ_N="$(printf '%s' "$projects" | wc -w | tr -d ' ')" LOOM="$loom" WAKE="$wake" \
 SMITHS="$SMITHS_JSON" ERRANDS="$err" PROJ="$proj" UNDERWAY="$underway" LANDED="$landed_json" python3 -c "
import json, os
payload = {
  'generated_at': os.popen('date -u +%Y-%m-%dT%H:%M:%SZ').read().strip(),
  'realm': 'wayof',
  'tally': {
    'runes': int(os.environ['RUNE_C'] or 0),
    'projects': int(os.environ['PROJ_N'] or 0),
    'loom': int(os.environ['LOOM'] or 0),
    'wake': int(os.environ['WAKE'] or 0),
    'smiths': len(json.loads(os.environ['SMITHS'])),
  },
  'errands_armed': json.loads(os.environ['ERRANDS']),
  'smiths': json.loads(os.environ['SMITHS']),
  'ledger': {
    'underway': json.loads(os.environ['UNDERWAY']),
    'landed': json.loads(os.environ['LANDED']),
    'charted': json.loads(os.environ['PROJ']),
  },
}
print(json.dumps(payload, ensure_ascii=False, indent=2))
")"

mkdir -p "$(dirname "$OUT")"
printf '%s\n' "$OUT_JSON" > "$OUT"
printf 'hall-snapshot[1]{generated_at,output}:\n  "%s","%s"\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$OUT"