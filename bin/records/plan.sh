#!/usr/bin/env bash
# plan.sh — the plan ledger: create the NEXT numbered plan and its index row.
#
#   plan.sh new <slug> --title "<title>" [--realm R] [--project P] [--from-meeting <id>]
#   plan.sh list                      # the ledger's rows (number · title · status)
#   plan.sh next                      # the number the next plan would take (read-only)
#   plan.sh from-meeting <id>         # the plans a meeting produced (reads the headers)
#
# `--from-meeting <id>` writes `from_meeting: <id>` into the plan's HEADER, in the same act
# as the plan is created — the join from a meeting to what it produced (plan 228 §5 · F5).
# The reverse join lives in `bin/records/meetings.sh plans <id>`, which reads these headers
# and refuses rather than guessing when a plan carries none.
#
# THE LEDGER (the house law): a plan belongs to whoever owns the work — plan 240.
#
#   --scope project   (default)  svartalfaheim/<realm>/projects/<project>/plans/
#   --scope realm     (company)  svartalfaheim/<realm>/plans/
#   --scope machine              hodd/machines/<host>/plans/
#   --scope personal             hodd/plans/
#
# Numbering is per shelf, after its index's highest; a number is never reused IN a shelf.
# A shelf under a scope that is allowed to grow (realm · machine · personal) is created on
# first use with its index; a PROJECT shelf is never created silently — an unknown project
# is a typo, and guessing it would file work in a directory nobody reads.
# Extracted from the Pi extension so every harness reaches it (behaviour in bin/).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
hoard="$(bash "$ROOT/bin/vault/hodd.sh" path 2>/dev/null || true)"
[ -n "$hoard" ] || { printf 'plan: no home (bin/vault/hodd.sh path answered nothing)\n' >&2; exit 1; }
HOME_DIR="$(dirname "$hoard")"
REALM="${YMIR_REALM:-work}"; PROJECT="${YMIR_PROJECT:-ymir}"
SCOPE="${YMIR_PLAN_SCOPE:-project}"; OWNER=""
LEDGER="$HOME_DIR/svartalfaheim/$REALM/projects/$PROJECT/plans"
[ -d "$LEDGER" ] || LEDGER="$HOME_DIR/svartalfaheim/$REALM/workspace/$PROJECT/plans"
# the ledger is found, never guessed: the project may live under any realm (work, a house realm)
[ -d "$LEDGER" ] || LEDGER="$(find "$HOME_DIR/svartalfaheim" -maxdepth 4 -type d -path "*/projects/$PROJECT/plans" 2>/dev/null | head -1)"
[ -d "$LEDGER" ] || LEDGER="$(find "$HOME_DIR/svartalfaheim" -maxdepth 4 -type d -path "*/workspace/$PROJECT/plans" 2>/dev/null | head -1)"
[ -d "$LEDGER" ] || { printf 'plan: no ledger for %s/%s (looked in projects/ and workspace/)\n' "$REALM" "$PROJECT" >&2; exit 1; }

# ── the scopes (plan 240) — a plan belongs to whoever owns the work ───────────
seed_shelf_index() {   # <scope> <owner> — the shelf's own index, written once
  local scope="$1" owner="$2" f="$LEDGER/README.md"
  [ -f "$f" ] && return 0
  {
    case "$scope" in
      machine)
        printf '# %s'"'"'s plans — the machine'"'"'s own ledger\n\n' "$owner"
        printf '**A machine plans for itself here.** Its power, its thermals, its fans, its rail, its repairs —\n'
        printf 'deliberately *not* a project'"'"'s ledger, because a plan belongs to whoever owns the work.\n\n' ;;
      realm|company)
        printf '# %s — the realm'"'"'s plans\n\n' "$owner"
        printf '**A company (realm) plans for itself here** — strategy, money, the house'"'"'s own work —\n'
        printf 'deliberately *not* a project'"'"'s ledger (plan 240).\n\n' ;;
      personal)
        printf '# The Allfather'"'"'s plans\n\n'
        printf '**His own working plans live here** — personal work, schedules, errands that belong to no project\n'
        printf 'and no machine (plan 240).\n\n' ;;
      *)  printf '# Plans — %s\n\n' "$owner" ;;
    esac
    printf '```\nplan[3]{rule,why}:\n'
    printf '  "numbering is per shelf","%s 001 is this shelf'"'"'s first plan; no number is reused within a shelf"\n' "$owner"
    printf '  "one index: this file","every plan gets a row here, in the same change that creates it"\n'
    printf '  "the owner is in the plan header","owner · owner_name, so a plan keeps its provenance if it ever moves"\n'
    printf '```\n\n## The plans\n'
  } > "$f"
}

set_ledger_for_scope() {   # <scope> <owner> — resolve (and, where legal, create) the shelf
  local scope="$1" owner="$2"
  case "$scope" in
    project) : ;;                      # resolved above, unchanged, never created here
    realm|company)
      [ -n "$owner" ] || { printf 'plan: --scope realm needs --owner <realm>\n' >&2; return 2; }
      LEDGER="$HOME_DIR/svartalfaheim/$owner/plans" ;;
    machine)
      [ -n "$owner" ] || owner="${HOSTNAME%%.*}"
      LEDGER="$HOME_DIR/hodd/machines/$owner/plans" ;;
    personal) LEDGER="$HOME_DIR/hodd/plans" ;;
    *) printf 'plan: unknown scope %s (project|realm|machine|personal)\n' "$scope" >&2; return 2 ;;
  esac
  [ "$scope" = project ] && return 0
  mkdir -p "$LEDGER" 2>/dev/null || { printf 'plan: cannot create %s\n' "$LEDGER" >&2; return 2; }
  seed_shelf_index "$scope" "${owner:-$REALM}"
  return 0
}

# ── Rule 45 — a number is taken from the CURRENT ledger, never from a stale one ──
# WHY (2026-11-04): this seat sat seven commits behind origin, asked for the next
# number, and was told 182. The plan was written — but another machine had taken 182
# the same day, so two plans shared a number and one had to be renumbered. Numbering
# is a DISTRIBUTED allocation: the ledger is git, and an allocation without a fetch
# is a guess dressed as a fact.
ledger_state() {   # fresh | behind:<n> | unverified:<why>
  local repo br behind
  command -v git >/dev/null 2>&1 || { printf 'unverified:no git on PATH'; return 0; }
  repo="$(git -C "$LEDGER" rev-parse --show-toplevel 2>/dev/null)" || { printf 'unverified:the home is not a git repository'; return 0; }
  [ "${YMIR_OFFLINE:-0}" = "1" ] && { printf 'unverified:YMIR_OFFLINE=1'; return 0; }
  git -C "$repo" fetch --quiet --prune origin 2>/dev/null || { printf 'unverified:origin is unreachable'; return 0; }
  br="$(git -C "$repo" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"
  br="${br:-main}"
  git -C "$repo" rev-parse --verify -q "origin/$br" >/dev/null 2>&1 || { printf 'unverified:origin/%s is missing' "$br"; return 0; }
  behind="$(git -C "$repo" rev-list --count "HEAD..origin/$br" 2>/dev/null || printf 0)"
  if [ "${behind:-0}" = "0" ]; then printf 'fresh'; else printf 'behind:%s' "$behind"; fi
}

# READING a number is harmless; TAKING one is not. Only `new` calls this.
refuse_stale_ledger() {
  local s repo; s="$(ledger_state)"
  case "$s" in
    fresh) : ;;
    behind:*)
      if [ "${YMIR_ALLOW_STALE_LEDGER:-0}" = "1" ]; then
        printf 'plan: WARNING — the ledger is %s commit(s) behind origin and a number was taken anyway (YMIR_ALLOW_STALE_LEDGER=1)\n' "${s#behind:}" >&2
      else
        repo="$(git -C "$LEDGER" rev-parse --show-toplevel 2>/dev/null)"
        printf 'plan: REFUSED — the ledger is %s commit(s) behind origin, so the next number is not this seat to take.\n' "${s#behind:}"
        printf 'plan: it may already belong to a plan written elsewhere (that is how 182 was written twice, 2026-11-04).\n'
        printf 'plan: run  git -C "%s" pull --ff-only  then ask again; the ledger is %s\n' "$repo" "$LEDGER"
        printf 'plan: loud override when you know better:  YMIR_ALLOW_STALE_LEDGER=1\n'
        return 1
      fi ;;
    unverified:*)
      printf 'plan: note — the ledger is UNVERIFIED against origin (%s): a number taken now may already be taken elsewhere.\n' "${s#unverified:}" >&2 ;;
  esac
  return 0
}

next_number() { ls "$LEDGER" 2>/dev/null | grep -oE '^[0-9]+' | sort -n | tail -1 | awk '{print ($1+1)}' ; }

case "${1:-}" in
  -h|--help|"") sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  next)
    # next [--scope S] [--owner O] [--all]
    shift; while [ $# -gt 0 ]; do case "$1" in
      --scope) SCOPE="${2-}"; shift 2 ;;
      --owner) OWNER="${2-}"; shift 2 ;;
      --all) SCOPE="all"; shift ;;
      *) shift ;;
    esac; done
    if [ "$SCOPE" = all ]; then
      printf 'shelves[5]{scope,owner,path,next}\n'
      for d in "$HOME_DIR"/svartalfaheim/*/plans "$HOME_DIR"/svartalfaheim/*/projects/*/plans \
               "$HOME_DIR"/hodd/machines/*/plans "$HOME_DIR"/hodd/plans; do
        [ -d "$d" ] || continue
        LEDGER="$d"
        printf '  "%s","%s","%s","%s"\n' "$(basename "$(dirname "$d")")" "$(basename "$d")" "${d#$HOME_DIR/}" "$(next_number)"
      done
      exit 0
    fi
    set_ledger_for_scope "$SCOPE" "${OWNER:-$PROJECT}" || exit 2
    n="$(next_number)"; printf '%s\n' "${n:-1}" ;;
  list)
    # list [--scope S] [--owner O] [--all]
    shift; ALL=0; while [ $# -gt 0 ]; do case "$1" in
      --scope) SCOPE="${2-}"; shift 2 ;;
      --owner) OWNER="${2-}"; shift 2 ;;
      --all) ALL=1; shift ;;
      *) shift ;;
    esac; done
    if [ "$ALL" = 1 ]; then
      for d in "$HOME_DIR"/svartalfaheim/*/projects/*/plans "$HOME_DIR"/svartalfaheim/*/plans \
               "$HOME_DIR"/hodd/machines/*/plans "$HOME_DIR"/hodd/plans; do
        [ -f "$d/README.md" ] || continue
        printf '# %s\n' "${d#$HOME_DIR/}"
        grep -hE '^\| [0-9]+ \|' "$d/README.md" 2>/dev/null | sed -E 's/^\| ([0-9]+) \| \[([^]]*)\].*/  #\1 \2/' | tail -20
        grep -hE '^- \*\*[0-9]+\*\*|^- \*\*[0-9]{4}\*\*' "$d/README.md" 2>/dev/null | sed -E 's/^- \*\*([0-9]+)\*\* [—-] \[(.*)\]\(.*/  #\1 \2/' | tail -20
      done
      exit 0
    fi
    set_ledger_for_scope "$SCOPE" "${OWNER:-$PROJECT}" || exit 2
    grep -hE '^\| [0-9]+ \|' "$LEDGER/README.md" 2>/dev/null | sed -E 's/^\| ([0-9]+) \| \[([^]]*)\].*/#\1 \2/' | tail -20
    grep -hE '^- \*\*[0-9]+\*\*' "$LEDGER/README.md" 2>/dev/null | sed -E 's/^- \*\*([0-9]+)\*\* [—-] \[(.*)\]\(.*/  #\1 \2/' | tail -20 ;;
  new)
    slug="${2:-}"; shift 2 2>/dev/null || true
    title=""; from_meeting=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --title) title="${2-}"; shift 2 ;;
        --realm) REALM="${2-}"; shift 2 ;;
        --project) PROJECT="${2-}"; shift 2 ;;
        --scope) SCOPE="${2-}"; shift 2 ;;
        --owner) OWNER="${2-}"; shift 2 ;;
        --from-meeting) from_meeting="${2-}"; shift 2 ;;
        *) shift ;;
      esac
    done
    [ -n "$slug" ] && [ -n "$title" ] || { printf 'plan: new needs <slug> and --title\n' >&2; exit 2; }
    [ "$SCOPE" = project ] && OWNER="${OWNER:-$PROJECT}"
    set_ledger_for_scope "$SCOPE" "${OWNER:-}" || exit 2
    refuse_stale_ledger || exit 1
    n="$(next_number)"; n="${n:-1}"; pad="$(printf '%03d' "$n")"; f="$LEDGER/${pad}-${slug}.md"
    [ -e "$f" ] && { printf 'plan: %s exists\n' "$f" >&2; exit 1; }
    {
      printf '# Plan %s - %s\n' "$n" "$title"
      printf 'owner: %s\nowner_name: %s\n' "$SCOPE" "${OWNER:-$PROJECT}"
      [ -n "$from_meeting" ] && printf 'from_meeting: %s\n' "$from_meeting"
      printf '\n**Opened %s.**\n' "$(date +%F)"
    } > "$f"
    printf '| %s | [%s](%s) | opened |\n' "$n" "$title" "$(basename "$f")" >> "$LEDGER/README.md"
    printf 'created %s\n  shelf: %s (%s)\n' "$f" "$LEDGER" "$SCOPE" ;;
  from-meeting)
    # The join, read back out of the ledger: which plans a meeting produced. It refuses
    # rather than guessing — a plan with no `from_meeting:` header is never assumed to be one.
    want="${2:-}"; [ -n "$want" ] || { printf 'plan: from-meeting needs a meeting id\n' >&2; exit 2; }
    found=0
    for p in "$LEDGER"/*.md; do
      [ -e "$p" ] || continue
      [ "$(basename "$p")" = "README.md" ] && continue
      if head -20 "$p" | grep -qE "^\**from_meeting\**\s*:\s*\`?$want\`?\s*$"; then
        printf '  "%s","%s"\n' "$want" "$(basename "$p")"
        found=$((found+1))
      fi
    done
    if [ "$found" = 0 ]; then
      printf 'plan: no plan header names meeting %s (from_meeting: %s)\n' "$want" "$want" >&2
      exit 1
    fi ;;
  *) printf 'error: unknown action %s\nhelp: plan.sh [new <slug> --title <t> [--from-meeting <id>] | list | next | from-meeting <id>]\n' "$1" >&2; exit 2 ;;
esac
