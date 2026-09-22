#!/usr/bin/env bash
# eindri-dispatch.sh — the errand loop: ONE command per errand (plan 42
# Part III-b, the automation law).
#
# Implements the whole handoff path:
#   new    -> waves registry -> brief (bin/erindi-brief.sh) -> state/<id>.meta
#             -> backlog row (flock) -> arm the task (bin/eindri-arm.sh) -> spawn
#   close  -> the arm/coordinator's close hook: result file -> backlog state
#             -> Forseti review verdict -> rune
#   review -> record the acceptance verdict (the Forseti door)
#   status -> the fleet ledger, one command
#
# Usage:
#   eindri-dispatch.sh new <id> [<repo>] [--scout|--mode <mode>]
#                      [--title T] [--scope S] [--done D] [--wave N]
#                      [--harness H] [--backend tmux|herdr] [--dry-run]
#   eindri-dispatch.sh close <id> [--verdict pass|return|fail] [--note "…"]
#   eindri-dispatch.sh review <id> pass|return [--note "…"]
#   eindri-dispatch.sh status [--wave N]
#   eindri-dispatch.sh --version
#
# Env: BROKK_HOME / BROKK_DATA_OVERRIDE / BROKK_STATE_OVERRIDE (like the
# siblings); BROKK_WAVES_OVERRIDE for the waves registry.
#
# Exit: 0 ok, 1 error, 2 usage.
set -u

VERSION="1.0.0"
# shellcheck disable=SC1091
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ymir-platform.sh" 2>/dev/null || true
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
BROKK_HOME="${BROKK_HOME:-${BROKK_ROOT_OVERRIDE:-$ROOT}}"
DATA="${BROKK_DATA_OVERRIDE:-$BROKK_HOME/data}"
STATE="${BROKK_STATE_OVERRIDE:-$BROKK_HOME/state}"
WAVES="${BROKK_WAVES_OVERRIDE:-$DATA/waves.yaml}"
BACKLOG="$DATA/backlog.md"
LOCK="$DATA/backlog.lock"

say() { printf '%s\n' "$*"; }

meta_write() { # <id> <key=value>...
  local id=$1; shift
  mkdir -p "$STATE"
  : > "$STATE/$id.meta.tmp"
  for kv in "$@"; do printf '%s\n' "$kv" >> "$STATE/$id.meta.tmp"; done
  mv "$STATE/$id.meta.tmp" "$STATE/$id.meta"
}

meta_get() { # <id> <key> -> value
  grep "^$2=" "$STATE/$1.meta" 2>/dev/null | tail -1 | cut -d= -f2- || true
}

backlog_append() { # id wave kind title status
  mkdir -p "$DATA"
  if [ ! -f "$BACKLOG" ]; then
    printf '%s\n' \
      '# The errand ledger (plan 42 — the fleet backlog, one writer)' \
      '' \
      '| id | wave | kind | status | title |' \
      '|---|---|---|---|---|' > "$BACKLOG"
  fi
  exec 9>"$LOCK"
  flock 9
  printf '| %s | %s | %s | %s | %s |\n' "$1" "$2" "$3" "$4" "${5//|/\\|}" >> "$BACKLOG"
  flock -u 9
  exec 9>&-
}

backlog_set_status() { # id newstatus [note]
  [ -f "$BACKLOG" ] || return 1
  local tmp; tmp="$BACKLOG.tmp"
  exec 9>"$LOCK"
  flock 9
  awk -v id="$1" -v st="$2" -v n="${3-}" '
    BEGIN { FS="|"; OFS="|" }
    {
      f = $2; gsub(/^ +| +$/, "", f)
      if (f == id) {
        $4 = " " st
        if (n != "") $5 = " " n
      }
    }
    { print }
  ' "$BACKLOG" > "$tmp" && mv "$tmp" "$BACKLOG"
  flock -u 9
  exec 9>&-
}

wave_gate() { # wave -> gate name or empty
  [ -f "$WAVES" ] || return 0
  awk -v w="$1" '
    /^[a-zA-Z]:/ { key=$1; gsub(":","",key) }
    $0 ~ "^  gate:" && key==w { sub("^  gate: *",""); print }' "$WAVES"
}

spawn_args() { # id repo scout-ish...
  say "spawn: $(realpath "$SCRIPT_DIR/einherjar-spawn.sh")"
}

cmd_new() {
  local id repo KIND=ship MODE= SCOUT=0 WAVE= TITLE= SCOPE= DONE= HARNESS= BACKEND= SEAT= NO_SEAT= DRY=0
  local POS=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --scout) SCOUT=1 ;;
      --mode) MODE="${2-}"; shift ;;
      --mode=*) MODE=${1#--mode=} ;;
      --title) TITLE="${2-}"; shift ;;
      --title=*) TITLE=${1#--title=} ;;
      --scope) SCOPE="${2-}"; shift ;;
      --done) DONE="${2-}"; shift ;;
      --wave) WAVE="${2-}"; shift ;;
      --harness) HARNESS="${2-}"; shift ;;
      --backend) BACKEND="${2-}"; shift ;;
      --seat) SEAT="${2-}"; shift ;;
      --seat=*) SEAT=${1#--seat=} ;;
      --no-seat) NO_SEAT=1 ;;
      --dry-run) DRY=1 ;;
      *) POS+=("$1") ;;
    esac
    shift
  done
  id="${POS[0]-}"
  repo="${POS[1]-}"
  [ -n "$id" ] || { echo "error: task-id required (new <id> [repo])" >&2; exit 2; }
  case "$id" in */*|.*|*' '*) echo "error: invalid task-id '$id'" >&2; exit 2 ;; esac

  # THE HANDOFF MINIMUM (the law): refuse to dispatch a naked smith
  [ -n "$TITLE" ] || { echo "error: --title (mission) is required — an errand is never dispatched without it" >&2; exit 2; }
  [ -n "$DONE" ] || { echo "error: --done (definition of done) is required — the arm and the verdict depend on it" >&2; exit 2; }
  [ -n "$SEAT" ] || [ -n "${NO_SEAT:-}" ] || {
    echo "error: --seat <alias> is required (or --no-seat for a pure code errand) — the smith must know its machine" >&2; exit 2; }
  if [ -n "${NO_SEAT:-}" ]; then SEAT=standalone; fi

  if [ "$SCOUT" = 1 ]; then KIND=scout; else
    [ -n "$MODE" ] || MODE=local-only
    case "$MODE" in direct-PR|local-only|no-mistakes) ;; *) echo "error: bad --mode $MODE" >&2; exit 2 ;; esac
  fi
  [ -n "$WAVE" ] || WAVE="A"

  # the wave gate: a wave whose gate row is not closed refuses to dispatch
  local gate force=0
  gate=$(wave_gate "$WAVE")
  if [ -n "$gate" ] && [ -z "$(git -C "$ROOT" log --oneline -1 --grep="$gate" 2>/dev/null)" ]; then
    echo "error: wave $WAVE waits on gate '$gate' (not found in git log)" >&2
    exit 1
  fi

  # 1) the brief (the errand book): Refuses to overwrite an existing brief.
  local brief_rc=0
  if [ -x "$SCRIPT_DIR/erindi-brief.sh" ]; then
    if [ "$KIND" = scout ]; then
      "$SCRIPT_DIR/erindi-brief.sh" "$id" "${repo:-$ROOT}" --scout >/dev/null 2>&1 || brief_rc=$?
    else
      "$SCRIPT_DIR/erindi-brief.sh" "$id" "${repo:-$ROOT}" --mode "$MODE" >/dev/null 2>&1 || brief_rc=$?
    fi
  fi
  [ "$brief_rc" = 0 ] || echo "warn: erindi-brief exit $brief_rc (brief exists? continuing)" >&2
  # fill the brief with THIS errand's mission (the book's title/scope/done)
  local brief="$DATA/$id/brief.md"
  if [ -f "$brief" ]; then
    local tx="$TITLE"
    [ -n "$SCOPE" ] && tx="$tx\n\nScope: $SCOPE"
    [ -n "$DONE" ] && tx="$tx\n\nDefinition of done: $DONE"
    [ -n "$tx" ] && sed -i "s/{TASK}/$(printf '%s' "$tx" | sed 's/[&\\/]/\\&/g')/" "$brief" 2>/dev/null || true
  fi

  # 1b) the errand's OWN PLANNING DOCUMENT (the Allfather's ask: Brokk hands
  # every Eindri its own plan): data/<id>/plan.md — wave + gate, the machine
  # card of the target seat, the standing laws, the channels, the citations
  local plan="$DATA/$id/plan.md"
  mkdir -p "$DATA/$id"
  {
    printf '# Plan — errand %s (wave %s)  \n\n' "$id" "$WAVE"
    printf 'kind: %s · mode: %s · created: %s\n\n' "$KIND" "${MODE:-scout}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '**Mission:** %s\n\n' "${TITLE:-$id}"
    [ -n "$SCOPE" ] && printf '**Scope:** %s\n\n' "$SCOPE"
    [ -n "$DONE" ] && printf '**Definition of done:** %s\n\n' "$DONE"
    local gate; gate=$(wave_gate "$WAVE")
    [ -n "$gate" ] && printf '**Wave gate (must be closed):** %s\n\n' "$gate"
    printf '**Seat:** %s\n\n' "$SEAT"
    printf '**Environment:** harness=%s · model=%s · effort=%s · isolation=%s\n\n' "${HARNESS:-auto}" "${MODEL:-default}" "${EFFORT:-default}" "${ISOLATION:-auto}"
    # the target seat's card, when seated over the private home
    local seat="${SEAT-}"
    if [ -n "$seat" ] && [ -f "$BROKK_HOME/hodd/data/machines.md" ]; then
      printf '**The seat you work on (card):**\n\n'
      grep -iE "^\| *\`?${seat}\`? *|\|.*${seat}.*\|" "$BROKK_HOME/hodd/data/machines.md" 2>/dev/null | head -3
      printf '\nFull registry: `hodd/data/machines.md`\n\n'
    fi
    printf '**The standing laws (the errand book):**\n\n'
    printf '1. No sudo — a root need is reported, never taken.\n'
    printf '2. Named-file staging only — never `git add -A` (the 2026-09-17 scar).\n'
    printf '3. Append-only surfaces never rewrite (runes · rules · fixes · daily).\n'
    printf '4. Private data stays in the home; keys by path, never inline.\n'
    printf '5. The circle and the ward for the wire (aliases · ~/.ssh keys).\n'
    printf '6. The shared vault serializes — one writer per wave; a busy home repo means wait.\n'
    printf '7. Close with the report contract: result, rune, Allfather tail, well lesson.\n'
    printf '8. The wall rule: a blocker is reported with its exact output.\n\n'
    printf '**Channels (talk to Brokk):**\n\n'
    printf '%s\n' "- ask a question: write \`data/$id/questions/q-<n>.md\` — Brokk answers in \`answers/\`"
    printf '%s\n' "- steer arrives in \`data/$id/inbox/\` (acked by your arm)"
    printf '%s\n' "- completion marker: \`state/$id.done\` — your arm files the close hook"
    printf '\n**Expected close (the report contract):** write \`data/%s/result.md\`; the arm files the close hook, a rune is carved, and the Allfather tail + well lesson follow (law 7).\n' "$id"
    printf '\n**History (same wave):**\n\n'
    grep "| $id |" "$BACKLOG" 2>/dev/null | sed 's/^/  /' | head -5
    printf '\n**Citations:** plan 42 (\`%s\`), the errand book Part III-b (incl. the handoff minimum), Part II-c (per-machine), Part II-e (the mill).\n' "${PLAN42_REF:-svartalfaheim/whynotproductions/workspace/ymir/plans/42-federation-single-heart.md}"
  } > "$plan"
  printf '\n\n**Your planning document:** `data/%s/plan.md` — read it before you touch a command.\n' "$id" >> "$brief" 2>/dev/null || true

  # 2) the task record (so relaunch + the tracker know it, pre-spawn)
  meta_write "$id" "id=$id" "kind=$KIND" "mode=${MODE:-scout}" "wave=$WAVE" \
    "title=$TITLE" "scope=$SCOPE" "done=$DONE" "status=open" \
    "project=${repo:-$ROOT}" "created=$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  # 3) the backlog ledger
  backlog_append "$id" "$WAVE" "$KIND" "open" "${TITLE:-$id}"

  # 4) the arm — a task watcher that IS the handoff trigger (see eindri-arm.sh)
  if [ -x "$SCRIPT_DIR/eindri-arm.sh" ]; then
    mkdir -p "$DATA/$id"
    "$SCRIPT_DIR/eindri-arm.sh" "$id" >> "$DATA/$id/arm.log" 2>&1 &
    echo "armed $id (pid $! — log $DATA/$id/arm.log)"
  else
    echo "note: no eindri-arm.sh — arm falls to the spawn" >&2
  fi

  # 5) spawn (dry-run reports what would launch)
  if [ "$DRY" = 1 ]; then
    echo "dry-run: would spawn $id kind=$KIND mode=${MODE:-scout} harness=${HARNESS:-auto} backend=${BACKEND:-auto} worktree=${repo:-$ROOT}"
  elif [ -x "$SCRIPT_DIR/einherjar-spawn.sh" ]; then
    local sp=()
    [ "$SCOUT" = 1 ] && sp+=(--scout) || sp+=(--mode "$MODE")
    [ -n "$HARNESS" ] && sp+=(--harness "$HARNESS")
    [ -n "$BACKEND" ] && sp+=(--backend "$BACKEND")
    "$SCRIPT_DIR/einherjar-spawn.sh" "$id" "${repo:-$ROOT}" "${sp[@]}"
  else
    echo "note: no einherjar-spawn.sh — loop ends at the ledger" >&2
  fi
  say "open: $id → $BACKLOG"
}

cmd_close() {
  local id="${1-}" verdict=pass note=
  [ -n "$id" ] || { echo "error: close <id>" >&2; exit 2; }
  shift || true
  while [ $# -gt 0 ]; do
    case "$1" in
      --verdict) verdict="${2-}"; shift ;;
      --verdict=*) verdict=${1#--verdict=} ;;
      --note) note="${2-}"; shift ;;
      --note=*) note=${1#--note=} ;;
      *) echo "error: unknown '$1'" >&2; exit 2 ;;
    esac
    shift
  done
  case "$verdict" in pass|return|fail) ;; *) echo "error: --verdict pass|return|fail" >&2; exit 2 ;; esac
  # The close hook: the worker's result is filed, the backlog moves to
  # review — but the VERDICT is never self-issued: only Brokk/Forseti
  # (cmd_review) writes state/<id>.review, which is the arm's handoff ack.
  mkdir -p "$DATA/$id"
  [ -n "$note" ] && printf '%s\n' "$note" > "$DATA/$id/result.md"
  mv_state=review
  backlog_set_status "$id" "$mv_state" "${note:-worker-done, awaiting verdict}"
  printf 'closed=%s\nnote=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$note" > "$STATE/$id.close"
  say "closed $id → review (the verdict is Brokk/Forseti's, never the arm's)"
}

cmd_review() {
  local id="${1-}" verdict="${2-}" note=
  [ -n "$id" ] && [ -n "$verdict" ] || { echo "error: review <id> <pass|return> [--note …]" >&2; exit 2; }
  case "$verdict" in pass|return|fail) ;; *) echo "error: review pass|return|fail" >&2; exit 2 ;; esac
  shift 2 || true
  while [ $# -gt 0 ]; do case "$1" in --note) note="${2-}"; shift 2 ;; *) shift ;; esac; done
  mkdir -p "$STATE" "$DATA"
  printf 'reviewer=forseti\nverdict=%s\nnote=%s\ntime=%s\n' "$verdict" "$note" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$STATE/$id.review"
  case "$verdict" in
    pass) st=accepted ;;
    return) st=returned ;;
    fail) st=failed ;;
  esac
  backlog_set_status "$id" "$st" "forseti: $verdict $note"
  say "reviewed $id → $verdict (handoff ack — the arm retires now)"
}

cmd_steer() { # steer <id> <text...> — Brokk speaks to the worker (arm acks it)
  local id="${1-}"; shift || true
  [ -n "$id" ] && [ $# -gt 0 ] || { echo "error: steer <id> <text>" >&2; exit 2; }
  mkdir -p "$DATA/$id/inbox"
  local n=1; while [ -e "$DATA/$id/inbox/steer-$n.md" ]; do n=$((n+1)); done
  printf '%s\n%s\n' "# steer (Brokk → Eindri $id)" "$*" > "$DATA/$id/inbox/steer-$n.md"
  say "steered $id ← steer-$n.md"
}

cmd_questions() { # questions [id] — what the workers are asking Brokk
  local queried="${1-}"
  local d found=0
  for meta in "$STATE"/*.meta; do
    [ -f "$meta" ] || continue
    local id; id=$(basename "$meta" .meta)
    [ -n "$queried" ] && [ "$queried" != "$id" ] && continue
    local qd="$DATA/$id/questions"; [ -d "$qd" ] || continue
    for q in "$qd"/q-*.md; do
      [ -f "$q" ] || continue
      found=1
      printf 'Q %s %s: %s\n' "$id" "$(basename "$q")" "$(sed 's/^#.*//' "$q" | tr '\n' ' ' | head -c 160)"
    done
    # answered ones ride answers/; unanswered stay in questions/
    for a in "$DATA/$id/answers"/a-*.md; do
      [ -f "$a" ] || continue
      found=$found
    done
  done
  [ "$found" = 1 ] || say "questions: none pending"
}

cmd_answer() { # answer <id> <q-file> <text...> — Brokk answers the worker
  local id="${1-}" q="${2-}"; shift 2 || true
  [ -n "$id" ] && [ -n "$q" ] && [ $# -gt 0 ] || { echo "error: answer <id> <q-file> <text>" >&2; exit 2; }
  mkdir -p "$DATA/$id/answers"
  local n=1; while [ -e "$DATA/$id/answers/a-$n.md" ]; do n=$((n+1)); done
  printf '%s\n%s\n' "# answer (Brokk → Eindri $id, in reply to $q)" "$*" > "$DATA/$id/answers/a-$n.md"
  say "answered $id ($q) → a-$n.md (the arm acks it to the worker)"
}

cmd_status() {
  [ -f "$BACKLOG" ] || { echo "backlog: empty — no errands yet ($BACKLOG)"; return 0; }
  cat "$BACKLOG"
  # the activity tail: what the workers are doing right now
  local d beat age now q
  now=$(date +%s)
  for meta in "$STATE"/*.meta; do
    [ -f "$meta" ] || continue
    local id; id=$(basename "$meta" .meta)
    # a fresh arm beat = a live worker under watch
    beat="$STATE/$id.beat"
    if [ -f "$beat" ]; then
      age=$((now - $(stat -c %Y "$beat" 2>/dev/null || echo 0)))
      echo "  · arming $id — beat age ${age}s $([ -f "$STATE/$id.close" ] && echo '(done → awaiting verdict)' || echo '(open)')"
    fi
  done
  cmd_questions >/dev/null 2>&1 || true
}

case "${1-}" in
  -v|-V|--version) echo "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
CMD="${1-}"; shift || true
case "$CMD" in
  new) cmd_new "$@" ;;
  close) cmd_close "$@" ;;
  review) cmd_review "$@" ;;
  steer) cmd_steer "$@" ;;
  questions) cmd_questions "$@" ;;
  answer) cmd_answer "$@" ;;
  status) cmd_status "$@" ;;
  *) echo "error: unknown command '$CMD'" >&2; exit 2 ;;
esac