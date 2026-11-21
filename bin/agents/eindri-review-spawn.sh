#!/usr/bin/env bash
# eindri-review-spawn.sh — the review spine. FORSETI the Judge is sent after
# every ship: a worker's terminal `done` opens a dedicated review errand that
# audits the PR it opened, before the Allfather's seal.
#
# The delivery-gate law makes a PR the only way work leaves (the guards, the fix
# notes, the no-merge rule). This is the other half of that law: a PR is not
# "done" when it is pushed, it is done when it has been AUDITED. The spine sends
# the judge, once per task, and never again.
#
#   bin/agents/eindri-review-spawn.sh <task-id> [--pr-url <url>] [--branch <b>]
#                              [--dry-run] [--force]
#   bin/agents/eindri-review-spawn.sh --pr <pr-url> [--project <path>] [--dry-run] [--force]
#        the PR-ONLY mode (plan 206 §10.3a): judge a pull request this seat did not
#        author and has no errand record for. The marker is per HEAD, so a moved
#        head earns a fresh judgement and a second run in the same minute does not.
#
# It is called by the terminal act's done path (bin/agents/eindri-acclaim.sh) and can be
# run by hand. It reads the PR from the task's own record (state/<id>.status
# carries `done: opened PR <url>`), fills the fierce review brief for THIS task,
# and spawns a scout-kind `<id>-review` errand through the einherjar road:
#
#   bin/agents/einherjar-spawn.sh <id>-review <project> --scout --backend herdr
#       --harness pi --model <resolved by bin/model/agent-model.sh> --effort high
#
# The judge is read-only by charter (Forseti's card keeps edit:deny/write:deny),
# and the verdict lands on the wake road at state/eindri-reports/<id>-review.md.
#
# One per task. A `.reviewed` marker (state/.reviewed/<id>) is written only after
# the review is SEATED; a re-done never re-reviews, and a failed spawn leaves no
# marker so a retry can still seat the judge. YMIR_AUTO_REVIEW=off is the loud
# override (it prints why and exits 0); a failed spawn is never silent.
#
# Config (Rule 07 — env with one documented default):
#   YMIR_AUTO_REVIEW    on|off              default on
#   YMIR_REVIEW_HARNESS pi|...              default from the roster (Forseti), else pi
#   YMIR_REVIEW_MODEL   provider/model      default: resolved by bin/model/agent-model.sh forseti
#   YMIR_REVIEW_EFFORT  low..max            default high
#   YMIR_REVIEW_BACKEND tmux|herdr          default herdr
#   YMIR_REVIEW_DRY     0|1                 default 0; 1 = print the spawn line, seat nothing
#
# Output: Galdr TOON.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)}"

# The roots that live OUTSIDE the code tree resolve through the one door
# (Rule 04): the operator's home, not a path baked into the tree.
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _yc in "$SCRIPT_DIR/../vault/hoard-lib.sh" "$SCRIPT_DIR/../vault/hoard-lib.sh" "$SCRIPT_DIR/../../vault/hoard-lib.sh"; do
    [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yc
fi
hoard_state_dir YMIR_STATE_DIR

# ── THE HOUSE'S DATA SHELF, RESOLVED THROUGH THE ONE DOOR (2026-11-20) ────────
# The brief and context of an errand live in the OPERATOR'S home (`<home>/hodd/data`), never
# in the code checkout. This spine used to derive them from the project root — `$PROJECT/data` —
# and hand that path on as BROKK_DATA_OVERRIDE, so every review judge on a developer seat was
# refused by einherjar-spawn.sh with "the house is split — data resolves outside the home",
# after this door had already created `<checkout>/data/<id>-review/` beside the code (measured
# four times on 2026-11-20, each time moved home by hand). The resolver below is the same one
# einherjar-spawn.sh uses, so the two doors cannot disagree about where the records live.
YMIR_HOME_ROOT_RESOLVED=""
DATA_SHELF=""
if declare -f ymir_home_root >/dev/null 2>&1; then
  ymir_home_root YMIR_HOME_ROOT_RESOLVED 2>/dev/null || YMIR_HOME_ROOT_RESOLVED=""
  hoard_data_dir DATA_SHELF 2>/dev/null || DATA_SHELF=""
fi

inside_home() {  # <path> — the path lies inside the resolved home; no home resolved means yes
  local p=${1-}
  [ -z "$YMIR_HOME_ROOT_RESOLVED" ] && return 0
  [ -n "$p" ] || return 1
  case "$p" in
    "$YMIR_HOME_ROOT_RESOLVED"/*) return 0 ;;
  esac
  return 1
}

house_data() {  # <result-var> — the home's data shelf; an override may MOVE it, never take it out
  local result_var=${1-} cand="${BROKK_DATA_OVERRIDE:-}"
  [ -n "$result_var" ] || return 2
  if [ -n "$cand" ]; then
    if inside_home "$cand"; then
      printf -v "$result_var" '%s' "$cand"; return 0
    fi
    printf 'review-spawn: BROKK_DATA_OVERRIDE=%s lies outside the home (%s) — the records resolve from the home instead\n' \
      "$cand" "${YMIR_HOME_ROOT_RESOLVED:-none}" >&2
  fi
  [ -n "$DATA_SHELF" ] || return 1
  printf -v "$result_var" '%s' "$DATA_SHELF"
}

TEMPLATE="$ROOT/.agents/assets/templates/review-brief.template.md"

usage() {
  awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
}

case "${1:-}" in
  -h|--help|"") usage; exit 0 ;;
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
esac

ID=""
PR_URL_ARG=""
BRANCH_ARG=""
PR_ONLY=0
PROJECT_ARG=""
DRY=0
FORCE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --pr) PR_ONLY=1; PR_URL_ARG="${2-}"; shift 2 ;;
    --pr=*) PR_ONLY=1; PR_URL_ARG=${1#--pr=}; shift ;;
    --project) PROJECT_ARG="${2-}"; shift 2 ;;
    --project=*) PROJECT_ARG=${1#--project=}; shift ;;
    --pr-url) PR_URL_ARG="${2-}"; shift 2 ;;
    --pr-url=*) PR_URL_ARG=${1#--pr-url=}; shift ;;
    --branch) BRANCH_ARG="${2-}"; shift 2 ;;
    --branch=*) BRANCH_ARG=${1#--branch=}; shift ;;
    --dry-run) DRY=1; shift ;;
    --force) FORCE=1; shift ;;
    -*) printf 'error: unknown flag %s\nhelp: bin/agents/eindri-review-spawn.sh <task-id> [--pr-url <url>] [--branch <b>] [--dry-run] [--force] | --pr <url>\n' "$1" >&2; exit 2 ;;
    *)
      if [ -z "$ID" ]; then ID=$1
      else printf 'error: too many positional arguments\nhelp: one task-id\n' >&2; exit 2
      fi
      shift ;;
  esac
done
[ -n "$ID" ] || [ "$PR_ONLY" = 1 ] || { printf 'error: task-id is required\nhelp: bin/agents/eindri-review-spawn.sh <task-id> | --pr <url>\n' >&2; exit 2; }
if [ -n "$ID" ]; then
  case "$ID" in
    */*|.*|*' '*) printf 'error: invalid task-id %s\n' "$ID" >&2; exit 2 ;;
  esac
fi

REVIEW_ID="${ID:+$ID-review}"
AUTO="${YMIR_AUTO_REVIEW:-on}"
HARNESS="${YMIR_REVIEW_HARNESS:-}"
# The judge's model is RESOLVED for THIS seat (plan 206 §11, the Allfather: "all users and
# computers have different models and capabilities"). The code names no model id: the fleet
# declares its choice in the private home, the seat's own catalogue says whether it can serve
# it, and a seat that cannot says so instead of quietly borrowing a neighbour's promise.
#
# THE HOME'S ROW WINS (RULES/08, 2026-11-21). The fleet names the judge in config/agents.yaml
# (forseti: harness claude, model opus). The heart's review-watch drop-in pinned YMIR_FORSETI_MODEL
# to a pi model, and the resolver honours an environment override above the home, so a
# harness-wide pin overruled the operator's declared judge. So: the judge's harness is read from
# the home row first, and when the home names the judge's model the YMIR_FORSETI_MODEL pin yields.
# A Claude judge is resolved against Claude's allow-list, not pi's catalogue, and comes back as the
# name the Claude CLI takes (claude-opus-5-5) — the harness is handed on, so model and harness
# agree (#865). YMIR_REVIEW_MODEL stays the one deliberate per-run override.
if [ -z "$HARNESS" ] && [ -x "$SCRIPT_DIR/../fleet/agents-config.sh" ]; then
  HARNESS="$("$SCRIPT_DIR/../fleet/agents-config.sh" get forseti harness 2>/dev/null | head -n1 || true)"
fi
HARNESS="${HARNESS:-pi}"
_cfg_model=""
[ -x "$SCRIPT_DIR/../fleet/agents-config.sh" ] && \
  _cfg_model="$("$SCRIPT_DIR/../fleet/agents-config.sh" get forseti model 2>/dev/null | head -n1 || true)"
_unpin=(env)
[ -n "$_cfg_model" ] && _unpin=(env -u YMIR_FORSETI_MODEL)
_model_err="$(mktemp)"
MODEL="${YMIR_REVIEW_MODEL:-$("${_unpin[@]}" bash "$ROOT/bin/model/agent-model.sh" forseti --plain --harness "$HARNESS" 2>"$_model_err" || true)}"
unset _cfg_model _unpin
[ -n "$MODEL" ] || { printf 'error: no model resolved for the judge on this seat\n' >&2; grep 'REFUSED' "$_model_err" >&2; rm -f "$_model_err"; printf 'help: bin/model/agent-model.sh forseti --explain (a model this seat cannot serve is a refusal, not a fallback)\n' >&2; exit 1; }
rm -f "$_model_err"
EFFORT="${YMIR_REVIEW_EFFORT:-high}"
BACKEND="${YMIR_REVIEW_BACKEND:-herdr}"
# YMIR_REVIEW_DRY=1 behaves exactly as --dry-run: resolve and print the spawn
# line without seating the judge. It lets the whole spine be proved (the acclaim
# hook included) on a fixture, with no live seat.
[ "${YMIR_REVIEW_DRY:-0}" = 1 ] && DRY=1

skip() {  # <why>
  printf 'review-spawn[1]{task,review,state,why}:\n  "%s","%s","skipped","%s"\n' "$ID" "$REVIEW_ID" "$1"
  exit 0
}

# Give the claim back. DEFINED HERE, ABOVE ITS FIRST USE: it used to sit 70 lines
# below, and bash cannot call a function it has not yet reached — so the "no PR"
# path printed `release_claim: command not found` and the acclaim read the spawn as
# FAILED, when it had only decided not to seat a judge (measured 2026-11-08).
release_claim() { [ "${DRY:-0}" -eq 0 ] && rmdir "${REVIEW_SPAWNED:-}" 2>/dev/null || true; }

# ── the guards: off, a review of a review, an already-reviewed task ──────────
[ "$AUTO" = off ] && skip "YMIR_AUTO_REVIEW=off (the loud override)"
case "$ID" in
  *-review) skip "the id is already a review — a scout opens no PR" ;;
esac

# Find the task record. A well-formed spawn writes it in the machine state, but
# a per-seat BROKK_STATE_OVERRIDE can move it, so both are consulted.
meta_value() {  # <file> <key>
  grep "^$2=" "$1" 2>/dev/null | tail -1 | cut -d= -f2- || true
}
TASK_STATE=""
TASK_META=""
for _cand in "${BROKK_STATE_OVERRIDE:-}" "$YMIR_STATE_DIR" "${BROKK_HOME:-$ROOT}/state" "$ROOT/state"; do
  [ -n "$_cand" ] || continue
  if [ -f "$_cand/$ID.meta" ]; then TASK_STATE="$_cand"; TASK_META="$_cand/$ID.meta"; break; fi
done
unset _cand
NO_TASK=0
if [ -z "$TASK_META" ]; then
  if [ "$PR_ONLY" = 1 ]; then
    NO_TASK=1
  else
    skip "no task record at <state>/$ID.meta — nothing to review"
  fi
fi
TASK_KIND="$(meta_value "$TASK_META" kind)"; TASK_KIND=${TASK_KIND:-ship}
[ "$NO_TASK" = 0 ] && [ "$TASK_KIND" = scout ] && skip "kind=scout — a scout opens no PR"
PROJECT="$(meta_value "$TASK_META" project)"
[ -n "$PROJECT" ] || PROJECT="${BROKK_ROOT_OVERRIDE:-$ROOT}"
WORKTREE="$(meta_value "$TASK_META" worktree)"

# The shared state the spine writes and Brokk reads: the RESOLVED task root
# (the hoard, symlinked beside the code), never an inference from the existence
# of $PROJECT/state — that inference seated a SECOND judge under an override
# (Forseti's verdict on #235, reproduced live). The resolved root wins; the
# project's state dir is only a fallback when no task state resolved at all.
SHARED_ROOT="$PROJECT"
[ -n "$TASK_STATE" ] && SHARED_STATE="$TASK_STATE" || SHARED_STATE="$SHARED_ROOT/state"
# The errand's records are the HOME's (Rule 04): no fallback to `<checkout>/data` — a data
# folder inside a code checkout is the split this door must not create, so a home that does
# not resolve is named aloud rather than answered with the wrong directory.
if ! house_data SHARED_DATA; then
  printf 'error: no data shelf resolved for the review — the house is unreadable, not split by us\n  home:  %s\nhelp: set YMIR_HOME to the operator home (bin/vault/hoard-lib.sh names it), or fix the machine record at ${YMIR_CONFIG_DIR:-~/.config/ymir}/home\n' \
    "${YMIR_HOME_ROOT_RESOLVED:-none}" >&2
  release_claim
  exit 1
fi

# ── the PR: from the flag, else the task's own terminal status line ──────────
PR_URL="$PR_URL_ARG"
if [ -z "$PR_URL" ]; then
  # The done line may sit in the task's own record state or the caller's seat
  # state (a per-seat BROKK_STATE_OVERRIDE); the spine reads wherever it landed.
  for _sf in "${BROKK_STATE_OVERRIDE:-}/$ID.status" "$TASK_STATE/$ID.status" "$SHARED_STATE/$ID.status"; do
    [ -n "$_sf" ] || continue
    [ -f "$_sf" ] || continue
    _url=$(grep -oE 'https://github\.com/[^[:space:]]+/pull/[0-9]+' "$_sf" 2>/dev/null | tail -1 || true)
    if [ -n "$_url" ]; then PR_URL="$_url"; break; fi
  done
  unset _sf _url
fi
[ -n "$PR_URL" ] || { release_claim; skip "no PR in state/$ID.status (a local-only tip never reviews)"; }
PR_NUMBER="$(printf '%s' "$PR_URL" | grep -oE '/pull/[0-9]+' | grep -oE '[0-9]+' | tail -1 || true)"
[ -n "$PR_NUMBER" ] || PR_NUMBER="?"

# pr_key <owner/repo> <n> → pr-<owner>--<repo>-<n>, lowercased: the one name a PR has in the
# review shelf, shared by the spine, the keeper (bin/forge/review-watch.sh) and the interim loop
pr_key() {
  local slug; slug="$(printf '%s' "$1" | tr 'A-Z' 'a-z')"
  printf 'pr-%s--%s-%s' "${slug%%/*}" "${slug#*/}" "$2"
}

# ── PR-ONLY mode: the PR is the record, and its HEAD is the marker (plan 206 §10.3a) ──
HEAD_SHA=""
if [ "$PR_ONLY" = 1 ]; then
  command -v gh >/dev/null 2>&1 || {
    printf 'error: gh is required to judge a PR by url, and it is not on PATH here\nhelp: a judge with no GitHub door cannot read the head it must review\n' >&2
    exit 1
  }
  SLUG="$(printf '%s' "$PR_URL" | sed -nE 's#^https://github\.com/([^/]+/[^/]+)/pull/([0-9]+).*#\1#p')"
  [ -n "$SLUG" ] || { printf 'error: cannot read owner/repo from the PR url %s\n' "$PR_URL" >&2; exit 1; }
  _pr_json="$(gh pr view "$PR_NUMBER" -R "$SLUG" --json headRefOid,headRefName,mergeable 2>/dev/null || true)"
  HEAD_SHA="$(printf '%s' "$_pr_json" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("headRefOid",""))' 2>/dev/null || true)"
  [ -n "$HEAD_SHA" ] || {
    printf 'error: could not read PR #%s from %s — no head sha, so no marker and no honest judgement\nhelp: check the GitHub identity on this seat (gh auth status)\n' "$PR_NUMBER" "$SLUG" >&2
    exit 1
  }
  if [ -z "$BRANCH_ARG" ]; then
    BRANCH_ARG="$(printf '%s' "$_pr_json" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("headRefName",""))' 2>/dev/null || true)"
  fi
  unset _pr_json
  if [ "$NO_TASK" = 1 ]; then
    # the id carries the REPOSITORY: PR #7 of two repositories is two reviews, never one
    # (review of #863, 2026-11-21) — pr-<owner>--<repo>-<n> (an owner never holds "--")
    ID="$(pr_key "$SLUG" "$PR_NUMBER")"
    REVIEW_ID="$ID-review"
    PROJECT="${PROJECT_ARG:-$ROOT}"
    SHARED_ROOT="$PROJECT"
    SHARED_STATE="$YMIR_STATE_DIR"
    house_data SHARED_DATA || { printf 'error: no data shelf resolved for the review of %s\nhelp: set YMIR_HOME to the operator home\n' "$PR_URL" >&2; exit 1; }
    TASK_BRIEF=""
    TASK_STATUS=""
  fi
fi

# ── the branch: the flag, else the task worktree's own branch ────────────────
BRANCH="$BRANCH_ARG"
if [ -z "$BRANCH" ] && [ -n "$WORKTREE" ] && [ -d "$WORKTREE" ]; then
  _b=$(git -C "$WORKTREE" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
  case "$_b" in HEAD|"") ;; *) BRANCH="$_b" ;; esac
  unset _b
fi
[ -n "$BRANCH" ] || BRANCH="eindri/$ID"

# ── the head the judge is seated for (task mode reads it now; PR-only mode already has it) ──
_slug="$(printf '%s' "$PR_URL" | sed -nE 's#^https://github\.com/([^/]+/[^/]+)/pull/[0-9]+.*#\1#p')"
if [ -z "$HEAD_SHA" ] && [ -n "$_slug" ] && [ "$PR_NUMBER" != "?" ] && command -v gh >/dev/null 2>&1; then
  HEAD_SHA="$(gh pr view "$PR_NUMBER" -R "$_slug" --json headRefOid -q .headRefOid 2>/dev/null | tr -d '[:space:]' || true)"
fi

# ── the anti-double marker ───────────────────────────────────────────────────
REVIEWED_DIR="$SHARED_STATE/.reviewed"
# ONE HEAD, ONE JUDGE (review of #863, 2026-11-21). Every road into this spine — an errand's terminal
# done (task mode), the keeper and the interim loop (PR-only mode) — shares ONE per-head marker,
# .reviewed/pr-<owner>--<repo>-<n>.<head>, and one claim beside it. Before, the errand road marked only
# the task id, so the keeper seated a second judge for a head the errand's judge already had.
# The per-head marker lives in the HOME's state (YMIR_STATE_DIR — where the keeper's hoard_state_dir
# reads), never a task's own state dir: two roads that keep two shelves never see each other's mark.
HEAD_MARKER=""
HEAD_DIR="${YMIR_STATE_DIR:-$SHARED_STATE}/.reviewed"
if [ -n "$_slug" ] && [ "$PR_NUMBER" != "?" ] && [ -n "$HEAD_SHA" ]; then
  HEAD_MARKER="$HEAD_DIR/$(pr_key "$_slug" "$PR_NUMBER").$HEAD_SHA"
  mkdir -p "$HEAD_DIR" 2>/dev/null || true
fi
if [ "$NO_TASK" = 1 ]; then
  # Plan 206 §10.3 — a PR is judged once per HEAD. A moved head is new work and earns a
  # fresh judgement; the same head twice in a minute earns nothing (the flood brake).
  MARKER="${HEAD_MARKER:-$REVIEWED_DIR/$ID.unknown}"
  REVIEW_SPAWNED="$MARKER.spawning"
else
  MARKER="$REVIEWED_DIR/$ID"
  REVIEW_SPAWNED="${HEAD_MARKER:+$HEAD_MARKER.spawning}"
  REVIEW_SPAWNED="${REVIEW_SPAWNED:-$REVIEWED_DIR/$ID.spawning}"
fi
if [ -f "$MARKER" ] && [ "$FORCE" -ne 1 ]; then
  skip "already reviewed ($MARKER exists) — a re-done never re-reviews"
fi
if [ -n "$HEAD_MARKER" ] && [ -f "$HEAD_MARKER" ] && [ "$FORCE" -ne 1 ]; then
  skip "this head already has a judge ($HEAD_MARKER) — one head, one judge"
fi
if [ -f "$MARKER" ] && [ "$FORCE" -eq 1 ]; then
  printf 'review-spawn: --force overrides the anti-double marker (%s) — a deliberate re-review\n' "$MARKER"
fi
# Claim the task atomically so two racing dones cannot seat two judges. A stale
# claim (older than 30 min: a spawn that died badly) is reclaimed.
if [ -d "$REVIEW_SPAWNED" ]; then
  _age=$(( $(date +%s) - $(stat -c %Y "$REVIEW_SPAWNED" 2>/dev/null || echo 0) ))
  if [ "$_age" -lt 1800 ]; then
    skip "a review spawn is already in flight for this task"
  fi
  rm -rf "$REVIEW_SPAWNED" 2>/dev/null || true
fi
mkdir -p "$REVIEWED_DIR" 2>/dev/null || true
if [ "$DRY" -eq 0 ] && ! mkdir "$REVIEW_SPAWNED" 2>/dev/null; then
  skip "a review spawn is already in flight for this task"
fi


# ── the judge's seat: the harness was resolved with the model, above ────────

# ── fill the fierce brief for THIS task ──────────────────────────────────────
BRIEF="$SHARED_DATA/$REVIEW_ID/brief.md"
REPORT_PATH="$SHARED_STATE/eindri-reports/$REVIEW_ID.md"
STATUS_PATH="$SHARED_STATE/$REVIEW_ID.status"
INBOX_DIR="$SHARED_STATE/$REVIEW_ID.inbox"
WAKE_QUEUE="$SHARED_STATE/.wake-queue"
TASK_BRIEF="$SHARED_DATA/$ID/brief.md"
TASK_STATUS="$SHARED_STATE/$ID.status"

if [ ! -r "$TEMPLATE" ]; then
  release_claim
  printf 'error: review brief template not found at %s\nhelp: it lives in the tree at .agents/assets/templates/review-brief.template.md\n' "$TEMPLATE" >&2
  exit 1
fi
brief=$(cat "$TEMPLATE")
brief=${brief//'{{TASK_ID}}'/$ID}
brief=${brief//'{{REVIEW_ID}}'/$REVIEW_ID}
brief=${brief//'{{PR_URL}}'/$PR_URL}
brief=${brief//'{{PR_NUMBER}}'/$PR_NUMBER}
brief=${brief//'{{BRANCH}}'/$BRANCH}
brief=${brief//'{{HEAD_SHA}}'/${HEAD_SHA:-the current head of the PR}}
brief=${brief//'{{PROJECT}}'/$PROJECT}
brief=${brief//'{{STATE_DIR}}'/$SHARED_STATE}
brief=${brief//'{{DATA_DIR}}'/$SHARED_DATA}
brief=${brief//'{{REPORT_PATH}}'/$REPORT_PATH}
brief=${brief//'{{STATUS_PATH}}'/$STATUS_PATH}
brief=${brief//'{{INBOX_DIR}}'/$INBOX_DIR}
brief=${brief//'{{WAKE_QUEUE}}'/$WAKE_QUEUE}
brief=${brief//'{{TASK_BRIEF}}'/$TASK_BRIEF}
brief=${brief//'{{TASK_STATUS}}'/$TASK_STATUS}
mkdir -p "$SHARED_DATA/$REVIEW_ID" || true
printf '%s\n' "$brief" >"$BRIEF" || {
  release_claim
  printf 'error: could not write the review brief at %s\n' "$BRIEF" >&2
  exit 1
}

# ── the claim: one judge per PR head, across the fleet (plan 343.12) ─────────
# A judge and a coder may hold the same PR in different roles, but two JUDGES on one head may not:
# a seat that finds another seat's judge already on this head stands down and says whose it is
# (the collisions of 2026-11-21: #858 and #868 merged while this seat's judges were still reviewing).
# A moved head is a new judgement and may be claimed. Dry-run only asks; a ledger that cannot be
# used never stops a judgement (stated, Rule 25).
CLAIM_SH="$SCRIPT_DIR/claim.sh"; PR_CLAIM_KEY=""
if [ -x "$CLAIM_SH" ] && [ "${YMIR_CLAIMS:-on}" != off ] && [ -n "$_slug" ] && [ "$PR_NUMBER" != "?" ]; then
  PR_CLAIM_KEY="pr:$_slug#$PR_NUMBER"
  if [ "$DRY" -eq 1 ]; then
    _co="$("$CLAIM_SH" check "$PR_CLAIM_KEY" --role judge 2>&1)" || { release_claim; skip "another seat already holds this PR as judge — ${_co#claim: }"; }
  else
    _co="$("$CLAIM_SH" take "$PR_CLAIM_KEY" --role judge --errand "$REVIEW_ID" ${HEAD_SHA:+--head "$HEAD_SHA"} 2>&1)"; _crc=$?
    if [ "$_crc" = 1 ]; then release_claim; skip "another seat already holds this PR as judge — ${_co#claim: }"; fi
    [ "$_crc" = 0 ] || printf 'review-spawn: the claims ledger could not be used (claim.sh exit %s) — judging without a claim\n' "$_crc" >&2
    [ "$_crc" = 0 ] || PR_CLAIM_KEY=""
  fi
  unset _co _crc
fi

# ── the spawn line (printed whole on --dry-run) ──────────────────────────────
spawn=( "$SCRIPT_DIR/einherjar-spawn.sh" "$REVIEW_ID" "$PROJECT" --scout
        --backend "$BACKEND" --harness "$HARNESS" --model "$MODEL" --effort "$EFFORT" --role forseti )
# `--role forseti` seats the judge with ITS permission profile (RULES/08, 2026-11-21): the one
# merge door (bin/forge/judge-merge.sh, bin/agents/pr-seal.sh seal) is open and raw `gh pr merge`
# stays denied. Without it the judge carried the worker profile and was refused at the merge.
spawn_line="$SCRIPT_DIR/einherjar-spawn.sh $REVIEW_ID $(printf '%q' "$PROJECT") --scout --backend $BACKEND --harness $HARNESS --model $MODEL --effort $EFFORT --role forseti"

if [ "$DRY" -eq 1 ]; then
  release_claim
  printf 'review-spawn[1]{task,review,pr,branch,head,marker,brief,report,spawn}:\n'
  printf '  "%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' \
    "$ID" "$REVIEW_ID" "$PR_URL" "$BRANCH" "${HEAD_SHA:-none}" "$MARKER" "$BRIEF" "$REPORT_PATH" "$spawn_line"
  exit 0
fi

# ── the judged record: which repo, PR and HEAD this judge was seated for ─────
# bin/forge/judge-merge.sh reads it when the verdict lands: an APPROVE merges THIS head and no
# other (RULES/08, 2026-11-21). It is written BEFORE the judge starts, so a report older than it
# belongs to an earlier head and is never read as this head's approval.
JUDGED="$REVIEWED_DIR/$REVIEW_ID.judged"
{
  printf 'review=%s\n' "$REVIEW_ID"
  printf 'task=%s\n' "$ID"
  printf 'repo=%s\n' "$_slug"
  printf 'pr=%s\n' "$PR_NUMBER"
  printf 'head=%s\n' "$HEAD_SHA"
  printf 'url=%s\n' "$PR_URL"
  printf 'at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} >"$JUDGED" 2>/dev/null || true
unset _slug

# ── seat the judge through the einherjar road ────────────────────────────────
# The review's records belong to the SHARED state, never the caller's seat: the
# spawn is a Brokk-level act, and its meta/status must be read by supervision.
if env -u BROKK_STATE_OVERRIDE -u BROKK_DATA_OVERRIDE \
       BROKK_HOME="$SHARED_ROOT" BROKK_STATE_OVERRIDE="$SHARED_STATE" BROKK_DATA_OVERRIDE="$SHARED_DATA" \
       "${spawn[@]}"; then
  {
    printf 'review=%s\n' "$REVIEW_ID"
    printf 'pr=%s\n' "$PR_URL"
    printf 'branch=%s\n' "$BRANCH"
    printf 'report=%s\n' "$REPORT_PATH"
    printf 'at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } >"$MARKER" 2>/dev/null || true
  [ -n "$HEAD_MARKER" ] && [ "$HEAD_MARKER" != "$MARKER" ] && cp "$MARKER" "$HEAD_MARKER" 2>/dev/null
  release_claim
  printf 'review-spawn[1]{task,review,pr,branch,brief,report,state}:\n'
  printf '  "%s","%s","%s","%s","%s","%s","seated"\n' \
    "$ID" "$REVIEW_ID" "$PR_URL" "$BRANCH" "$BRIEF" "$REPORT_PATH"
else
  _rc=$?
  release_claim
  rm -f "$JUDGED" 2>/dev/null || true
  [ -n "$PR_CLAIM_KEY" ] && "$CLAIM_SH" release "$PR_CLAIM_KEY" --role judge >/dev/null 2>&1
  printf 'error: the review spawn failed (exit %s) for %s — NO judge is seated; retry with bin/agents/eindri-review-spawn.sh %s --force\n' \
    "$_rc" "$ID" "$ID" >&2
  exit 1
fi
