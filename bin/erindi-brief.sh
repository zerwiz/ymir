#!/usr/bin/env bash
# erindi-brief.sh - scaffold an Eindri worker brief at data/<task-id>/brief.md.
#
# Erindi ("the errand") is the written errand Brokk hands an Eindri. The brief
# carries the Setup / Rules / Definition-of-done contract, a fixed machine-
# readable "Delivery contract: mode=<mode>" line, the worktree-isolation
# assertion, the status protocol, and the steering-inbox receive/ack section.
# Ported from the upstream distro brief scaffold for plan 29
# (docs/plans/29-brokk-distro-runtime.md).
#
# Usage:
#   erindi-brief.sh <task-id> <repo-name> --mode <no-mistakes|direct-PR|local-only>
#   erindi-brief.sh <task-id> <repo-name> --scout
#   erindi-brief.sh <task-id> --relaunch
#
# --scout writes the scout contract: the deliverable is a report at
# data/<task-id>/report.md (no branch, no push, no PR) and the worktree is
# scratch.
# --relaunch regenerates the brief from the task's recorded state/<id>.meta so
# a replacement Eindri receives the SAME delivery contract as the original; it
# refuses to invent a mode and it will not run without an existing meta record.
# The fixed "Delivery contract: mode=<mode>" line is read by
# bin/einherjar-spawn.sh, which refuses to launch a ship task whose explicit
# --mode disagrees, so an adjusted brief and the recorded task cannot drift.
# --mode is refused on --scout and --relaunch: a scout delivers a report and a
# relaunch re-derives the mode from the task record, not from a flag.
# Refuses to overwrite an existing brief unless --relaunch is given.
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
esac

ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
BROKK_HOME="${BROKK_HOME:-${BROKK_ROOT_OVERRIDE:-$ROOT}}"
DATA="${BROKK_DATA_OVERRIDE:-$BROKK_HOME/data}"
STATE="${BROKK_STATE_OVERRIDE:-$BROKK_HOME/state}"
PAUSED_VERB="${BROKK_PAUSED_VERB:-paused}"

KIND=ship
SCOUT=0
RELAUNCH=0
MODE=
MODE_SET=0
POS=()
want_value=
for a in "$@"; do
  if [ -n "$want_value" ]; then
    case "$a" in
      --*) echo "error: --$want_value requires a value" >&2; exit 1 ;;
    esac
    case "$want_value" in
      mode) MODE=$a; MODE_SET=1 ;;
      *) echo "error: internal parser state for --$want_value" >&2; exit 1 ;;
    esac
    want_value=
    continue
  fi
  case "$a" in
    --scout) SCOUT=1 ;;
    --relaunch) RELAUNCH=1 ;;
    --mode) want_value=mode ;;
    --mode=*) MODE=${a#--mode=}; MODE_SET=1 ;;
    --yolo|--yolo=*) echo "error: --yolo is not a brief input; pass it to bin/einherjar-spawn.sh, which records the task's merge posture" >&2; exit 1 ;;
    *) POS+=("$a") ;;
  esac
done
[ -z "$want_value" ] || { echo "error: --$want_value requires a value" >&2; exit 1; }

if [ "$SCOUT" -eq 1 ] && [ "$RELAUNCH" -eq 1 ]; then
  echo "error: --scout and --relaunch are mutually exclusive" >&2
  exit 1
fi

ID=${POS[0]:-}
[ -n "$ID" ] || { echo "error: task-id is required" >&2; exit 2; }
case "$ID" in
  */*|.*|*' '*) echo "error: invalid task-id '$ID' (no slashes, no leading dot, no spaces)" >&2; exit 2 ;;
esac

meta_value() {  # <meta> <key>
  grep "^$2=" "$1" 2>/dev/null | tail -1 | cut -d= -f2- || true
}

if [ "$RELAUNCH" -eq 1 ]; then
  META="$STATE/$ID.meta"
  [ -f "$META" ] || { echo "error: --relaunch requires an existing task record at $META" >&2; exit 1; }
  RECORDED_KIND=$(meta_value "$META" kind); RECORDED_KIND=${RECORDED_KIND:-ship}
  REPO=$(meta_value "$META" project)
  [ -n "$REPO" ] || REPO=$(meta_value "$META" worktree)
  [ -n "$REPO" ] || { echo "error: task record $META records no project; cannot regenerate the brief" >&2; exit 1; }
  if [ "$MODE_SET" -eq 1 ]; then
    echo "error: --mode is refused with --relaunch; the delivery mode is re-derived from $META" >&2
    exit 1
  fi
  if [ "$RECORDED_KIND" = ship ]; then
    MODE=$(meta_value "$META" mode)
    case "$MODE" in
      no-mistakes|direct-PR|local-only) ;;
      *) echo "error: task record $META records no valid mode; refusing to regenerate the brief" >&2; exit 1 ;;
    esac
  elif [ "$RECORDED_KIND" != scout ]; then
    echo "error: task record $META records kind=$RECORDED_KIND, which has no brief scaffold" >&2
    exit 1
  fi
  KIND=$RECORDED_KIND
else
  if [ "$SCOUT" -eq 1 ]; then
    KIND=scout
  else
    [ "$MODE_SET" -eq 1 ] || {
      echo "error: ship briefs require --mode <no-mistakes|direct-PR|local-only>; resolve it at intake and pass it here" >&2
      exit 1
    }
    case "$MODE" in
      no-mistakes|direct-PR|local-only) ;;
      *) echo "error: --mode must be one of no-mistakes, direct-PR, local-only (got '$MODE')" >&2; exit 1 ;;
    esac
  fi
  if [ "$MODE_SET" -eq 1 ] && [ "$SCOUT" -eq 1 ]; then
    echo "error: --mode applies only to ship briefs; a scout delivers a report" >&2
    exit 1
  fi
  REPO=${POS[1]:-}
  [ -n "$REPO" ] || { echo "error: <repo-name> is required for a fresh brief" >&2; exit 2; }
fi

BRIEF="$DATA/$ID/brief.md"
if [ -e "$BRIEF" ] && [ "$RELAUNCH" -ne 1 ]; then
  echo "error: $BRIEF already exists (use --relaunch to regenerate from the task record)" >&2
  exit 1
fi
mkdir -p "$DATA/$ID"

shell_quote() {
  printf "'"
  printf '%s' "$1" | sed "s/'/'\\\\''/g"
  printf "'"
}

STATUS_FILE=$(shell_quote "$STATE/$ID.status")
INBOX_DIR=$(shell_quote "$STATE/$ID.inbox")
REPORT_FILE="$DATA/$ID/report.md"

INBOX_SECTION=$(cat <<EOF
# Brokk instruction inbox
Brokk steers you through durable message files in $INBOX_DIR.
When a terminal message says an instruction is waiting there - and at any natural checkpoint when you are unsure - list $INBOX_DIR/*.msg, read and act on each message in numeric order, then acknowledge each handled message by moving it: \`mv $INBOX_DIR/NNN.msg $INBOX_DIR/handled/\`.
The move IS the acknowledgement: without it Brokk rings again and eventually treats you as stuck. An empty or absent inbox needs no action.
EOF
)

STATUS_SECTION=$(cat <<EOF
Report status by appending one line:
   \`echo "{state}: {one short line}" >> $STATUS_FILE\`
   States: working, needs-decision, blocked, $PAUSED_VERB, done, failed.
   Each append wakes Brokk, so report sparingly: only phase changes a supervisor
   would act on and the needs-decision/blocked/$PAUSED_VERB/done/failed states.
   Use \`$PAUSED_VERB: {why}\` - distinct from \`blocked:\` - ONLY when you are deliberately
   idling on a known external wait you expect to clear on its own (an upstream release,
   a rate-limit reset); use \`blocked:\` when you are stuck and need Brokk to act.
   A mid-task \`working:\` line is nonterminal: do not end the turn after it; continue
   until a defined \`done:\` gate under Definition of done.
   A decision or blocker stays open until a \`resolved\` line carrying its exact key
   lands; a later \`done:\` or \`working:\` line never closes it.
EOF
)

if [ "$KIND" = scout ]; then
  cat > "$BRIEF" <<EOF
You are an Eindri: an autonomous worker agent managed by Brokk. Work on your own; do not wait for the Allfather.

# Task
{TASK}

# Delivery contract
Delivery contract: mode=scout

# Setup
You are in a disposable git worktree of $REPO at .yggdrasil/$ID on the host (under Utgard it appears at /sandbox/workspace), at a detached HEAD on a clean default branch.
This is a SCOUT task: the deliverable is a written report, not a PR.
The worktree is your laboratory - install, run, edit, and make scratch commits freely; all of it is discarded at teardown.
The report is the only thing that survives, so anything worth keeping must be in it.

**Verify isolation before anything else.** Run \`pwd -P\` and \`git rev-parse --show-toplevel\`; both must resolve to this disposable task worktree (host path .yggdrasil/$ID, or /sandbox/workspace under Utgard), never the primary checkout Brokk operates from.
If the top-level path is the primary checkout or not the worktree you were launched in, STOP - do not branch or commit here - append \`blocked: launched in primary checkout, not an isolated worktree\` to the status file and stop.

# Rules
1. Never push to any remote and never open a PR.
2. Stay inside this worktree; the only files you may write outside it are the report and the status file below.
3. $STATUS_SECTION
4. If you hit the same obstacle twice, append \`blocked: {why}\` and stop; Brokk will help.
5. If a decision belongs to the Allfather (product choices, destructive actions), append \`needs-decision: {summary of options}\` and stop. Brokk will reply with the decision.

$INBOX_SECTION

# Definition of done
Write your findings to \`$REPORT_FILE\`.
The report must stand alone: what you did, what you found, the evidence (commands run, output, file:line references), and what you recommend.
When the report is complete, append \`done: {one-line conclusion}\` to the status file and stop.
EOF
  if [ "$RELAUNCH" -eq 1 ]; then
    printf 'scaffolded: %s (scout, relaunch; replace {TASK})\n' "$BRIEF"
  else
    printf 'scaffolded: %s (scout; replace {TASK})\n' "$BRIEF"
  fi
  exit 0
fi

case "$MODE" in
  direct-PR)
    RULE1='Never push to the default branch (push only your `eindri/'"$ID"'` branch). Never merge a PR; the Glitnir human gate owns the merge.'
    DOD_BODY='Commit your work on `eindri/'"$ID"'`. Push the branch and open a PR with `gh`. Report the PR URL: append `done: opened PR <url>` to the status file and stop. Brokk routes the PR to the Glitnir human gate; you never merge.'
    ;;
  local-only)
    RULE1="Never push to any remote and never open a PR. Work only on your \`eindri/$ID\` branch; Brokk merges into local \`main\` after the Allfather approves."
    DOD_BODY="Commit your work on \`eindri/$ID\`. Append \`done: ready in branch eindri/$ID\` to the status file and stop. Brokk merges into local \`main\` after the Allfather approves."
    ;;
  *)  # no-mistakes
    RULE1='Never push to the default branch. Never merge a PR; the Glitnir human gate owns the merge.'
    DOD_BODY='Run the `no-mistakes` pipeline over your branch and open the PR it produces. Append `done: <PR url> (pipeline <status>)` to the status file and stop. Brokk routes the PR to the Glitnir human gate; you never merge.'
    ;;
esac

if [ "$MODE" = no-mistakes ]; then
  SETUP_STEP2='
2. Run `no-mistakes doctor`; if it reports the repo is not initialized here, run `no-mistakes init`.'
else
  SETUP_STEP2=""
fi

cat > "$BRIEF" <<EOF
You are an Eindri: an autonomous worker agent managed by Brokk. Work on your own; do not wait for the Allfather.

# Task
{TASK}

# Delivery contract
Delivery contract: mode=$MODE

# Setup
You are in a disposable git worktree of $REPO at .yggdrasil/$ID on the host (under Utgard it appears at /sandbox/workspace), at a detached HEAD on a clean default branch.

**Verify isolation before anything else.** Run \`pwd -P\` and \`git rev-parse --show-toplevel\`; both must resolve to this disposable task worktree (host path .yggdrasil/$ID, or /sandbox/workspace under Utgard), never the primary checkout Brokk operates from.
The path check is authoritative. If the top-level path is the primary checkout or not the worktree you were launched in, STOP - do not branch or commit here - append \`blocked: launched in primary checkout, not an isolated worktree\` to the status file and stop.

1. First action: create your branch: \`git checkout -b eindri/$ID\`$SETUP_STEP2

# Rules
1. $RULE1
2. Stay inside this worktree; modify nothing outside it.
3. $STATUS_SECTION
4. If you hit the same obstacle twice, append \`blocked: {why}\` and stop; Brokk will help.
5. If a decision belongs to the Allfather (product choices, destructive actions), append \`needs-decision: {summary of options}\` and stop. Brokk will reply with the decision.

$INBOX_SECTION

# Definition of done
$DOD_BODY
EOF
if [ "$RELAUNCH" -eq 1 ]; then
  printf 'scaffolded: %s (ship, mode=%s, relaunch; replace {TASK})\n' "$BRIEF" "$MODE"
else
  printf 'scaffolded: %s (ship, mode=%s; replace {TASK})\n' "$BRIEF" "$MODE"
fi
