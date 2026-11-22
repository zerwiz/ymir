#!/usr/bin/env bash
# lore-audit.sh — does every system the saga tells of have a functioning door? (plan 350 part A)
#
# The Allfather's question (2026-11-22): "do we have a FUNCTIONING function for every feature the saga tells?"
# The claims are docs/lore-claims.tsv: one row per system, the door that should keep it, one read-only command
# and what its output must show. This door measures every row, on this machine, now:
#
#   TRUE     the door exists and the command bore the claim out
#   PARTIAL  the door exists, but the command did not bear the claim out
#   FALSE    there is no door
#   PLANNED  the house records the system as not yet built (and its probe did not pass)
#
#   lore-audit.sh run [--claims F] [--json] [--out FILE]   measure; a Markdown table (or JSON); --out keeps it
#   lore-audit.sh watch [--notify]                          measure, keep <state>/lore-audit/last.json, and name
#                                                           every claim that was TRUE last time and is not now;
#                                                           --notify hands that to the arm holder through the Veil
#
# Exit: 0 measured · 1 (watch) a claim turned from true · 2 usage.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
case "${1:-}" in -h|--help|'') sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
VERB=$1; shift
CLAIMS="$ROOT/docs/lore-claims.tsv"; JSON=0; OUT=""; NOTIFY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --claims) CLAIMS="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    --out) OUT="$2"; shift 2 ;;
    --notify) NOTIFY=1; shift ;;
    *) printf 'lore-audit: unknown argument %s\n' "$1" >&2; exit 2 ;;
  esac
done
# shellcheck disable=SC1091
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
H="${YMIR_HOME:-}"; [ -n "$H" ] || { declare -f ymir_home_root >/dev/null && ymir_home_root H 2>/dev/null; }
S="${YMIR_STATE_DIR:-}"; [ -n "$S" ] || { declare -f hoard_state_dir >/dev/null && hoard_state_dir S 2>/dev/null; }
export YMIR_HOME="${H:-}" YMIR_STATE="${S:-${H:-}/state}"

measure() {  # → JSON lines, one per claim
  while IFS=$'\t' read -r sys claim door cmd expect state; do
    case "$sys" in ''|'#'*) continue ;; esac
    local out rc verdict has
    has=yes
    [ "$door" = - ] && has=no
    [ "$has" = yes ] && [ ! -e "$ROOT/$door" ] && has=no
    out="$(cd "$ROOT" && timeout 120 bash -c "$cmd" </dev/null 2>&1 | head -c 400)"; rc=$?
    if [ "$has" = no ]; then
      verdict=FALSE; [ "$state" = planned ] && verdict=PLANNED
    else
      if { [ "$expect" = rc0 ] && [ "$rc" = 0 ]; } || { [ "$expect" != rc0 ] && printf '%s' "$out" | grep -qE -- "$expect"; }; then
        verdict=TRUE
      else
        verdict=PARTIAL; [ "$state" = planned ] && verdict=PLANNED
      fi
    fi
    python3 -c 'import json,sys; print(json.dumps(dict(zip(["system","claim","door","command","expect","rc","output","verdict"], sys.argv[1:]))))' \
      "$sys" "$claim" "$door" "$cmd" "$expect" "$rc" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-200)" "$verdict"
  done <"$CLAIMS"
}

render() {  # JSON lines on stdin → Markdown table
  python3 -c '
import json, sys
rows = [json.loads(l) for l in sys.stdin if l.strip()]
count = {}
for r in rows:
    count[r["verdict"]] = count.get(r["verdict"], 0) + 1
print("| System | Claim | Door | Command | Output | Verdict |")
print("|---|---|---|---|---|---|")
esc = lambda s: str(s).replace("|", "\\|")
for r in rows:
    g = r.get
    print("| %s | %s | `%s` | `%s` | %s (exit %s) | **%s** |" % (g("system"), esc(g("claim")), esc(g("door")), esc(g("command")),
          esc(g("output")) or "(empty)", g("rc"), g("verdict").lower()))
print()
print("Totals: " + " · ".join(f"{k.lower()} {v}" for k, v in sorted(count.items())))'
}

case "$VERB" in
  run)
    rows="$(measure)"
    if [ "$JSON" = 1 ]; then out="$rows"; else out="$(printf '%s\n' "$rows" | render)"; fi
    if [ -n "$OUT" ]; then mkdir -p "$(dirname "$OUT")"; printf '%s\n' "$out" >"$OUT"; fi
    printf '%s\n' "$out" ;;
  watch)
    d="$YMIR_STATE/lore-audit"; mkdir -p "$d"
    rows="$(measure)"
    turned="$(python3 - "$d/last.json" "$rows" <<'PY'
import json, sys
path, rows = sys.argv[1], [json.loads(l) for l in sys.argv[2].splitlines() if l.strip()]
try:
    before = {r["system"]: r["verdict"] for r in json.load(open(path))}
except Exception:
    before = {}
for r in rows:
    if before.get(r["system"]) == "TRUE" and r["verdict"] != "TRUE":
        print(f'{r["system"]}: was true, now {r["verdict"].lower()} — {r["output"][:80]}')
json.dump(rows, open(path, "w"))
PY
)"
    printf '%s\n' "$rows" >>"$d/history.jsonl"
    if [ -n "$turned" ]; then
      printf 'lore-audit: a claim turned false:\n%s\n' "$turned"
      if [ "$NOTIFY" = 1 ] && [ -x "$ROOT/bin/agents/veil.sh" ]; then
        timeout 120 bash "$ROOT/bin/agents/veil.sh" send --from "script the lore audit" --kind finding \
          "the saga promises what the house no longer keeps: $(printf '%s' "$turned" | tr '\n' ';')" >/dev/null 2>&1 || true
      fi
      exit 1
    fi
    printf 'lore-audit: no claim turned false (%s claims measured)\n' "$(printf '%s\n' "$rows" | grep -c .)" ;;
  *) printf 'lore-audit: unknown verb %s\n' "$VERB" >&2; exit 2 ;;
esac
