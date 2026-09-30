#!/usr/bin/env bash
# fm-notify-lib.sh — the watcher's path to the Allfather's desktop.
#
# The watcher already decides, on every poll, which events mean a human. Every
# one of those decisions ended in `wake`, which is an AGENT delivery: the reason
# is queued for firstmate, and whether firstmate then speaks to the Allfather is
# a model decision that a busy, context-starved or mid-turn session may drop.
# Nothing caught the drop, so a wedged crew stayed silent until he happened to
# look at the hall. That is why arming felt brittle: the arm fed a peer, not a
# person, so a missed wake cost a turn rather than a man standing in a room.
#
# This library is the missing edge. It reads the SAME actionable span the
# watcher just classified, speaks the human-meaningful verbs to the desktop
# through bin/ymir-say.sh (the single owner of "Ymir speaks"), and does nothing
# else. The agent wake is untouched and still happens; this is ADDITIONAL, never
# a replacement, so no supervision path loses its delivery.
#
# Dedup is durable and signature-keyed: an event is spoken once per distinct
# status line, not once per poll and not once per watcher. The marker lives
# beside the existing .seen-* family, so a restarted watcher stays quiet about
# what it already told the Allfather while a NEW event still speaks. Nothing is
# suppressed before it is spoken — the marker is written by fm_notify_speak
# itself, and only after ymir-say.sh was invoked.
#
# The verb set is deliberately the four human-meaningful ones. A bare turn-end or
# a `working:` note is not news; `done`, `needs-decision`, `blocked` and `failed`
# are the four ways a crew stops and needs him.

FM_NOTIFY_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_NOTIFY_LIB_REPO="$(cd "$FM_NOTIFY_LIB_DIR/../.." && pwd)"

# shellcheck source=bin/brokk-classify-lib.sh
[ -n "${BROKK_CLASSIFY_LIB_LOADED:-}" ] || {
  . "$FM_NOTIFY_LIB_REPO/bin/brokk-classify-lib.sh"
  BROKK_CLASSIFY_LIB_LOADED=1
}

# The one owner of the spoken surface. Overridable so the tests can capture the
# call without a desktop notifier present.
FM_NOTIFY_SAY_BIN="${BROKK_NOTIFY_SAY_BIN:-$FM_NOTIFY_LIB_REPO/bin/ymir-say.sh}"

# The four verbs that mean the Allfather, not the watcher. Matched against the
# leading verb word of the status line (status_line_verb), never a substring:
# a `done:` echoed inside a note must not raise the Allfather's desktop.
FM_NOTIFY_VERBS="done needs-decision blocked failed"

# How each verb is spoken. done is information; the other three are a request for
# his time, and a failure is the one that must not wait behind anything.
fm_notify_urgency() {  # <verb>
  case "$1" in
    done) printf 'note' ;;
    failed) printf 'critical' ;;
    *) printf 'normal' ;;
  esac
}

fm_notify_mark() {  # <verb> -> the ymir-say mode for that verb
  case "$1" in
    done) printf '%s' --mark-done ;;
    failed) printf '%s' --mark-fail ;;
    *) printf '%s' --mark-alarm ;;
  esac
}

# The durable "we already told him about this exact line" marker. Keyed on the
# task AND a hash of the line itself, so a task that finishes, then blocks again,
# then finishes again speaks three times — each a genuinely distinct state — while
# the four hundred polls in between stay silent.
fm_notify_marker_path() {  # <task> <line>
  local sig
  sig=$(printf '%s' "$2" | sha256sum 2>/dev/null | cut -c1-16)
  [ -n "$sig" ] || sig=$(printf '%s' "$2" | cksum | tr -d ' ' | cut -c1-16)
  printf '%s/.notified-%s-%s' "$STATE" "$1" "$sig"
}

fm_notify_already_said() {  # <task> <line>
  [ -e "$(fm_notify_marker_path "$1" "$2")" ]
}

# The newest Allfather-meaningful line in a task's status log, or empty. Read
# BACKWARD from the tail so this is O(1)-ish on a long log and never walks the
# whole file on a poll.
fm_notify_status_line() {  # <task>
  local f="$STATE/$1.status" line
  [ -e "$f" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in *[![:space:]]*) ;; *) continue ;; esac
    status_is_Allfather_relevant "$line" || continue
    last=$line
  done < <(tail -n 40 "$f" 2>/dev/null)
  printf '%s' "${last:-}"
}

fm_notify_speak() {  # <task> <line>
  local task=$1 line=$2 verb note mode marker tmp
  verb=$(status_line_verb "$line")
  case " $FM_NOTIFY_VERBS " in *" $verb "*) ;; *) return 0 ;; esac
  fm_notify_already_said "$task" "$line" && return 0
  note=$(status_line_note "$line" 2>/dev/null || true)
  mode=$(fm_notify_mark "$verb")
  # Marker first, then speak: the worst outcome is a suppressed notification
  # after a crash between the two, whereas speaking first and crashing would
  # re-announce on every poll forever. A repeated line is noise; a silent one is
  # the exact failure this library exists to remove.
  marker=$(fm_notify_marker_path "$task" "$line")
  tmp=$(umask 077; mktemp "$STATE/.notified.XXXXXX" 2>/dev/null) || tmp=
  if [ -n "$tmp" ]; then
    mv -f -- "$tmp" "$marker" 2>/dev/null || rm -f -- "$tmp" 2>/dev/null
  fi
  [ -x "$FM_NOTIFY_SAY_BIN" ] || "$FM_NOTIFY_SAY_BIN" >/dev/null 2>&1
  "$FM_NOTIFY_SAY_BIN" "$mode" "$task: $verb${note:+ - $note}" \
    --urgency "$(fm_notify_urgency "$verb")" >/dev/null 2>&1 || true
  triage_log "notified Allfather: $task $verb"
  return 0
}

# The entrypoint the watcher calls once it has decided an event is actionable.
# A no-op for a task with no human-meaningful line, which is the common case
# (a bare turn-end, a working note, an unreadable log).
fm_notify_task() {  # <task>
  local task=$1 line
  [ -n "$task" ] || return 0
  line=$(fm_notify_status_line "$task")
  [ -n "$line" ] || return 0
  fm_notify_speak "$task" "$line"
}

# The bulk form, for a watcher pass that has just surfaced several status files
# at once. Each file is independent; one failure never skips the rest.
fm_notify_tasks() {  # <task> ...
  local t
  for t in "$@"; do fm_notify_task "$t" || true; done
  return 0
}

# The watcher's own form: it holds a space-separated list of status FILE paths
# (the FM_*_SURFACE_ENDPOINTS shape), not task ids. Strips the suffix here so no
# caller has to, and ignores anything that is not a status file.
fm_notify_files() {  # <status-file> ...
  local f base
  for f in "$@"; do
    case "$f" in *.status) ;; *) continue ;; esac
    base=$(basename "$f"); base=${base%.status}
    fm_notify_task "$base" || true
  done
  return 0
}