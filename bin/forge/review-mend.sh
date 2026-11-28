#!/usr/bin/env bash
# review-mend.sh — the refusal becomes a router (plan 233 §13/13a/13b)
set -u
VERSION="1.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; -h|--help|"") printf 'usage: review-mend.sh <pr> [--dry-run] [--only mechanical|route|all] [--report]\n'; exit 0 ;; esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)"
. "$ROOT/bin/vault/hoard-lib.sh"
ymir_home_root YMIR_HOME

PR=""; DRY=0; ONLY="all"; REPORT=0; MEND_OTHERS=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1; shift ;;
    --only) ONLY="${2:-all}"; shift 2 ;;
    --report) REPORT=1; shift ;;
    --mend-others) MEND_OTHERS=1; shift ;;
    *) if [ -z "$PR" ]; then PR="$1"; shift; else shift; fi ;;
  esac
done
case "$PR" in ''|*[!0-9]*) printf 'review-mend: refused — no PR number\n' >&2; exit 3 ;; esac

# report mode
if [ "$REPORT" = "1" ]; then
  printf '{"pr":%s,"rungs":[]}\n' "$PR"
  exit 0
fi

# ONE MACHINE MENDS: THE HEART (2026-11-27). Every seat that ran this door committed and pushed onto the
# same open pull requests, so one branch collected commits from machines nobody had asked. Only the heart
# mends, routes or seats a fixer. A dry run changes nothing and is allowed anywhere.
if [ "$DRY" = "0" ]; then
  _roles="$(timeout 20 bash "$ROOT/bin/fleet/role.sh" resolve 2>/dev/null | head -1 || true)"
  case ",$(printf '%s' "$_roles" | tr ' ' ',')," in
    *,heart,*) ;;
    *) printf 'review-mend: refused — only the heart mends a pull request (this machine: %s).\n' "${_roles:-no role}" >&2
       printf 'next: change nothing and push nothing. Send your findings to the author of PR #%s (RULES/08).\n' "$PR" >&2
       exit 4 ;;
  esac
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

# route step — a message to another machine is an act, so a dry run sends none
if [ "$DRY" = "0" ] && { [ "$ONLY" = "route" ] || [ "$ONLY" = "all" ]; }; then
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
MECHANICAL=0
if [ "$ONLY" = "mechanical" ] || [ "$ONLY" = "all" ]; then MECHANICAL=1; fi
# NEVER PUSH TO ANOTHER PERSON'S BRANCH UNASKED, and never publish a private address (2026-11-27).
if [ "$MECHANICAL" = "1" ] && [ "$DRY" = "0" ]; then
  _author="$(gh pr view "$PR" --json author -q .author.login 2>/dev/null || true)"
  _me="$(gh api user -q .login 2>/dev/null || true)"
  if [ "$MEND_OTHERS" = "0" ] && { [ -z "$_me" ] || [ "$_author" != "$_me" ]; }; then
    printf 'skip: PR #%s belongs to %s — no commit without being asked (--mend-others)\n' "$PR" "${_author:-unknown}"
    MECHANICAL=0
  else
    case "$(git config user.email 2>/dev/null)" in
      *@users.noreply.github.com) ;;
      *) printf "skip: git user.email is not a GitHub no-reply address — no commit into a public repository\n"
         MECHANICAL=0 ;;
    esac
  fi
fi
if [ "$MECHANICAL" = "1" ]; then
  # THE CALLER'S TREE IS NEVER SWITCHED (2026-11-28). A mend works in a temporary worktree of the pull
  # request's head. A dry run fetches and checks out nothing: it reads the head only if it is already here.
  MEND_DIR=""; HERE_DIR="$PWD"
  if [ "$DRY" = "0" ]; then
    MEND_DIR="$(mktemp -d)"
    if git fetch -q origin "$BRANCH" 2>/dev/null && git worktree add -q --detach "$MEND_DIR/tree" FETCH_HEAD 2>/dev/null; then
      trap 'cd "$HERE_DIR" && git worktree remove --force "$MEND_DIR/tree" >/dev/null 2>&1; rm -rf "$MEND_DIR"' EXIT
      cd "$MEND_DIR/tree" || exit 3
      HEAD_REF=HEAD
    else
      printf 'skip: the head of #%s could not be checked out — nothing mended\n' "$PR"
      rm -rf "$MEND_DIR"; MEND_DIR=""; HEAD_REF=""
    fi
  elif git rev-parse -q --verify "origin/$BRANCH" >/dev/null 2>&1; then
    HEAD_REF="origin/$BRANCH"
  else
    printf 'dry-run: origin/%s is not here — no mechanical rung read\n' "$BRANCH"; HEAD_REF=""
  fi
  # missing CHANGE LOG
  for f in $([ -n "$HEAD_REF" ] && git diff --name-only "origin/main...$HEAD_REF" 2>/dev/null); do
    git cat-file -e "$HEAD_REF:$f" 2>/dev/null || continue
    case "$f" in *.md)
      # A RENDERED DOCUMENT IS NOT A RECORD (2026-11-18). A generated file says so in its own head
      # ("**Generated by bin/gates/capabilities.sh**. Do not hand-edit.") and is rewritten from the
      # tree on every check, so a change-log appended here is erased by the next render and this
      # rung re-appends it for ever: PR #817 collected 18 identical "judge: change-log" commits and
      # the capability gate stayed red through all of them. The renderer owns its file; skip it.
      if git show "$HEAD_REF:$f" 2>/dev/null | head -15 | grep -qiE 'do not hand-edit|generated by '; then
        printf 'skip: %s is rendered from the tree — its generator owns it\n' "$f"
        continue
      fi
      if ! git show "$HEAD_REF:$f" 2>/dev/null | grep "## CHANGE LOG" >/dev/null; then
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
  if [ -n "$MEND_DIR" ]; then
    if [ "$MENDED" = "1" ] && ! git push -q origin "HEAD:refs/heads/$BRANCH" 2>/dev/null; then
      printf 'mend: the push to %s was refused — nothing landed\n' "$BRANCH" >&2
    fi
    cd "$HERE_DIR" || exit 3
  fi
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
exit 0
