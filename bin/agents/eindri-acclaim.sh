#!/usr/bin/env bash
# eindri-acclaim.sh — action half of the Eindri→Brokk wake bridge.
#
# Runs when the when-adapter fires on a stable `true`, AND as the WORKER'S OWN
# terminal act (the push path, plan 58 Phase 3): the smith calls it before it
# exits, it writes its report and appends the durable wake to state/.wake-queue.
# The arm only notifies; a finished errand wakes Brokk with no poller, no sweep,
# and no arm alive.
#
# It files the report durably (state/eindri-reports/<agent>.md), marks the
# delivery on the ONE shared ledger (state/eindri-delivered/<agent>.<kind> — see
# bin/agents/eindri-wake-lib.sh, so the failsafe sweep never re-fires the same news),
# appends the wake, and sounds the desktop note. Idempotent via the ledger.
#
# The worker's terminal act may be one command — the status append and the shelf
# are done here so neither can be skipped:
#   bin/agents/eindri-acclaim.sh <agent> --terminal done --line "<one-line report>"
#
# Usage: bin/agents/eindri-acclaim.sh <agent> [<worktree-root>] [--terminal done|failed|needs-decision] [--line "<text>"]
#          [--evidence "<command>"]...
#
# THE VEIL (plan 350 B1): evidence or no "done". A done act carries one --evidence per claim: the
# command that proves it. The act RUNS each one in the errand's repo and files the command, its exit
# and its output under `## Evidence`. No evidence, an evidence command that fails, or a pull request
# whose checks are red at its head, and the terminal state is `unproven`, never `done` — the review
# is not seated and the arm holder is told. Checks still running are named as pending (the Veil's
# sweep reads them again). VEIL_EVIDENCE=off is the loud override; VEIL_EVIDENCE_TIMEOUT (900 s)
# bounds each command. Every report carries a Veil id (bin/agents/veil.sh) the holder answers with
# RECEIVED. Exit 5 when the act ended unproven.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)}"

# The roots that live OUTSIDE the code tree: this machine's records and the
# runtime state belong to the home the operator chose at installation, never in
# the tree — a packaged install replaces its tree on upgrade (Rule 04).
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _yr="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _yc in "$_yr/hoard-lib.sh" "$_yr/../vault/hoard-lib.sh" "$_yr/../../vault/hoard-lib.sh"; do
    [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yr _yc
fi
hoard_state_dir YMIR_STATE_DIR
hoard_data_dir YMIR_DATA_DIR
STATE="${BROKK_STATE_OVERRIDE:-$YMIR_STATE_DIR}"

. "$SCRIPT_DIR/eindri-wake-lib.sh"
EINDRI_STATE="$STATE"

AGENT=""
WORKTREE=""
TERMINAL=""
LINE=""
EVIDENCE=()
while [ $# -gt 0 ]; do
  case "$1" in
    --evidence) [ -n "${2-}" ] || { printf 'error: --evidence needs a command\n' >&2; exit 2; }; EVIDENCE+=("$2"); shift 2 ;;
    --evidence=*) EVIDENCE+=("${1#--evidence=}"); shift ;;
    --terminal) TERMINAL="${2-}"; shift 2 ;;
    --terminal=*) TERMINAL=${1#--terminal=}; shift ;;
    --line) LINE="${2-}"; shift 2 ;;
    --line=*) LINE=${1#--line=}; shift ;;
    -h|--help)
      printf 'usage: bin/agents/eindri-acclaim.sh <agent> [<worktree-root>] [--terminal done|failed|needs-decision] [--line "<text>"]\n'
      exit 0 ;;
    -v|-V|--version) printf '1.0.0\n'; exit 0 ;;
    -*) printf 'error: unknown flag %s\nhelp: bin/agents/eindri-acclaim.sh <agent> [<worktree-root>] [--terminal done|failed|needs-decision] [--line "<text>"]\n' "$1" >&2; exit 2 ;;
    *)
      if [ -z "$AGENT" ]; then AGENT=$1
      elif [ -z "$WORKTREE" ]; then WORKTREE=$1
      else printf 'error: too many positional arguments\nhelp: bin/agents/eindri-acclaim.sh <agent> [<worktree-root>]\n' >&2; exit 2
      fi
      shift ;;
  esac
done
[ -n "$AGENT" ] || { printf 'usage: bin/agents/eindri-acclaim.sh <agent> [<worktree-root>] [--terminal done|failed|needs-decision] [--line "<text>"]\n' >&2; exit 2; }
case "$TERMINAL" in
  ''|done|failed|needs-decision) ;;
  *) printf 'error: --terminal must be done|failed|needs-decision (got %s)\n' "$TERMINAL" >&2; exit 2 ;;
esac

mkdir -p "$STATE/eindri-reports" "$STATE/eindri-questions" "$STATE/eindri-done"

# write_record <shelf> — append the `## Record` block, measured from the errand's own repo.
# The repo is the worktree argument, else the meta's worktree, else the directory the act runs in.
find_repo() {  # prints the errand's repo, or nothing
  local wt r
  for wt in "$WORKTREE" "$(sed -n 's/^worktree=//p' "$STATE/$AGENT.meta" "$ROOT/state/$AGENT.meta" 2>/dev/null | head -1)" "$PWD"; do
    [ -n "$wt" ] && [ -d "$wt" ] || continue
    r="$(git -C "$wt" rev-parse --show-toplevel 2>/dev/null)" && [ -n "$r" ] && { printf '%s' "$r"; return 0; }
  done
  return 0
}

# weigh_evidence <shelf> — run each --evidence in the repo, file it, and set UNPROVEN_WHY when the
# claim is not borne out. A PR named in the line is read at its head (`gh pr checks`).
UNPROVEN_WHY=""
weigh_evidence() {
  local shelf=$1 repo cmd out rc n=0 pr limit="${VEIL_EVIDENCE_TIMEOUT:-900}"
  repo="$(find_repo)"; [ -n "$repo" ] || repo="$PWD"
  printf '\n## Evidence\n' >>"$shelf"
  if [ "${#EVIDENCE[@]}" -eq 0 ]; then
    printf '\nnone given — a done act names the command that proves each claim (--evidence "<command>")\n' >>"$shelf"
    UNPROVEN_WHY="no evidence given"
  fi
  for cmd in "${EVIDENCE[@]}"; do
    n=$((n + 1))
    out="$(cd "$repo" && timeout "$limit" bash -c "$cmd" </dev/null 2>&1)"; rc=$?
    printf '\n%d. `%s` — exit %s\n\n```\n%s\n```\n' "$n" "$cmd" "$rc" "$(printf '%s\n' "$out" | tail -n 30)" >>"$shelf"
    [ "$rc" = 0 ] || UNPROVEN_WHY="${UNPROVEN_WHY:+$UNPROVEN_WHY; }evidence $n exited $rc ($cmd)"
  done
  pr="$(printf '%s' "$LINE" | grep -oE 'https://github\.com/[^[:space:]]+/pull/[0-9]+' | head -1)"
  [ "${VEIL_PR_CHECKS:-on}" = off ] && pr=""
  if [ -n "$pr" ]; then
    if command -v gh >/dev/null 2>&1; then
      out="$(timeout 60 gh pr checks "$pr" 2>&1)"; rc=$?
      case "$rc" in
        0) printf '\nPR checks at the head of %s: green\n' "$pr" >>"$shelf" ;;
        8) printf '\nPR checks at the head of %s: pending — the Veil sweep reads them again\n' "$pr" >>"$shelf" ;;
        *) if printf '%s\n' "$out" | grep -qP '\tfail\t'; then
             printf '\nPR checks at the head of %s: RED (exit %s)\n\n```\n%s\n```\n' "$pr" "$rc" "$(printf '%s\n' "$out" | grep -P '\tfail\t' | head -10)" >>"$shelf"
             UNPROVEN_WHY="${UNPROVEN_WHY:+$UNPROVEN_WHY; }PR checks are red at the head"
           else
             printf '\nPR checks at the head of %s: unread (%s)\n' "$pr" "$(printf '%s' "$out" | grep -m1 . | cut -c1-120)" >>"$shelf"
           fi ;;
      esac
    else
      printf '\nPR checks: unread (no gh on this machine)\n' >>"$shelf"
    fi
  fi
  return 0
}

write_record() {
  local shelf=$1 repo branch head base ahead files st where tip
  repo="$(find_repo)"
  if [ -z "$repo" ]; then
    printf '\n## Record\n\ncommit: none — nothing committed (no git repository found for %s)\n' "$AGENT" >>"$shelf"
    return 0
  fi
  branch="$(git -C "$repo" branch --show-current 2>/dev/null)"
  base="$(git -C "$repo" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)"
  [ -n "$base" ] || for b in origin/main origin/master; do
    git -C "$repo" rev-parse -q --verify "refs/remotes/$b" >/dev/null 2>&1 && { base=$b; break; }
  done
  ahead="$(git -C "$repo" rev-list --count "${base:-HEAD}..HEAD" 2>/dev/null || echo 0)"
  st="$(git -C "$repo" status --short 2>/dev/null)"
  {
    printf '\n## Record\n\n'
    if [ "${ahead:-0}" -gt 0 ] 2>/dev/null; then
      head="$(git -C "$repo" log --oneline -1 2>/dev/null)"
      where="local only"
      if git -C "$repo" rev-parse -q --verify "refs/remotes/origin/$branch" >/dev/null 2>&1 \
        && [ "$(git -C "$repo" rev-list --count "origin/$branch..HEAD" 2>/dev/null)" = 0 ]; then
        where="pushed"
      else
        tip="$(timeout 15 git -C "$repo" ls-remote origin "refs/parked/$AGENT" 2>/dev/null | awk '{print $1}')"
        [ -n "$tip" ] && [ "$tip" = "$(git -C "$repo" rev-parse HEAD 2>/dev/null)" ] && where="parked"
      fi
      printf 'commit: %s\n' "$head"
    else
      where="local only"
      printf 'commit: none — nothing committed (HEAD is %s)\n' "${base:-the base}"
    fi
    printf 'branch: %s\nrepo: %s\nmachine: %s\nwhere: %s\n' "${branch:-detached}" "$repo" "$(hostname -s 2>/dev/null || uname -n)" "$where"
    printf 'files (git diff --name-only %s...HEAD):\n' "${base:-HEAD}"
    files="$(git -C "$repo" diff --name-only "${base:-HEAD}...HEAD" 2>/dev/null)"
    if [ -n "$files" ]; then printf '%s\n' "$files" | sed 's/^/    /'; else printf '    (none)\n'; fi
    printf 'git status --short:\n'
    if [ -n "$st" ]; then printf '%s\n' "$st" | sed 's/^/    /'; else printf '    (clean)\n'; fi
  } >>"$shelf"
}

# 1. The worker's own terminal act, when it passes its line: append the status
#    line and file the shelf as ONE act, so neither half is ever deferred. Done
#    before delivery so the same shelf the failsafe sweeps is what gets queued.
if [ -n "$TERMINAL" ] && [ -n "$LINE" ]; then
  # A DONE LINE MUST CARRY THE PR (measured 2026-11-09). The review spine reads the
  # PR url out of this very line; a done line without one seats no judge, and the
  # fault is invisible — the errand simply never reviews. So a shipping errand whose
  # done line names no pull request is refused HERE, where the worker still exists to
  # fix it, rather than discovered later by a sweep.
  if [ "$TERMINAL" = "done" ] && ! printf '%s' "$LINE" | grep -qE 'https://github\.com/[^[:space:]]+/pull/[0-9]+'; then
    # The spawn records its meta in <repo>/state; the home's state may be a different dir — read both.
    mode="$(sed -n 's/^mode=//p' "$STATE/$AGENT.meta" "$ROOT/state/$AGENT.meta" 2>/dev/null | head -1)"
    case "${mode:-}" in
      local-only|batch|scout|review|recon|'') ;;   # no PR owed: a local tip never reviews; a batch ships through the gatherer's one PR; a scout (dispatch writes mode=scout, spawn omits it) and review/recon errands deliver a report
      *)
        printf 'refused: a %s errand cannot acclaim done without its pull request\n' "$mode" >&2
        printf 'help: put the url in the line — --line "done: opened PR https://github.com/<owner>/<repo>/pull/<n> — …"\n' >&2
        printf 'note: a done line without a PR seats no judge (the spine is PR-only).\n' >&2
        exit 3 ;;
    esac
  fi
  # the maker ward (RULES/53): the line carries the PR into the review spine and the PR record, so it may not
  # name a model, a maker or an agent harness. Refused HERE, where the worker still exists to reword it.
  if [ -r "$ROOT/bin/gates/guards/maker-guard.sh" ]; then
    _lf="$(mktemp)"; printf '%s\n' "$LINE" >"$_lf"
    bash "$ROOT/bin/gates/guards/maker-guard.sh" text "the $TERMINAL line" "$_lf" || { rm -f "$_lf"; exit 3; }
    rm -f "$_lf"
  fi
  # THE VEIL (plan 350 B1): weigh the evidence before a word of `done` is written anywhere.
  _evf=""
  if [ "$TERMINAL" = "done" ]; then
    _evf="$(mktemp)"
    if [ "${VEIL_EVIDENCE:-on}" = off ]; then
      printf '\n## Evidence\n\nVEIL_EVIDENCE=off — the evidence gate was overridden, loudly\n' >"$_evf"
      printf 'WARNING: VEIL_EVIDENCE=off — %s acclaims done without its evidence weighed\n' "$AGENT" >&2
    else
      weigh_evidence "$_evf"
      if [ -n "$UNPROVEN_WHY" ]; then
        TERMINAL=unproven
        printf 'unproven: %s — %s\nhelp: run the act again with one --evidence "<command>" per claim, each one green\n' "$AGENT" "$UNPROVEN_WHY" >&2
        LINE="$LINE [unproven: $UNPROVEN_WHY]"
      fi
    fi
  fi
  status_file="$STATE/$AGENT.status"
  last="$(tail -n1 "$status_file" 2>/dev/null || true)"
  [ "$last" = "$TERMINAL: $LINE" ] || printf '%s: %s\n' "$TERMINAL" "$LINE" >>"$status_file"
  case "$TERMINAL" in
    needs-decision) shelf="$STATE/eindri-questions/$AGENT.md" ;;
    *)              shelf="$STATE/eindri-reports/$AGENT.md" ;;
  esac
  # a done that follows an unproven replaces the unproven shelf: the proof is the news now
  if [ "$TERMINAL" = done ] && grep -q '\[unproven: ' "$shelf" 2>/dev/null; then : >"$shelf"; fi
  [ -s "$shelf" ] || printf '%s\n' "$(sol_stamped "$LINE")" >"$shelf" 2>/dev/null
  # A shelf the act claims to have filed must be THERE: say so loudly, never claim it silently.
  [ -s "$shelf" ] || { printf 'error: the report did not land — %s is missing or empty (state dir %s)\nhelp: check that the state dir is writable; the wake was NOT queued\n' "$shelf" "$STATE" >&2; exit 1; }
  # THE RECORD (plan 339.2). A done report counts only with its record: the commit, the files,
  # git status, and where the commit is. The act writes it from git itself, so no worker can
  # forget it and no worker can word it; the arm (src/ymir_runtime/watch.py, verify_record)
  # checks the claim on the machine it names, and a claim git does not bear out is false-done.
  if [ -n "$_evf" ]; then
    grep -q '^## Evidence' "$shelf" 2>/dev/null || cat "$_evf" >>"$shelf"
    rm -f "$_evf"
  fi
  if { [ "$TERMINAL" = "done" ] || [ "$TERMINAL" = "unproven" ]; } && ! grep -q '^## Record' "$shelf" 2>/dev/null; then
    write_record "$shelf"
  fi
fi

# 1b. The well remembers what the errand did (the Allfather, 2026-11-12: "when they are DONE
#     they need to remember what they have done to the well"). The brief asks the worker for
#     one episode before this act (bin/records/mimir.sh observe … --task <id>). Here a `done`
#     or `failed` that left none since its launch is said LOUDLY, and a minimal episode is
#     written from --line (or the status line) so no finished errand is missing from the
#     well. A failed errand is remembered with its why. The well is a record, not a gate: a
#     well that does not answer never holds back the wake.
MIMIR="${YMIR_ACCLAIM_WELL:-$SCRIPT_DIR/../records/mimir.sh}"   # a test points this away from the real well
well_remember_finish() {  # <terminal> <line> <writer>
  local term=$1 text=$2 writer=$3 since n
  [ -x "$MIMIR" ] && [ -n "$text" ] || return 0
  since="$(sed -n 's/^launch_iso=//p' "$STATE/$AGENT.meta" 2>/dev/null | head -1 | cut -c1-10)"
  n="$(timeout 15 "$MIMIR" recall "$AGENT" --task "$AGENT" ${since:+--since "$since"} --k 1 2>/dev/null \
        | sed -n '1s/^recall\[\([0-9]*\)\].*/\1/p')"
  if [ "${n:-0}" -ge 1 ] 2>/dev/null; then
    printf 'well: the errand %s left its own episode — remembered\n' "$AGENT" >&2
    return 0
  fi
  printf 'WARNING: the errand %s finished (%s) and left NO episode in the well — writing a minimal one from its line. A worker remembers what it did itself: bin/records/mimir.sh observe "…" --source eindri --task %s --tags eindri,%s\n' \
    "$AGENT" "$term" "$AGENT" "$term" >&2
  # through the queueing door (plan 350 E): a well that does not answer now is retried, never dropped
  if [ -x "$SCRIPT_DIR/../records/well-write.sh" ] && [ -z "${YMIR_ACCLAIM_WELL:-}" ]; then
    timeout 45 bash "$SCRIPT_DIR/../records/well-write.sh" observe "eindri $AGENT $term: $text (written by $writer: the worker left no episode of its own)" \
      --source "$writer" --task "$AGENT" --tags "eindri,$term,unremembered" --shape behaviour --key "acclaim:$AGENT:$term" >/dev/null 2>&1 \
      || printf 'warning: the well did not take the minimal episode for %s — the wake stands\n' "$AGENT" >&2
  else
    timeout 15 "$MIMIR" observe "eindri $AGENT $term: $text (written by $writer: the worker left no episode of its own)" \
      --source "$writer" --task "$AGENT" --tags "eindri,$term,unremembered" --shape behaviour --force >/dev/null 2>&1 \
      || printf 'warning: the well did not take the minimal episode for %s — the wake stands\n' "$AGENT" >&2
  fi
}
case "$TERMINAL" in
  done|failed|unproven)
    _wl="$LINE"; [ -n "$_wl" ] || _wl="$(tail -n1 "$STATE/$AGENT.status" 2>/dev/null | sed 's/^[a-z-]*: //')"
    well_remember_finish "$TERMINAL" "$_wl" eindri-acclaim
    unset _wl ;;
esac

# 2. Kind and detail from the shelves (a question outranks a report — the smith
#    is blocked and needs an answer, not a review).
kind="reported"
detail=""
corrected=0
if [ -f "$STATE/eindri-questions/$AGENT.md" ]; then
  kind="QUESTION"
  detail="QUESTION at state/eindri-questions/$AGENT.md — answer with bin/agents/eindri-send.sh $AGENT \"…\""
elif [ -f "$STATE/eindri-reports/$AGENT.md" ]; then
  # The shelf may be the SWEEP's snapshot rather than the worker's word: a liveness
  # pass files "# <id> — finished without a terminal word" when it finds a quiet
  # pane. That was a GUESS, and a guess must not outlive the evidence that corrects
  # it — measured 2026-11-06, when a live errand was judged dead at 3m59s, the sweep
  # filed its snapshot, the once-only `report` mark was spent on it, and the worker's
  # own terminal word could neither heal the shelf nor raise a wake. So: a shelf
  # carrying the sweep's header and nothing better is replaced by the terminal word,
  # and the correction travels as its own kind so the spent `report` cannot mute it.
  if grep -q ' — finished without a terminal word' "$STATE/eindri-reports/$AGENT.md" 2>/dev/null; then
    last="$(tail -n1 "$STATE/$AGENT.status" 2>/dev/null || true)"
    case "$last" in
      done:*|failed:*|unproven:*)
        # The sweep's guess is replaced, but the Evidence and the Record this act just wrote are KEPT
        # (measured 2026-11-22: the heal rewrote the shelf to the bare status line, and a done that had
        # filed five green evidence commands read as a claim with no proof).
        _kept="$(awk '/^## (Evidence|Record)$/{keep=1} keep' "$STATE/eindri-reports/$AGENT.md" 2>/dev/null)"
        { printf '%s\n' "$last"; [ -n "$_kept" ] && printf '\n%s\n' "$_kept"; } >"$STATE/eindri-reports/$AGENT.md.tmp" \
          && mv "$STATE/eindri-reports/$AGENT.md.tmp" "$STATE/eindri-reports/$AGENT.md"
        unset _kept
        detail="report healed from the terminal status line, replacing the sweep's snapshot and keeping its evidence ($STATE/eindri-reports/$AGENT.md)"
        corrected=1 ;;
      *)
        detail="report filed at $STATE/eindri-reports/$AGENT.md (the sweep's snapshot; no terminal word yet)" ;;
    esac
  else
    detail="report filed at $STATE/eindri-reports/$AGENT.md"
  fi
  [ "$TERMINAL" = unproven ] && { kind="UNPROVEN"; detail="UNPROVEN ($UNPROVEN_WHY) — $detail"; }
else
  # No shelf. A terminal status line IS a report (the worker wrote one shelf and
  # died before the other): heal the report shelf from it, so the two roads read
  # one ground and nothing is stranded.
  last="$(tail -n1 "$STATE/$AGENT.status" 2>/dev/null || true)"
  case "$last" in
    done:*|failed:*)
      printf '%s\n' "$last" >"$STATE/eindri-reports/$AGENT.md"
      detail="report healed from the terminal status line ($STATE/eindri-reports/$AGENT.md)" ;;
    needs-decision:*)
      kind="QUESTION"
      printf '%s\n' "$last" >"$STATE/eindri-questions/$AGENT.md"
      detail="question healed from the terminal status line (state/eindri-questions/$AGENT.md)" ;;
    *)
      if [ -n "$WORKTREE" ] && [ -f "$WORKTREE/REPORT.md" ]; then
        cp "$WORKTREE/REPORT.md" "$STATE/eindri-reports/$AGENT.md" 2>/dev/null || true
        detail="report filed from $WORKTREE/REPORT.md ($STATE/eindri-reports/$AGENT.md)"
      else
        detail="left working (herdr state flipped; read the pane: herdr agent read $AGENT)"
      fi ;;
  esac
fi

# 3. Deliver exactly once, on the shared ledger. The poller and the sweep are
#    the same road: whoever arrives first writes the wake, the other stands down.
wake_kind=report
[ "$kind" = "QUESTION" ] && wake_kind=question
[ "$kind" = "UNPROVEN" ] && wake_kind=unproven
[ "$corrected" = 1 ] && wake_kind=corrected
# THE ARM CONTRACT (plan 350 B): the report carries a Veil id the holder answers with RECEIVED. The wake
# below IS the delivery (--queued), so the id is recorded without a second queue line; the Veil's sweep
# resends it into the holder's pane when no receipt comes, and a red follows past ten minutes.
VEIL_ID=""
if [ -x "$SCRIPT_DIR/veil.sh" ] && [ "${VEIL_ARM:-on}" != off ]; then
  _vk=report; [ "$kind" = UNPROVEN ] && _vk=finding
  _reply=""; _pane="$(sed -n 's/^window=//p' "$STATE/$AGENT.meta" 2>/dev/null | head -1)"; [ -n "$_pane" ] && _reply="herdr:$_pane"
  VEIL_ID="$(BROKK_STATE_OVERRIDE="$STATE" "$SCRIPT_DIR/veil.sh" send --queued --from "agent $AGENT" --kind "$_vk" ${_reply:+--reply-to "$_reply"} "$kind: ${LINE:-$detail}" 2>/dev/null \
    | sed -n '2s/^  "\([^"]*\)".*/\1/p')"
  [ -n "$VEIL_ID" ] && detail="$detail [veil $VEIL_ID — answer: bin/agents/veil.sh received $VEIL_ID]"
  unset _vk _reply _pane
fi
if eindri_is_delivered "$AGENT" "$wake_kind"; then
  detail="$detail (already delivered — no duplicate wake)"
else
  if [ "$kind" = "QUESTION" ]; then
    eindri_queue_wake "eindri $AGENT QUESTION: $STATE/eindri-questions/$AGENT.md — answer with bin/agents/eindri-send.sh $AGENT \"…\"" ask
  elif [ "$kind" = "UNPROVEN" ]; then
    eindri_queue_wake "eindri $AGENT UNPROVEN: $detail" report
  elif [ "$corrected" = 1 ]; then
    eindri_queue_wake "eindri $AGENT CORRECTED: the sweep's snapshot was a guess — $detail" report
  else
    eindri_queue_wake "eindri $AGENT reported: $detail" report
  fi
  # The queue line is the wake: if it did not land, the errand is not reported — fail, do not mark delivered.
  if ! grep -q -F -- "eindri $AGENT " "$STATE/.wake-queue" 2>/dev/null; then
    printf 'error: the wake did not land — no line for %s in %s\nhelp: check that the state dir is writable\n' "$AGENT" "$STATE/.wake-queue" >&2
    exit 1
  fi
  if [ "$wake_kind" = unproven ]; then
    # an unproven report is not the errand's end: only its own kind is marked, so the proof that
    # follows is delivered as news (eindri-done/ would mute every later kind)
    mkdir -p "$STATE/eindri-delivered" 2>/dev/null
    printf '%s %s delivered unproven\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$AGENT" >"$STATE/eindri-delivered/$AGENT.unproven"
  else
    eindri_mark_delivered "$AGENT" "$wake_kind"
  fi
  if [ "${YMIR_NO_INJECT:-0}" != 1 ] && [ -x "$SCRIPT_DIR/../../systems/snotra/services/tts-lease/ymir-say.sh" ]; then
    if [ "$kind" = "QUESTION" ]; then
      "$SCRIPT_DIR/../../systems/snotra/services/tts-lease/ymir-say.sh" alarm "Eindri $AGENT asks — answer it" >/dev/null 2>&1 || true
    else
      "$SCRIPT_DIR/../../systems/snotra/services/tts-lease/ymir-say.sh" note "Eindri $AGENT reported" >/dev/null 2>&1 || true
    fi
  fi
fi
# 3b. The record-as-wake cursor (plan 257 H3). The arm raises one wake per terminal
#     status line newer than state/<id>.woke; the loud road has just delivered (or
#     found delivered) this one, so it writes the same cursor and the two roads never
#     wake twice for one line.
if [ -f "$STATE/$AGENT.status" ]; then
  _woke="$(date -r "$STATE/$AGENT.status" +%s.%N 2>/dev/null || stat -f %Fm "$STATE/$AGENT.status" 2>/dev/null || true)"
  [ -n "$_woke" ] && printf '%s\n' "$_woke" >"$STATE/$AGENT.woke" 2>/dev/null || true
  unset _woke
fi
# 3c. The last errand of a batch prompts the GATHER (plan 293 part 4). A batch errand never pushes
#     and never opens a PR — the helm gathers the batch into one push and one PR (RULES/08). Until
#     this, nothing told the helm the batch was ready: twenty-two clean batch branches sat on origin
#     and four were merged. The door decides whether this was the last one and queues ONE line that
#     names the finished ids and the exact gather command; it is silent for a lone errand.
if grep -qx 'mode=batch' "$STATE/$AGENT.meta" "$ROOT/state/$AGENT.meta" 2>/dev/null; then
  if [ -x "$SCRIPT_DIR/../forge/gather-notice.sh" ]; then
    _gn="$("$SCRIPT_DIR/../forge/gather-notice.sh" "$AGENT" 2>&1)" && [ -n "$_gn" ] && printf '%s\n' "$_gn"
  else
    printf 'gather-notice: bin/forge/gather-notice.sh is absent — a finished batch is not prompted\n' >&2
  fi
fi
# 4. The review spine (FORSETI the Judge). The delivery gate's other half: a
#    ship errand that reached `done` with a PR wakes its own reviewer. One per
#    task (the .reviewed marker); YMIR_AUTO_REVIEW=off is the loud override; a
#    failed spawn is a loud wake, never silence.
if [ "$TERMINAL" = done ] && [ -x "$SCRIPT_DIR/eindri-review-spawn.sh" ]; then
  if _rv_out="$("$SCRIPT_DIR/eindri-review-spawn.sh" "$AGENT" 2>&1)"; then
    printf '%s\n' "$_rv_out"
  else
    _rv_rc=$?
    printf '%s\n' "$_rv_out" >&2
    if [ ! -f "$STATE/.reviewed/$AGENT.failed" ]; then
      mkdir -p "$STATE/.reviewed" 2>/dev/null || true
      printf '%s\n' "$_rv_out" >"$STATE/.reviewed/$AGENT.failed" 2>/dev/null || true
      eindri_queue_wake "eindri $AGENT review spawn FAILED (rc=$_rv_rc): $(printf '%s' "$_rv_out" | grep -m1 . || true)" report
      if [ -x "$SCRIPT_DIR/../../systems/snotra/services/tts-lease/ymir-say.sh" ]; then
        "$SCRIPT_DIR/../../systems/snotra/services/tts-lease/ymir-say.sh" alarm "Forseti's review spawn failed for $AGENT" >/dev/null 2>&1 || true
      fi
    fi
  fi
fi
# 5. The judge's verdict is the seal (RULES/08, 2026-11-21). A REVIEW errand that reached `done`
#    hands its verdict to the one merge road: APPROVE merges at once (every gate re-checked at that
#    instant), NEEDS-REWORK goes back to the author's seat as one PR comment. review-watch sweeps the
#    same road every pass, so a judge that never ran this act is still carried out.
case "$AGENT" in
  *-review)
    if [ "$TERMINAL" = done ] && [ -x "$SCRIPT_DIR/../forge/judge-merge.sh" ]; then
      timeout 300 "$SCRIPT_DIR/../forge/judge-merge.sh" act "$AGENT" 2>&1 || \
        printf 'judge-merge: the verdict of %s could not be carried out now — review-watch sweeps it again\n' "$AGENT" >&2
    fi ;;
esac
# ── THE LAST LINK: SPEAK IT INTO THE ARM HOLDER'S PANE ─────────────────────────────────────────────
# The Allfather, 2026-11-08 and again 2026-11-09: *"why arent they injecting into your session chat? we
# have built that and its not getting used. they are writing handoff in files now instead"* … *"no
# handoff or sutch without also talking direckly in to the panes."* So the terminal act does all four:
# the status line, the report shelf, the durable wake, AND a turn in the chat of the session holding
# the arm. A message that only reaches a file has not reached anybody.
#
# It is best-effort-but-loud: if the pane cannot be reached, this says WHICH link broke and why, and
# the record above still stands. Silence here would be the very fault the door exists to fix.
_notify="$SCRIPT_DIR/eindri-notify.sh"
_injected=no
if [ -x "$_notify" ]; then
  if _nout="$("$_notify" --from "$AGENT" -- "$TERMINAL: $detail" 2>&1)"; then
    _injected=yes
  else
    printf '%s\n' "$_nout" >&2
    _injected="failed — $(printf '%s' "$_nout" | grep -m1 . || echo 'no reason given')"
  fi
else
  _injected="failed — no eindri-notify.sh beside this door"
fi

printf 'eindri-acclaim[5]{agent,kind,detail,pane,veil}:
  "%s","%s","%s","%s","%s"\n' "$AGENT" "$kind" "$detail" "$_injected" "${VEIL_ID:--}"
[ "$TERMINAL" = unproven ] && exit 5
exit 0
