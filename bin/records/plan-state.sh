#!/usr/bin/env bash
# plan-state.sh — read and write the Status/Owner header of every plan in the ledger.
set -uo pipefail
_root() { local d; d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; while [ "$d" != "/" ]; do [ -d "$d/.pi" ] && [ -d "$d/RULES" ] && { printf '%s' "$d"; return 0; }; d="$(dirname "$d")"; done; printf '%s' "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; }
ROOT="$(_root)"
PLAN_DIR="${YMIR_PLAN_DIR:-}"
if [ -z "$PLAN_DIR" ]; then
  _h="${YMIR_HOME:-}"
  if [ -z "$_h" ] && [ -r "$ROOT/bin/vault/hoard-lib.sh" ]; then . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true; command -v ymir_home_root >/dev/null 2>&1 && ymir_home_root _h; fi
  [ -n "$_h" ] || _h="$(bash "$ROOT/bin/vault/hodd.sh" path 2>/dev/null || true)"
  # The ledger's realm is the OPERATOR's: it is discovered inside his home, never
  # spelled here (RULES/04 — the repository ships to other fleets).
  command -v ymir_plan_dir >/dev/null 2>&1 || . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
  command -v ymir_plan_dir >/dev/null 2>&1 && { ymir_plan_dir PLAN_DIR 2>/dev/null || true; }
fi
[ -d "$PLAN_DIR" ] || { echo "plan-state: no ledger at $PLAN_DIR" >&2; exit 1; }

header() { sed -n '1,25p' "$1"; }
get_field() { header "$1" | grep -iE "^$2:" | head -1 | sed -E "s/^$2:[[:space:]]*//I"; }

valid_status() { case "$1" in open|building|done|parked|superseded) return 0;; esac; return 1; }

cmd="${1:-audit}"
case "$cmd" in
  -h|--help|"") sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  check)
    bad=0
    for f in "$PLAN_DIR"/*.md; do
      [ -e "$f" ] || continue
      [ "$(basename "$f")" = "README.md" ] && continue
      s="$(get_field "$f" Status)"; o="$(get_field "$f" Owner)"
      if [ -z "$s" ] || [ -z "$o" ]; then echo "MISSING: $(basename "$f") (status='${s:-}' owner='${o:-}')"; bad=$((bad+1)); fi
    done
    [ "$bad" -eq 0 ] && echo "plan-state: all plans carry Status and Owner" || { echo "plan-state: $bad finding(s)"; exit 1; } ;;
  set)
    f="${2:-}"; st="${3:-}"; ow="${4:-}"
    [ -n "$f" ] && [ -f "$f" ] || { echo "plan-state set: file required" >&2; exit 2; }
    valid_status "$st" || { echo "plan-state set: bad status $st" >&2; exit 2; }
    [ -n "$ow" ] || { echo "plan-state set: owner required" >&2; exit 2; }
    # remove existing Status/Owner lines in header
    python3 - "$f" "$st" "$ow" <<'PY'
import sys
f,st,ow=sys.argv[1],sys.argv[2],sys.argv[3]
lines=open(f).read().splitlines(keepends=True)
out=[]; seen=set()
for ln in lines:
    if ln.lower().startswith('status:') or ln.lower().startswith('owner:'):
        if ln.lower().startswith('status:') and 'status' not in seen:
            out.append(f"Status: {st}\n"); seen.add('status')
        elif ln.lower().startswith('owner:') and 'owner' not in seen:
            out.append(f"Owner: {ow}\n"); seen.add('owner')
        # drop duplicate
        continue
    out.append(ln)
if 'status' not in seen:
    # insert after first heading
    ins=0
    for i,l in enumerate(out):
        if l.startswith('#'): ins=i+1; break
    out.insert(ins, f"Status: {st}\n")
if 'owner' not in seen:
    ins=0
    for i,l in enumerate(out):
        if l.startswith('#'): ins=i+1; break
    out.insert(ins+ (1 if 'status' in seen else 0), f"Owner: {ow}\n")
open(f,'w').write(''.join(out))
PY
    echo "plan-state: set $(basename "$f") -> $st / $ow" ;;
  audit)
    printf 'plan-state audit (%s)\n' "$PLAN_DIR"
    n=0; done=0; open=0; building=0; parked=0; superseded=0; needs=0
    for f in "$PLAN_DIR"/*.md; do
      [ -e "$f" ] || continue
      [ "$(basename "$f")" = "README.md" ] && continue
      num="$(basename "$f" | grep -oE '^[0-9]+')"
      s="$(get_field "$f" Status)"; o="$(get_field "$f" Owner)"
      [ -z "$s" ] && s="MISSING"; [ -z "$o" ] && o="MISSING"
      case "$s" in done) done=$((done+1));; open) open=$((open+1));; building) building=$((building+1));; parked) parked=$((parked+1));; superseded) superseded=$((superseded+1));; esac
      [ "$o" = "needs-owner" ] && needs=$((needs+1))
      printf '%s\t%s\t%s\t%s\n' "$num" "$s" "$o" "$(basename "$f")"
      n=$((n+1))
    done
    echo "TALLY: total=$n done=$done open=$open building=$building parked=$parked superseded=$superseded needs-owner=$needs" ;;
  *) echo "plan-state: unknown action $cmd" >&2; exit 2 ;;
esac
