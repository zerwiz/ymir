#!/usr/bin/env bash
# review-mend.sh — the refusal becomes a router (plan 233 §13/13a/13b)
set -u
VERSION="1.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; -h|--help|"") printf 'usage: review-mend.sh <pr> [--dry-run] [--only mechanical|route|all] [--report]\n'; exit 0 ;; esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)"
. "$ROOT/bin/vault/hoard-lib.sh"
ymir_home_root YMIR_HOME

PR=""; DRY=0; ONLY="all"; REPORT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1; shift ;;
    --only) ONLY="${2:-all}"; shift 2 ;;
    --report) REPORT=1; shift ;;
    *) if [ -z "$PR" ]; then PR="$1"; shift; else shift; fi ;;
  esac
done
case "$PR" in ''|*[!0-9]*) printf 'review-mend: refused — no PR number\n' >&2; exit 3 ;; esac

# report mode
if [ "$REPORT" = "1" ]; then
  printf '{"pr":%s,"rungs":[]}\n' "$PR"
  exit 0
fi

# 1. branch
BRANCH="$(gh pr view "$PR" --json headRefName -q .headRefName 2>/dev/null || true)"
if [ -z "$BRANCH" ]; then printf 'review-mend: refused — no branch/no PR\n' >&2; exit 3; fi

ERRAND_ID="$(printf '%s' "$BRANCH" | sed -n 's#^eindri/##p')"
HOST=""; SEAT=""; PANE=""
# try claims/roster/data
if [ -n "$ERRAND_ID" ]; then
  for f in "$YMIR_HOME/state/claims" "$YMIR_HOME/state/roster.json" "$YMIR_HOME/data/$ERRAND_ID/meta.json"; do
    [ -r "$f" ] && { :; }
  done
  if [ -d "$YMIR_HOME/data/$ERRAND_ID" ]; then
    HOST="$(grep -rhoE '"host"[[:space:]]*:[[:space:]]*"[^"]+"' "$YMIR_HOME/data/$ERRAND_ID" 2>/dev/null | head -1 | sed -E 's/.*"([^"]+)"$/\1/')" 
    SEAT="$(grep -rhoE '"seat"[[:space:]]*:[[:space:]]*"[^"]+"' "$YMIR_HOME/data/$ERRAND_ID" 2>/dev/null | head -1 | sed -E 's/.*"([^"]+)"$/\1/')" 
    PANE="$(grep -rhoE '"pane"[[:space:]]*:[[:space:]]*"[^"]+"' "$YMIR_HOME/data/$ERRAND_ID" 2>/dev/null | head -1 | sed -E 's/.*"([^"]+)"$/\1/')" 
  fi
fi

# route step
if [ "$ONLY" = "route" ] || [ "$ONLY" = "all" ]; then
  if [ -n "$HOST" ]; then
    TAILNET="$(python3 -c "import json,sys; d=json.load(open('$YMIR_HOME/hodd/data/fleet.json')); print(d['hosts'].get('$HOST',{}).get('tailnet',''))" 2>/dev/null)"
    if [ -n "$TAILNET" ]; then
      # liveness check via ssh (timeout)
      if ssh -o ConnectTimeout=5 -o BatchMode=yes "$TAILNET" 'true' 2>/dev/null; then
        if [ -n "$PANE" ]; then
          ssh "$TAILNET" "~/ymir/bin/agents/eindri-notify.sh --from review -- \"[review] #$PR refused; mend required\"" 2>/dev/null || true
        fi
        printf 'routed{author=%s,host=%s,pane=%s}\n' "${SEAT:-$ERRAND_ID}" "$HOST" "${PANE:-?}"
        # handled via route; still may need mechanical? For all, continue to mechanical? Plan: route first then fall through only if dark. If routed, done.
        exit 0
      else
        printf 'DARK %s (last seen unknown)\n' "$HOST"
      fi
    fi
  fi
fi

# 2. mechanical mends
MENDED=0
if [ "$ONLY" = "mechanical" ] || [ "$ONLY" = "all" ]; then
  # checkout branch in a temp clone? We operate in current repo worktree.
  git fetch origin "$BRANCH" 2>/dev/null || true
  git checkout "$BRANCH" 2>/dev/null || true
  # missing CHANGE LOG
  for f in $(git diff --name-only origin/main...HEAD 2>/dev/null); do
    [ -f "$f" ] || continue
    case "$f" in *.md)
      if ! grep -q "## CHANGE LOG" "$f" 2>/dev/null; then
        if [ "$DRY" = "1" ]; then
          printf 'rung: mechanical change-log for %s (dry-run)\n' "$f"
        else
          printf '\n## CHANGE LOG\n\n- %s — review-mend: added missing heading for #%s\n' "$(date +%Y-%m-%d)" "$PR" >> "$f"
          git add "$f"
          git commit -m "judge: change-log for #$PR" >/dev/null 2>&1 || true
          MENDED=1
          printf 'mended: change-log for %s\n' "$f"
        fi
      fi
      ;;
    esac
  done
fi

# 3. fixer errand
printf 'next: fixer:%s\n' "${ERRAND_ID:-review-mend-$PR}"

# ── THE REFUSAL CALLS SOMEONE (2026-11-12) ────────────────────────────────────────────────────────
# The Allfather, for the hundredth time: *"why dont he call anyone to resolve the problems."* Until now
# this door NAMED a fixer and did nothing — `next: fixer:<id>` was a promise no one kept, and a REFUSE
# sat until a hand noticed. A refusal now SEATS the fixer: its own worktree, its own brief carrying the
# findings verbatim, its own pane — through the one spawn path, exactly as a hand would.
# `--no-seat` keeps the old behaviour for a dry run or a test.
SEAT=1
for _a in "$@"; do [ "$_a" = "--no-seat" ] && SEAT=0; done
if [ "$DRY" = "0" ] && [ "$SEAT" = "1" ] && [ -x "$ROOT/bin/agents/einherjar-spawn.sh" ]; then
  _id="${ERRAND_ID:-review-mend-$PR}"
  _findings="$(mktemp)"
  { printf '# Task\n\nThe judge refused PR %s. Its findings, verbatim, are below: fix every one, prove each\nwith the command its ward names, push to the same branch, and report.\n\n```\n' "$PR"
    printf '%s\n' "${FINDINGS:-see state/eindri-reports/pr-$PR.md}"
    printf '```\n' ; } > "$_findings"
  if bin/agents/erindi-brief.sh "$_id" ymir --mode direct-PR >/dev/null 2>&1; then
    _brief="$ROOT/data/$_id/brief.md"
    if [ -f "$_brief" ]; then
      python3 - "$_brief" "$_findings" <<'PYSEAT'
import sys
b,f=sys.argv[1],sys.argv[2]
t=open(b,encoding="utf-8").read(); task=open(f,encoding="utf-8").read()
t=t.replace("# Task\n{TASK}", "# Task\n\n"+task.strip()+"\n",1)
open(b,"w",encoding="utf-8").write(t)
PYSEAT
    fi
    ( cd "$ROOT" && git worktree add -f ".yggdrasil/$_id" -b "eindri/$_id" origin/main >/dev/null 2>&1; ( cd ".yggdrasil/$_id" && git checkout -- .pi/extensions 2>/dev/null ) )
    if out="$(bash "$ROOT/bin/agents/einherjar-spawn.sh" "$_id" "$ROOT" --mode direct-PR --harness pi --force 2>&1)"; then
      printf 'seated[2]{errand,pane}:\n  "%s","%s"\n' "$_id" "$(printf '%s' "$out" | sed -n 's/.*target=\([^ ]*\).*/\1/p' | head -1)"
    else
      printf 'seat: REFUSED — %s\n' "$(printf '%s' "$out" | grep -m1 . )" >&2
    fi
  fi
  rm -f "$_findings"
fi
# brief path
printf 'brief: bin/agents/erindi-brief.sh -> %s\n' "state/eindri-reports/pr-$PR.md"

# 4. if nothing handled? ensure next present (already printed)
# exit code
if [ "$DRY" = "1" ]; then
  exit 0
fi
# push if mended
if [ "$MENDED" = "1" ]; then
  git push origin "$BRANCH" 2>/dev/null || true
fi
exit 0
