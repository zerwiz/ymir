#!/usr/bin/env bash
# usage-ratchet.sh — PROVE the doors are used, and fail when the unused pile grows.
#
# WHY (2026-10-02): the Allfather asked *"are all files in bin and .agents/backend now being
# used"* — the answer was **no** (61 doors uncalled, 62 carrying a DECIDE verdict) — and then
# *"we have to prove and make sure all are used."* Reporting that once is not proving it, and a
# sweep that is never enforced decays back into the same pile within a month. **A ratchet cannot.**
#
# THE PROOF, two measurable signals per door (never a claim):
#   · a test exercises it          — named by anything under .agents/tests/
#   · a skill names it             — named by a SKILL.md or an asset under .agents/skills/
# Both can be false, and a door with both false is UNUSED. That is the whole definition.
#
#   bin/gates/checks/usage-ratchet.sh            # measure, record today's baseline if absent, report
#   bin/gates/checks/usage-ratchet.sh --strict   # non-zero when any shelf has grown its unused pile
#   bin/gates/checks/usage-ratchet.sh --accept N # a deliberate, recorded step DOWN: the pile may only
#                                   # shrink, and shrinking it is an explicit act, not a drift
set -uo pipefail

_root() {
  local d; d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [ "$d" != "/" ]; do
    [ -d "$d/.pi" ] && [ -d "$d/RULES" ] && { printf '%s' "$d"; return 0; }
    d="$(dirname "$d")"
  done
  printf '%s' "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
}
ROOT="$(_root)"
cd "$ROOT" || exit 2
REG=".agents/assets/agents/capabilities.md"
REC=".agents/assets/agents/usage-baseline.json"
STRICT=0; ACCEPT=""
case "${1:-}" in --strict) STRICT=1 ;; --accept) ACCEPT="${2:-}" ;; esac

[ -f "$REG" ] || { echo "usage-ratchet: no register — run bin/gates/capabilities.sh" >&2; exit 1; }

# counts come from the REGISTER (generated), not from a second recount that can disagree
c() { grep -oE "\| $1 \|" "$REG" | wc -l | tr -d ' '; }
UNUSED_BIN=$(( $(c "uncalled") ))
NAMED_ONLY=$(( $(c "uncalled\+named") ))
TESTED=$(( $(c "tested") + $(c "tested\+named") ))
BACKEND_PROV=$(grep -oE '"provenance"=[0-9]+' .agents/backend/README.md | head -1 | cut -d= -f2)
SHELF_NOW=$(ls bin/*.sh 2>/dev/null | wc -l | tr -d ' ')

printf 'usage_ratchet[4]{unused_bin,named_only,tested,backend_provenance}:\n  "%s","%s","%s","%s"\n' \
  "$UNUSED_BIN" "$NAMED_ONLY" "$TESTED" "${BACKEND_PROV:-?}"

prev=""
[ -f "$REC" ] && prev="$(python3 - "$REC" <<'PY' 2>/dev/null || true
import json,sys
print(json.load(open(sys.argv[1])).get("unused_bin",""))
PY
)"

if [ -n "$ACCEPT" ]; then
  mkdir -p "$(dirname "$REC")"
  printf '{\n  "unused_bin": %s,\n  "date": "%s",\n  "note": "accepted DOWN by an explicit act; the pile may only shrink from here"\n}\n' \
    "$ACCEPT" "$(date -u +%Y-%m-%d)" > "$REC"
  printf 'usage_ratchet[1]{action}: "baseline set to %s — from here it may only SHRINK"\n' "$ACCEPT"
  exit 0
fi

if [ -z "$prev" ]; then
  mkdir -p "$(dirname "$REC")"
  printf '{\n  "unused_bin": %s,\n  "shelf": %s,\n  "date": "%s",\n  "note": "first baseline; the pile may only shrink RELATIVE to the shelf"\n}\n' \
    "$UNUSED_BIN" "$SHELF_NOW" "$(date -u +%Y-%m-%d)" > "$REC"
  printf 'usage_ratchet[1]{action}: "first baseline recorded: %s unused — now it may only shrink"\n' "$UNUSED_BIN"
  exit 0
fi

# A door ADDED today is uncalled until a skill names it — that is not a regression, it
# is Tuesday. So the gate is: the unused pile may not grow BEYOND the growth of the shelf.
prev_shelf="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get('shelf',''))" "$REC" 2>/dev/null || true)"
allowed="$SHELF_NOW"
[ -n "${prev_shelf:-}" ] && allowed=$(( allowed - prev_shelf ))
[ "$allowed" -lt 0 ] && allowed=0
if [ "$UNUSED_BIN" -gt $(( prev + allowed )) ]; then
  cat >&2 <<MSG
usage_ratchet: the UNUSED pile grew BEYOND new doors — $prev -> $UNUSED_BIN (allowed +$allowed from a shelf that grew)

  A door became unreferenced since the last baseline. That is the failure this ratchet exists
  to stop, and it is not a matter of taste: every unused door is one an agent cannot find,
  and one it may replace with a script of its own.

  Two honest answers, never a third:
    1. the door is a real capability → name it: reference it from a SKILL.md or an asset, so the
       so the register shows it as NAMED.
    2. the door is retired      → MOVE it into the vault reference shelf with the reason
       (Rule 11; bin/no-delete-guard.sh refuses a deletion, so moving is the only exit).

  If the growth is deliberate, say so out loud and step the baseline down:
      bin/gates/checks/usage-ratchet.sh --accept $(($UNUSED_BIN - 1))
MSG
  [ "$STRICT" = 1 ] && exit 1
  exit 1
fi

printf 'usage_ratchet[1]{action}: "held or shrunk: %s -> %s — the pile only shrinks from here"\n' "$prev" "$UNUSED_BIN"
exit 0