#!/usr/bin/env bash
# saga-head-lib.sh — what is NEWS in Sága's short head (plan 275, item 28 §3).
#
# The head is read at every session start, so it must not carry history. This
# library is the policy, in one place, and it reads with shell builtins only: the
# state shelf holds 163 seat records, and a subprocess per record made the head cost
# 3.5 s (the very latency that makes an agent skip it).
#
#   · a LIVE errand — a record whose last word still claims life — is always shown;
#   · a FINISHED errand is shown ONCE, then folded into `.saga-head-seen`;
#   · an UNKNOWN row — a record whose pane can never be read on this machine (a
#     tmux window that no longer exists) — is reaped once and never printed again;
#   · anything older than the head's own last run was already reported (the old
#     696-line digest printed every one of them), so the first run SEEDS the markers
#     instead of reporting 156 errands as news. One `find -newer` answers "what is
#     newer than the last head" — never a stat per record.
#
# The only writes are the two bookkeeping files it owns in the state dir
# (`.saga-head-seen`, `.saga-head-last-run`). A seat record is never touched: the
# judge is bin/agents/eindri-liveness.sh, and this is the presenter.
#
# Source-safe (defines functions only). The caller owns the state dir.
set -u

# stat differs between GNU and BSD/macOS: probe, never assume (RULES/05).
saga_head_mtime() {  # <path> -> epoch seconds (0 when unreadable)
  [ -e "${1-}" ] || { printf '0'; return 0; }
  stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || printf '0'
}

saga_head_seen_file()    { printf '%s/.saga-head-seen' "${1:?state dir}"; }
saga_head_lastrun_file() { printf '%s/.saga-head-last-run' "${1:?state dir}"; }

# The fixed core as a READER gets it: every line above the CHANGE LOG. The history is the
# document's (RULES/06) and stays in the file; the context a worker spends is the core alone.
saga_head_core_text() {  # <core-file>
  [ -r "${1-}" ] || return 1
  awk '/^#? *#? *(CHANGE|Change) ?(LOG|Log)/{exit} {print}' "$1"
}

# The terminal word of a seat's record: its own, never an inference.
saga_head_is_terminal() {
  case "${1-}" in
    done:*|failed:*|needs-decision:*|paused:*) return 0 ;;
  esac
  return 1
}

# The windows tmux can still show, one per line. Empty when tmux is absent — and
# that is exactly the UNKNOWN row this lib reaps: a tmux-backed record on a machine
# that no longer runs tmux can never be read again (RULES/25: say so, then stop).
saga_head_tmux_windows() {
  command -v tmux >/dev/null 2>&1 || return 0
  tmux list-panes -a -F '#{window_id}' 2>/dev/null | sort -u
}

# saga_head_errand_block <state> [max_live] [max_finished]
# Prints the LIVE ERRANDS block (head lines only), and records what it reported.
saga_head_errand_block() {
  local state=${1:?state dir} max_live=${2:-6} max_fin=${3:-3}
  local seenf lastrunf first_run=0 now f id status claim backend pane launched age key l
  local -a live_ids=() live_meta=() fin=() reap=() new_seen=()
  local folded=0
  declare -A seen=() windows=() is_new=()

  seenf="$(saga_head_seen_file "$state")"
  lastrunf="$(saga_head_lastrun_file "$state")"
  now="$(date +%s)"
  [ -e "$lastrunf" ] || first_run=1
  if [ -r "$seenf" ]; then
    while IFS= read -r key || [ -n "$key" ]; do
      [ -n "$key" ] && seen["$key"]=1
    done <"$seenf"
  fi
  while IFS= read -r key; do
    [ -n "$key" ] && windows["$key"]=1
  done < <(saga_head_tmux_windows)
  # ONE door for "what changed since the last head" (portable: find -newer <marker file>).
  if [ "$first_run" = 0 ]; then
    while IFS= read -r f; do
      [ -n "$f" ] && is_new["${f##*/}"]=1
    done < <(find "$state" -maxdepth 1 -name '*.status' -newer "$lastrunf" 2>/dev/null)
  fi

  for f in "$state"/*.meta; do
    [ -f "$f" ] || continue
    id="${f##*/}"; id="${id%.meta}"
    status="$state/$id.status"
    [ -r "$status" ] || continue
    backend=""; pane=""; launched=""
    while IFS= read -r l || [ -n "$l" ]; do
      case "$l" in
        backend=*)  backend="${l#backend=}" ;;
        window=*)   pane="${l#window=}" ;;
        launched=*) launched="${l#launched=}" ;;
      esac
    done <"$f"
    claim=""
    while IFS= read -r l || [ -n "$l" ]; do claim="$l"; done <"$status"
    claim="${claim%$'\r'}"
    [ -n "$claim" ] || continue

    if saga_head_is_terminal "$claim"; then
      # Already reported: older than the last head, or marked seen.
      if [ "$first_run" = 1 ] || [ -z "${is_new[$id.status]:-}" ]; then
        folded=$((folded + 1)); continue
      fi
      key="$id:$(saga_head_mtime "$status")"
      [ -n "${seen[$key]:-}" ] && continue
      seen["$key"]=1; new_seen+=("$key")
      fin+=("  \"$id\",\"$(printf '%s' "$claim" | tr -d '"' | cut -c1-100)\"")
      continue
    fi

    if [ "$backend" = tmux ] && [ -n "$pane" ] && [ -z "${windows[$pane]:-}" ]; then
      key="reaped:$id"
      [ -n "${seen[$key]:-}" ] && continue
      seen["$key"]=1; new_seen+=("$key")
      reap+=("$id"); continue
    fi

    case "$launched" in ''|*[!0-9]*) age="—" ;; *) age="$(( (now - launched) / 3600 ))h" ;; esac
    live_ids+=("$id"); live_meta+=("${pane:-—}|${age}")
  done

  # The block. Oldest first: the errand that has stood longest is the one to look at.
  local i n
  n=${#live_ids[@]}
  printf 'live[%s]{id,pane,age}:\n' "$n"
  for ((i = 0; i < n && i < max_live; i++)); do
    printf '  "%s","%s","%s"\n' "${live_ids[$i]}" "${live_meta[$i]%%|*}" "${live_meta[$i]##*|}"
  done
  [ "$n" -gt "$max_live" ] && printf '  … and %s more: --section liveness\n' "$((n - max_live))"
  [ "$n" -eq 0 ] && printf '  none — no errand claims life\n'

  if [ "${#fin[@]}" -gt 0 ]; then
    printf 'finished since the last head (reported once, then gone):\n'
    for ((i = 0; i < ${#fin[@]} && i < max_fin; i++)); do printf '%s\n' "${fin[$i]}"; done
    [ "${#fin[@]}" -gt "$max_fin" ] && printf '  … and %s more: --section liveness\n' "$(( ${#fin[@]} - max_fin ))"
  fi
  if [ "${#reap[@]}" -gt 0 ]; then
    printf 'reaped: %s UNKNOWN row(s) whose pane can never be read here — %s\n' \
      "${#reap[@]}" "$(printf '%s ' "${reap[@]}" | cut -c1-90)"
  fi
  if [ "$first_run" = 1 ]; then
    printf 'first run of the head: %s finished errand(s) folded away, %s row(s) reaped (they were reported by the old digest)\n' \
      "$folded" "${#reap[@]}"
  fi

  # Record: only the markers that are NEW this run, and this run's instant. A dry run
  # (--check) measures the head and must never eat the news it measures.
  [ "${SAGA_HEAD_DRY:-0}" = 1 ] && return 0
  if [ "${#new_seen[@]}" -gt 0 ]; then
    printf '%s\n' "${new_seen[@]}" >>"$seenf" 2>/dev/null || true
  fi
  printf '%s\n' "$now" >"$lastrunf" 2>/dev/null || true
  return 0
}
