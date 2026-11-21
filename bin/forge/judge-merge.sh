#!/usr/bin/env bash
# judge-merge.sh — the judge's verdict is the seal: APPROVE merges at once, NEEDS-REWORK goes home.
#
# WHY (RULES/08, its sections appended 2026-11-21, at the Allfather's word): *"We need to have a
# claude opus review every pr. If its OK. He merges instantly."* The review spine
# (bin/agents/eindri-review-spawn.sh) seats the judge and the judge writes its report with the
# verdict block `verdict[1]{result,count,list,seal}`. Before this door nothing READ that block:
# an approval sat on the report shelf until a human saw it. This is the reader, and the one road
# from a verdict to a merge.
#
# WHAT ONE ACT DOES, for one finished review:
#   APPROVE       → bin/agents/pr-seal.sh seal <n> --repo <r> --head <approved sha>
#                   (the ONE merge door; it re-checks everything at that instant and merges
#                   under the operator's account with the method from bin/forge/merge-method.sh)
#     · merged          → settled; the Rune is pr-seal's
#     · red gate        → one PR comment naming the failing row; settled for this head — the
#                         next head is judged again by review-watch
#     · head moved      → settled, nothing said: the new head is new work
#     · pending / held  → one PR comment per head and reason; NOT settled, so the next pass
#                         tries the same approval again once the gate turns
#   NEEDS-REWORK  → one PR comment carrying the items, a wake for the author's seat; nothing merges
#   anything else → nothing; an unreadable verdict is never read as consent
#
# The approved head is the head the spine recorded when it seated the judge
# (state/.reviewed/<review-id>.judged). A report OLDER than that record belongs to an earlier
# head and is ignored; a report naming `judged-head: <sha>` that differs is refused.
#
# Usage:
#   judge-merge.sh act <review-id> [--dry-run]    act on one finished review
#   judge-merge.sh sweep [--dry-run]              act on every finished, unsettled review
#   judge-merge.sh verdict <report-path>          print the parsed verdict (result<TAB>count<TAB>list)
#
# Exit: 0 acted or nothing to do · 1 a fault · 2 usage.
set -u
VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,34p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  . "$ROOT/bin/vault/hoard-lib.sh"; YMIR_HOARD_LIB_LOADED=1
fi
[ -r "$ROOT/bin/time/sol-lib.sh" ] && . "$ROOT/bin/time/sol-lib.sh"
command -v sol_stamped >/dev/null 2>&1 || sol_stamped() { printf '%s — %s' "$(date '+%Y-%m-%d %H:%M %Z')" "$*"; }
STATE=""; hoard_state_dir STATE
[ -n "$STATE" ] || { printf 'judge-merge: the state dir is unresolved\n' >&2; exit 1; }
REVIEWED="$STATE/.reviewed"
REPORTS="$STATE/eindri-reports"
QUEUE="$STATE/.wake-queue"
SEAL="${YMIR_SEAL_DOOR:-$ROOT/bin/agents/pr-seal.sh}"
RODD="${YMIR_RODD_DOOR:-$ROOT/bin/voice/rodd-arm.sh}"
NOTIFY="${YMIR_NOTIFY_DOOR:-$ROOT/bin/agents/eindri-notify.sh}"
ARM_SEND="${YMIR_ARM_SEND_DOOR:-$ROOT/bin/fleet/arm-send.sh}"
ME="$(hostname -s 2>/dev/null || echo here)"
FLEET_HOME=""; ymir_home_root FLEET_HOME 2>/dev/null || true
FLEET="$FLEET_HOME/hodd/data/fleet.json"

ACTION="$1"; shift
DRY=0; ARGS=()
for a in "$@"; do case "$a" in --dry-run) DRY=1 ;; *) ARGS+=("$a") ;; esac; done

say() { printf '%s\n' "$*"; }

# ── the verdict block, read from the report's tail ─────────────────────────────────────────────
parse_verdict() {  # <report> → result<US>count<US>list<US>judged-head (US = \x1f)
  python3 - "$1" <<'PY'
import csv, io, re, sys
text = open(sys.argv[1], encoding="utf-8", errors="replace").read()
lines = text.splitlines()
result, count, items = "UNKNOWN", "", ""
for i in range(len(lines) - 1, -1, -1):
    if re.match(r"^\s*verdict\[\d+\]\{result,count,list,seal\}:\s*$", lines[i]):
        body = next((l for l in lines[i + 1:] if l.strip()), "")
        try:
            row = next(csv.reader(io.StringIO(body.strip()), skipinitialspace=True))
        except Exception:
            row = []
        r = (row[0] if row else "").strip().upper()
        # the template's own placeholder ("APPROVE or NEEDS-REWORK") is not a verdict
        if "NEEDS-REWORK" in r and "APPROVE" not in r: result = "NEEDS-REWORK"
        elif r == "APPROVE": result = "APPROVE"
        count = row[1].strip() if len(row) > 1 else ""
        items = row[2].strip() if len(row) > 2 else ""
        break
m = re.findall(r"judged-head:\s*([0-9a-f]{40})", text)
# \x1f, not a tab: a tab is IFS whitespace, so an empty field (an APPROVE with no list) would fold
# and shift the judged-head into the list
print("\x1f".join([result, count.replace("\x1f", " "), items.replace("\x1f", " ").replace("\n", " "), m[-1] if m else ""]))
PY
}

meta() {  # <file> <key>
  sed -n "s/^$2=//p" "$1" 2>/dev/null | tail -1
}

say_once() {  # <marker> <repo> <n> <text> — one PR comment per marker
  local marker="$1" repo="$2" n="$3" text="$4"
  [ -e "$marker" ] && return 0
  if [ "$DRY" = 1 ]; then say "  would comment on $repo#$n: $text"; return 0; fi
  if gh pr comment "$n" -R "$repo" --body "$text" >/dev/null 2>&1; then
    printf '%s\n' "$text" >"$marker" 2>/dev/null || true
  else
    printf 'judge-merge: the comment on %s#%s did not land\n' "$repo" "$n" >&2
  fi
}

wake_author() {  # <repo> <n> <task> <items> <head>
  # The rework goes to the ARM HOLDER of the seat that opened the PR, by two roads at once, because
  # either may be down (the arm wire failed on 2026-11-21): the arm wire (rodd-arm tell / arm-send)
  # AND a turn typed into the holder's herdr pane (eindri-notify). The holder starts a coder errand
  # on the PR's branch; when the coder's new head lands, review-watch seats the judge for it again.
  local repo="$1" n="$2" task="$3" items="$4" head="$5" json body branch host line road
  json="$(gh pr view "$n" -R "$repo" --json body,headRefName 2>/dev/null || true)"
  body="$(printf '%s' "$json" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("body") or "")
except Exception: pass' 2>/dev/null)"
  branch="$(printf '%s' "$json" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("headRefName") or "")
except Exception: pass' 2>/dev/null)"
  host="$(printf '%s\n' "$body" | sed -nE 's/^[[:space:]]*Arm:[[:space:]]*([^@[:space:]]+@)?([A-Za-z0-9._-]+)[[:space:]]*$/\2/p' | head -1)"
  [ -n "$host" ] || host="$ME"
  line="PR #$n ($repo) NEEDS-REWORK from the judge at head ${head:0:12}: $items — start a coder errand on branch ${branch:-the branch of the PR} to fix these items and push to that same branch; the judge reviews the new head and an APPROVE on green merges at once."
  if [ "$DRY" = 1 ]; then say "  would hand the rework to the arm holder on $host: $line"; return 0; fi
  # the house wake format: '<sol stamp> — <text>\tclass=<kind>' (bin/agents/eindri-wake-lib.sh); a
  # rework is a report the arm holder acts on
  printf '%s\tclass=report\n' "$(sol_stamped "judge $line")" >>"$QUEUE" 2>/dev/null || true
  if [ "$host" = "$ME" ]; then
    timeout 30 bash "$RODD" tell --from judge "$line" >/dev/null 2>&1 \
      || printf 'judge-merge: the arm wire did not take the rework for %s#%s here\n' "$repo" "$n" >&2
    timeout 30 bash "$NOTIFY" --from judge -- "$line" >/dev/null 2>&1 \
      || printf 'judge-merge: the rework for %s#%s could not be typed into the arm holder'"'"'s pane here\n' "$repo" "$n" >&2
    return 0
  fi
  timeout 60 bash "$ARM_SEND" "$host" "$line" >/dev/null 2>&1 \
    || printf 'judge-merge: the arm wire did not carry the rework for %s#%s to %s\n' "$repo" "$n" "$host" >&2
  road="$(python3 - "${YMIR_FLEET_REGISTRY:-$FLEET}" "$host" <<'PY' 2>/dev/null
import json, sys
try: h = (json.load(open(sys.argv[1])).get("hosts") or {}).get(sys.argv[2]) or {}
except Exception: h = {}
if h.get("user") and h.get("tailnet"): print(f"{h['user']}@{h['tailnet']}")
PY
)"
  [ "${YMIR_NO_INJECT:-0}" = 1 ] && road=""   # a test types into nobody's pane
  if [ -n "$road" ]; then
    timeout 60 ssh -o BatchMode=yes -o ConnectTimeout=6 "$road" \
      "d=\${YMIR_RUNTIME_DIR:-\$HOME/ymir-runtime}; [ -f \$d/bin/agents/eindri-notify.sh ] || d=\$HOME/ymir; cd \$d && bash bin/agents/eindri-notify.sh --from judge -- $(printf '%q' "$line")" \
      </dev/null >/dev/null 2>&1 \
      || printf 'judge-merge: the rework for %s#%s could not be typed into the pane on %s\n' "$repo" "$n" "$host" >&2
  else
    printf 'judge-merge: no road to %s in the fleet registry — the rework stands in the arm wire and the local queue\n' "$host" >&2
  fi
}

may_act() {  # <owner/repo> → 0 when the repository is kept AND this gh hand can write it
  MAY_WHY=""
  if ! python3 "$ROOT/bin/forge/warden-policy.py" keeps "$1" >/dev/null 2>&1; then
    MAY_WHY="not kept: not owned by the operator's login and not marked git.keep: true"; return 1
  fi
  local perm
  perm="$(gh repo view "$1" --json viewerPermission -q .viewerPermission 2>/dev/null | tr -d '[:space:]')"
  case "$perm" in
    ADMIN|MAINTAIN|WRITE) return 0 ;;
    *) MAY_WHY="this hand holds ${perm:-no readable} permission there, not write"; return 1 ;;
  esac
}

act() {  # <review-id>
  local rid="$1" side report v result count items named repo n head task settled out rc cond detail
  side="$REVIEWED/$rid.judged"
  report="$REPORTS/$rid.md"
  [ -r "$side" ] || { say "judge-merge: $rid — no judged record ($side); the spine did not seat this review, nothing to act on"; return 0; }
  [ -r "$report" ] || { say "judge-merge: $rid — the judge has not reported yet"; return 0; }
  # a report written before the judge was seated for this head is an older head's verdict
  if [ "$(stat -c %Y "$report")" -lt "$(stat -c %Y "$side")" ]; then
    say "judge-merge: $rid — the report predates the judged record; the judge of this head has not reported"
    return 0
  fi
  repo="$(meta "$side" repo)"; n="$(meta "$side" pr)"; head="$(meta "$side" head)"; task="$(meta "$side" task)"
  if [ -z "$repo" ] || [ -z "$n" ] || [ -z "$head" ]; then
    say "judge-merge: $rid — the judged record lacks repo, pr or head; nothing is merged on a half-record"
    return 0
  fi
  settled="$REVIEWED/$rid.$head.acted"
  [ -e "$settled" ] && { say "judge-merge: $rid — already settled for ${head:0:12}"; return 0; }
  # THE KEEPER ACTS ONLY WHERE IT MAY MERGE (review of #863, 2026-11-21). A repository that is not
  # kept (not the operator's own login, not git.keep: true — an upstream the house only tracks), or
  # one this hand cannot write, gets no comment, no wake and no merge: settled in silence.
  if ! may_act "$repo"; then
    say "judge-merge: $rid — $repo is not a repository this hand may merge ($MAY_WHY); settled with nothing said"
    [ "$DRY" = 1 ] || printf 'not kept: %s\n' "$MAY_WHY" >"$settled"
    return 0
  fi

  v="$(parse_verdict "$report")"
  IFS=$'\x1f' read -r result count items named <<<"$v"
  if [ -n "$named" ] && [ "$named" != "$head" ]; then
    say "judge-merge: $rid — the report judged ${named:0:12} but the spine seated it for ${head:0:12}; refused"
    return 0
  fi

  case "$result" in
    APPROVE)
      # an approval must NAME the head it judged: a report with no `judged-head:` line cannot prove
      # which head it read, so it merges nothing (review of #863, 2026-11-21)
      if [ "$named" != "$head" ]; then
        say "judge-merge: $rid — APPROVE names no judged-head (want ${head:0:12}); nothing merges on an approval that cannot say what it read"
        return 0
      fi
      if [ "$DRY" = 1 ]; then say "judge-merge: $rid — APPROVE; would run: $SEAL seal $n --repo $repo --head $head --review $rid"; return 0; fi
      out="$("$SEAL" seal "$n" --repo "$repo" --head "$head" --review "$rid" 2>&1)"; rc=$?
      printf '%s\n' "$out"
      if [ "$rc" = 0 ]; then
        printf 'merged %s#%s at %s\n' "$repo" "$n" "$head" >"$settled"
        return 0
      fi
      cond="$(printf '%s\n' "$out" | sed -n 's/^  "#[0-9]*","\([^"]*\)","\(.*\)"$/\1/p' | head -1)"
      detail="$(printf '%s\n' "$out" | sed -n 's/^  "#[0-9]*","\([^"]*\)","\(.*\)"$/\2/p' | head -1)"
      case "$cond" in
        "red gate")
          say_once "$REVIEWED/$rid.$head.said-red" "$repo" "$n" \
            "The judge approved head \`${head:0:12}\`, but it is **not merged**: a required gate is red — $detail. Push a fix; the new head is reviewed again."
          printf 'red: %s\n' "$detail" >"$settled" ;;
        "head moved"|"not open"|"conflicts")
          printf '%s: %s\n' "$cond" "$detail" >"$settled" ;;
        "wrong identity"|"not the house's")
          # a fault of THIS hand, not of the PR: settled without a word on GitHub — a comment per head
          # would repeat the same refusal on every push (review of #863, 2026-11-21)
          printf 'judge-merge: %s#%s approved but REFUSED: %s — %s\n' "$repo" "$n" "$cond" "$detail" >&2
          printf '%s: %s\n' "$cond" "$detail" >"$settled" ;;
        *)
          # pending, held, draft, not yet mergeable, a hand that is not the operator's: not now
          say_once "$REVIEWED/$rid.$head.said-$(printf '%s' "${cond:-unknown}" | tr -c 'a-z0-9' '-')" "$repo" "$n" \
            "The judge approved head \`${head:0:12}\`; the merge waits — ${cond:-not ready}: $detail. It is tried again on the next pass."
          ;;
      esac
      return 0 ;;
    NEEDS-REWORK)
      say_once "$REVIEWED/$rid.$head.said-rework" "$repo" "$n" \
        "$(printf 'The judge asks for rework on head `%s` (%s item(s)); nothing is merged.\n\n%s\n' "${head:0:12}" "${count:-?}" \
            "$(printf '%s' "$items" | sed -E 's/[[:space:]]+([0-9]+[.)])[[:space:]]/\n\1 /g')")"
      wake_author "$repo" "$n" "${task:-$rid}" "$items" "$head"
      [ "$DRY" = 1 ] || printf 'needs-rework: %s\n' "$items" >"$settled"
      return 0 ;;
    *)
      say "judge-merge: $rid — no readable verdict in $report; nothing merges on silence"
      return 0 ;;
  esac
}

case "$ACTION" in
  verdict) [ -n "${ARGS[0]:-}" ] || { printf 'usage: judge-merge.sh verdict <report>\n' >&2; exit 2; }; parse_verdict "${ARGS[0]}" | tr '\037' '\t' ;;
  act)     [ -n "${ARGS[0]:-}" ] || { printf 'usage: judge-merge.sh act <review-id>\n' >&2; exit 2; }; act "${ARGS[0]}" ;;
  sweep)
    command -v gh >/dev/null 2>&1 || { printf 'judge-merge: gh is not on PATH — no verdict can be carried out here\n' >&2; exit 1; }
    for side in "$REVIEWED"/*.judged; do
      [ -r "$side" ] || continue
      act "$(basename "$side" .judged)"
    done ;;
  *) printf 'judge-merge: unknown action %s (act|sweep|verdict)\n' "$ACTION" >&2; exit 2 ;;
esac
