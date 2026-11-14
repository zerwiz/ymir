#!/usr/bin/env bash
# gather.sh — gather a batch of errand branches into ONE push and ONE PR.
#
# WHY (RULES/08, appended 2026-11-12). The Allfather's word: "if multiple agents are sent out at
# the same time, it's much better to merge the branches locally into one push … so everybody is
# going through the gates." Errands dispatched together (brief mode `batch`) commit on their own
# `eindri/<id>` branches and never push. This door is the helm's one road for the rest, so the
# same steps run the same way every time:
#
#   1 · fetch origin, and make ONE integration worktree from fresh origin/main
#       (through bin/forge/yggdrasil.sh — RULES/08.2);
#   2 · merge each named branch, in the order given, with a merge commit that carries the
#       errand's one-line acclaim. On a CONFLICT it stops, names the branch and the files, and
#       leaves the worktree mid-merge for the helm to resolve there; `--continue <batch>` resumes;
#   3 · run the pre-push gates ONCE (.githooks/pre-push, the same file the hook seats) on the
#       gathered head;
#   4 · push that one branch and open ONE PR whose body lists every errand and its acclaim;
#   5 · record the batch in the well, and append `done: shipped in PR <url>` to each errand's
#       status, so `--finished` never gathers it twice.
#
# Usage:
#   gather.sh <id|branch>… [--dry-run] [--no-pr] [--house <h> --fleet <f>]
#   gather.sh --finished   [--dry-run] [--no-pr] [--house <h> --fleet <f>]
#   gather.sh --continue <batch> [--no-pr] [--house <h> --fleet <f>]
#   gather.sh --list-finished
#
#   <id>      an errand id: gathers branch eindri/<id>, acclaim from state/<id>.status
#   <branch>  any local branch with a slash (a helm branch, e.g. hoenir/quiet-helm-test)
#   --finished       every errand whose last status line is `done:` and says "not pushed",
#                    whose eindri/<id> branch exists here and is not yet on origin/main
#   --dry-run        say what would be merged, merge nothing, push nothing
#   --no-pr          gather, gate and stop: no push, no PR (the helm ships by hand)
#   --house/--fleet  the PR signature (RULES/44); also GATHER_HOUSE / GATHER_FLEET. Never invented.
#
# Env: GATHER_STATE (default <main checkout>/state) · GATHER_REMOTE (origin) · GATHER_BASE (main)
#      GATHER_SKIP_WELL=1 (tests) · GATHER_GATES (default .githooks/pre-push in the worktree)
#
# Exit: 0 gathered (or would, on --dry-run) · 1 a fault · 2 usage · 3 a merge conflict (named).
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HERE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# The MAIN checkout: a worktree's common git dir sits inside it, and the errands' state lives there.
COMMON="$(git -C "$HERE_ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
MAIN_ROOT="${GATHER_REPO:-$( [ -n "$COMMON" ] && dirname "$COMMON" || printf '%s' "$HERE_ROOT")}"
STATE="${GATHER_STATE:-$MAIN_ROOT/state}"
REMOTE="${GATHER_REMOTE:-origin}"
BASE="${GATHER_BASE:-main}"
HOUSE="${GATHER_HOUSE:-}"
FLEET="${GATHER_FLEET:-}"

DRY=0; NOPR=0; FINISHED=0; LIST=0; CONTINUE=""
ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
    -h|--help) sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --dry-run) DRY=1 ;;
    --no-pr) NOPR=1 ;;
    --finished) FINISHED=1 ;;
    --list-finished) LIST=1 ;;
    --continue) CONTINUE="${2-}"; shift ;;
    --house) HOUSE="${2-}"; shift ;;
    --fleet) FLEET="${2-}"; shift ;;
    -*) printf 'error: unknown flag %s\nhelp: bin/forge/gather.sh --help\n' "$1" >&2; exit 2 ;;
    *) ARGS+=("$1") ;;
  esac
  shift
done

err() { printf 'error: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf 'help: %s\n' "$2" >&2; exit "${3:-1}"; }
g() { git -C "$MAIN_ROOT" "$@"; }

# plan 290 §3 — the shared law every outward door keeps (bin/forge/warden-lib.sh). A gather pushes a
# branch and opens a PR, so it acts only on the operator's own repository and only as the identity
# this machine names for the duty. `--dry-run` and `--no-pr` write nothing outward, but the repository
# is judged either way: a batch aimed at someone else's tree is refused before any work is done.
. "$HERE_ROOT/bin/forge/warden-lib.sh"
warden_begin gather || err "this machine cannot be named from the fleet registry"
GATHER_REPO_NAME="$(warden_repo_of "$MAIN_ROOT")" || err "$MAIN_ROOT has no readable origin, so the repository a batch would push to is unknown"
WARDEN_REPOS="$GATHER_REPO_NAME"
warden_require_repos "$GATHER_REPO_NAME" || err "this batch would push to $GATHER_REPO_NAME, which is not in the operator's registry (bin/forge/warden-lib.sh rule 2)"

# ── who is finished ─────────────────────────────────────────────────────────
# acclaim_of <id> — the last `done:` line of the errand's status, without the word.
acclaim_of() {
  local f="$STATE/$1.status"
  [ -r "$f" ] || { printf '(no status line)'; return 0; }
  grep -E '^done:' "$f" | tail -1 | sed 's/^done:[[:space:]]*//' | cut -c1-200
}
finished_ids() {
  local f id last
  for f in "$STATE"/*.status; do
    [ -r "$f" ] || continue
    id="$(basename "$f" .status)"
    last="$(grep -v '^[[:space:]]*$' "$f" | tail -1)"
    case "$last" in done:*"not pushed"*) ;; *) continue ;; esac
    g show-ref --verify --quiet "refs/heads/eindri/$id" || continue
    # already on the base? then it shipped some other way
    g merge-base --is-ancestor "eindri/$id" "$REMOTE/$BASE" 2>/dev/null && continue
    printf '%s\n' "$id"
  done
}

if [ "$LIST" = 1 ]; then
  ids="$(finished_ids)"; n="$(printf '%s' "$ids" | grep -c . || true)"
  printf 'finished[%s]{id,branch,acclaim}:\n' "$n"
  while IFS= read -r id; do [ -n "$id" ] && printf '  "%s","eindri/%s","%s"\n' "$id" "$id" "$(acclaim_of "$id" | tr '"' "'")"; done <<<"$ids"
  exit 0
fi

# ── the manifest: one file per batch, so a conflict can be resumed ───────────
GDIR="$STATE/gather"
mkdir -p "$GDIR" || err "cannot write $GDIR"

if [ -n "$CONTINUE" ]; then
  MANIFEST="$GDIR/$CONTINUE.manifest"
  [ -r "$MANIFEST" ] || err "no batch named $CONTINUE" "ls $GDIR"
  BATCH="$CONTINUE"
  WTP="$(grep '^worktree=' "$MANIFEST" | cut -d= -f2-)"
  [ -d "$WTP" ] || err "the batch worktree $WTP is gone" "start the batch again"
  if [ -n "$(git -C "$WTP" diff --name-only --diff-filter=U)" ]; then
    err "conflicts remain in $WTP: $(git -C "$WTP" diff --name-only --diff-filter=U | tr '\n' ' ')" "resolve, git add, git commit, then --continue $BATCH" 3
  fi
  if git -C "$WTP" rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then
    err "the merge in $WTP is resolved but not committed" "git -C $WTP commit --no-edit, then --continue $BATCH"
  fi
  # the branch the helm just resolved is now merged
  pend="$(grep '^pending=' "$MANIFEST" | head -1 | cut -d= -f2-)"
  if [ -n "$pend" ]; then
    sed -i "0,/^pending=/s//merged=/" "$MANIFEST"
  fi
else
  # resolve what to gather
  if [ "$FINISHED" = 1 ]; then
    while IFS= read -r id; do [ -n "$id" ] && ARGS+=("$id"); done <<<"$(finished_ids)"
  fi
  [ "${#ARGS[@]}" -gt 0 ] || err "nothing to gather" "name errand ids or branches, or pass --finished (see --list-finished)" 2

  # rows: branch<TAB>id<TAB>acclaim
  ROWS=""
  for a in "${ARGS[@]}"; do
    case "$a" in
      */*) br="$a"; id="${a#eindri/}"; [ "$id" = "$a" ] && id="-"
           if [ "$id" = "-" ]; then acc="helm branch"; else acc="$(acclaim_of "$id")"; fi ;;
      *)   br="eindri/$a"; id="$a"; acc="$(acclaim_of "$a")" ;;
    esac
    g show-ref --verify --quiet "refs/heads/$br" || err "no local branch $br" "the errand commits on eindri/<id>; check git branch --list 'eindri/*'"
    case "$ROWS" in *"$br	"*) continue ;; esac
    ROWS="${ROWS}${br}	${id}	${acc}
"
  done

  if [ "$DRY" = 1 ]; then
    n="$(printf '%s' "$ROWS" | grep -c . || true)"
    printf 'gather[%s]{branch,errand,commits_ahead,acclaim}:\n' "$n"
    while IFS=$'\t' read -r br id acc; do
      [ -n "$br" ] || continue
      ahead="$(g rev-list --count "$REMOTE/$BASE..$br" 2>/dev/null || echo '?')"
      printf '  "%s","%s","%s","%s"\n' "$br" "$id" "$ahead" "$(printf '%s' "$acc" | tr '"' "'")"
    done <<<"$ROWS"
    printf 'dry-run: would merge these into one worktree from %s/%s, gate once, push once, open one PR\n' "$REMOTE" "$BASE"
    exit 0
  fi

  if [ "$NOPR" = 0 ]; then
    [ -n "$HOUSE" ] && [ -n "$FLEET" ] || err "the PR signature needs --house and --fleet (or GATHER_HOUSE/GATHER_FLEET)" "pass them, or --no-pr to gather and gate only"
  fi

  g fetch -q "$REMOTE" "$BASE" || err "could not fetch $REMOTE $BASE"
  BATCH="gather-$(date -u +%Y%m%d-%H%M%S)"
  out="$(bash "$MAIN_ROOT/bin/forge/yggdrasil.sh" create "$BATCH" --repo "$MAIN_ROOT" --base "$REMOTE/$BASE" 2>&1)" \
    || err "could not make the integration worktree: $out"
  WTP="$MAIN_ROOT/.yggdrasil/$BATCH"
  MANIFEST="$GDIR/$BATCH.manifest"
  {
    printf 'batch=%s\nworktree=%s\nbranch=yggdrasil/%s\nbase=%s/%s\n' "$BATCH" "$WTP" "$BATCH" "$REMOTE" "$BASE"
    while IFS=$'\t' read -r br id acc; do [ -n "$br" ] && printf 'todo=%s\t%s\t%s\n' "$br" "$id" "$acc"; done <<<"$ROWS"
  } >"$MANIFEST"
  printf 'gather: batch %s in %s\n' "$BATCH" "$WTP"
fi

# ── merge what is left ──────────────────────────────────────────────────────
while :; do
  line="$(grep '^todo=' "$MANIFEST" | head -1)"
  [ -n "$line" ] || break
  IFS=$'\t' read -r br id acc <<<"${line#todo=}"
  msg="gather: $br — $acc"
  if git -C "$WTP" merge --no-ff --no-edit -m "$msg" "$br" >/dev/null 2>&1; then
    sed -i "0,/^todo=/s//merged=/" "$MANIFEST"
    printf 'gather: merged %s\n' "$br"
  else
    files="$(git -C "$WTP" diff --name-only --diff-filter=U | tr '\n' ' ')"
    sed -i "0,/^todo=/s//pending=/" "$MANIFEST"
    printf 'conflict[1]{branch,files,worktree}:\n  "%s","%s","%s"\n' "$br" "$files" "$WTP" >&2
    printf 'help: resolve in %s, git add, git commit --no-edit, then: bin/forge/gather.sh --continue %s\n' "$WTP" "$BATCH" >&2
    exit 3
  fi
done

HEAD_SHA="$(git -C "$WTP" rev-parse HEAD)"
BRANCH="$(grep '^branch=' "$MANIFEST" | cut -d= -f2-)"

# ── the gates, ONCE ─────────────────────────────────────────────────────────
GATES="${GATHER_GATES:-$WTP/.githooks/pre-push}"
if [ -r "$GATES" ]; then
  remote_sha="$(git -C "$WTP" rev-parse "$REMOTE/$BASE")"
  printf 'refs/heads/%s %s refs/heads/%s %s\n' "$BRANCH" "$HEAD_SHA" "$BRANCH" "$remote_sha" \
    | ( cd "$WTP" && bash "$GATES" ) || err "the gates refused the gathered head $HEAD_SHA — see the rows above" "fix in $WTP, commit, then --continue $BATCH"
  printf 'gather: gates passed once on %s\n' "${HEAD_SHA:0:12}"
else
  err "no gates at $GATES" "a batch never ships ungated"
fi
printf 'gated=%s\n' "$HEAD_SHA" >>"$MANIFEST"

if [ "$NOPR" = 1 ]; then
  printf 'gather: gathered and gated on %s in %s — not pushed (--no-pr)\n' "$BRANCH" "$WTP"
  exit 0
fi
[ -n "$HOUSE" ] && [ -n "$FLEET" ] || err "the PR signature needs --house and --fleet" "pass them, or GATHER_HOUSE/GATHER_FLEET"
# rule 3: the hand must be the identity this machine names for this duty
warden_require_identity || err "the identity this machine names for gather does not answer (bin/forge/warden-lib.sh rule 3)"

# ── one push, one PR ────────────────────────────────────────────────────────
# The gates above ARE the pre-push hook's text, run once on this exact sha; the push
# skips the hook so the same suite does not run twice. Refuse if the head moved since.
[ "$(git -C "$WTP" rev-parse HEAD)" = "$HEAD_SHA" ] || err "the head moved after the gates ran" "--continue $BATCH to gate again"
git -C "$WTP" push -q --no-verify -u "$REMOTE" "$BRANCH" || err "push of $BRANCH failed"

BODY="$(mktemp)"; trap 'rm -f "$BODY"' EXIT
{
  printf 'MERGE WITH A MERGE COMMIT — this is a gathered batch; a squash erases every errand'"'"'s history.\n\n'
  printf 'One batch, gathered by `bin/forge/gather.sh` (RULES/08, the batch road): every errand below\n'
  printf 'committed on its own branch and never pushed; the helm merged them in one worktree from\n'
  printf 'fresh `%s/%s` and the gates ran once on head `%s`.\n\n' "$REMOTE" "$BASE" "${HEAD_SHA:0:12}"
  printf '**Merge with a merge commit, not squash:** squashing erases each errand'"'"'s history and leaves git\n'
  printf 'thinking the branches are unmerged. `bin/forge/merge-method.sh` picks the flag for the tools.\n\n'
  printf '| Branch | Errand | Acclaim |\n|---|---|---|\n'
  grep -E '^merged=' "$MANIFEST" | while IFS=$'\t' read -r br id acc; do
    printf '| `%s` | %s | %s |\n' "${br#merged=}" "$id" "$(printf '%s' "$acc" | tr '|' '/')"
  done
} >"$BODY"
n="$(grep -c '^merged=' "$MANIFEST")"
url="$(cd "$WTP" && bash bin/forge/pr-open.sh --role helm --house "$HOUSE" --fleet "$FLEET" --errand "$BATCH" \
  --authority "RULES/08 batch road; the Allfather merges" --proves "gates passed once on ${HEAD_SHA:0:12}" \
  --title "gather: $n errands in one batch ($BATCH)" --body-file "$BODY")" || err "the PR could not be opened (the branch is pushed)" "open it by hand from $WTP"
case "$url" in
  https://*/pull/[0-9]*) ;;
  *) err "the PR opener printed no pull-request URL (got '${url:-nothing}') — nothing is marked shipped" "the branch is pushed; open the PR by hand from $WTP, then re-run" ;;
esac
printf 'pr=%s\n' "$url" >>"$MANIFEST"
# rule 4: every outward act is a Rune — what was pushed, where, as whom, and on what verdict.
warden_runes gathered "pushed $BRANCH ($n errand(s)) to $GATHER_REPO_NAME and opened $url — gates passed once on ${HEAD_SHA:0:12}" >/dev/null || true

# ── the record ──────────────────────────────────────────────────────────────
grep -E '^merged=' "$MANIFEST" | while IFS=$'\t' read -r br id acc; do
  [ "$id" = "-" ] && continue
  printf 'done: shipped in PR %s (batch %s)\n' "$url" "$BATCH" >>"$STATE/$id.status"
done
if [ "${GATHER_SKIP_WELL:-0}" != 1 ] && [ -r "$MAIN_ROOT/bin/records/mimir.sh" ]; then
  bash "$MAIN_ROOT/bin/records/mimir.sh" observe \
    "Batch $BATCH gathered $n branches into one PR $url; gates ran once on ${HEAD_SHA:0:12}. Branches: $(grep -E '^merged=' "$MANIFEST" | cut -f1 | sed 's/^merged=//' | tr '\n' ' ')" \
    --source helm --task "$BATCH" --tags gather,batch,delivery >/dev/null 2>&1 \
    || printf 'warning: the well did not take the batch record\n' >&2
fi
printf 'gather[1]{batch,branches,head,pr}:\n  "%s","%s","%s","%s"\n' "$BATCH" "$n" "${HEAD_SHA:0:12}" "$url"
