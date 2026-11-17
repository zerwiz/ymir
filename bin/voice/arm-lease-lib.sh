#!/usr/bin/env bash
# arm-lease-lib.sh — the LEASE: a project's right to spawn hands on a machine, and the
# record that says whether it is still alive (plan 310 §4).
#
# WHY A FILE. On 2026-11-17 the heart's arm read `held` all morning while every pi on that
# machine was dead: a claim that LOOKED alive. A right that lives only in a conversation
# cannot be reclaimed, cannot be read by the next machine, and cannot be argued with. So a
# lease is a ROW — one row per lease, one file, in the state the arm already uses:
#
#   <state>/.arm.leases      one tab-separated row per lease, one lease per row
#   <state>/.arm.leases.log  the append-only journal of every grant, renew and reclaim
#
# The row is exactly the shape the plan names, neither more nor fewer columns:
#
#   lease{n,holder,machine,scope,hands,granted,expires,heartbeat}
#
#     n          the lease number, never reused (the journal keeps the ones that ended)
#     holder     who holds it — the seat/agent name (a name, never a claim of a mind)
#     machine    the machine it was granted on; a lease never travels
#     scope      the project it is for ("ymir", "foreman"), or `*` for the whole machine
#     hands      how many workers that lease may have standing at once
#     granted    epoch seconds it was issued
#     expires    epoch seconds it must be renewed by
#     heartbeat  epoch seconds of the last renewal — the one field that says "still here"
#
# THE LAWS THIS FILE HOLDS
#
#   1 · A LEASE WHOSE HEARTBEAT STOPS IS RECLAIMABLE BY THE MACHINE, WITHOUT ASKING
#       ANYONE. `arm_lease_reclaim` needs no permission and no second party: a dead
#       heartbeat IS the permission. A LIVE lease is refused — reclaiming a living claim
#       would be theft, and theft reads exactly like authority afterwards.
#   2 · ONE WRITER. Every mutation takes the same mkdir lock and rewrites the table through
#       a temporary file, so two grants in the same second cannot lose each other.
#   3 · NOTHING IS DELETED FROM THE RECORD. A reclaim removes the ROW (the table is state)
#       and APPENDS the event to the journal (the journal is history). Rule 06.
#   4 · ONE NUMBER PER DECISION. How many hands and how long a lease runs are the
#       Allfather's (plan 310 §7.2); until he says otherwise they are the two constants
#       below, overridable from the environment and never restated in a caller.
#
# Source-safe: defines functions and constants only; it runs nothing at source time.
set -u

_ARM_LEASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=bin/voice/arm-speak-lib.sh
. "$_ARM_LEASE_DIR/arm-speak-lib.sh"

# The two conservative defaults the Allfather has not yet ruled on (plan 310 §7.2):
# two hands, one hour. One constant each, one place.
ARM_LEASE_HANDS="${YMIR_ARM_LEASE_HANDS:-2}"
ARM_LEASE_TTL="${YMIR_ARM_LEASE_TTL:-3600}"
# A lease whose heartbeat has not been renewed for this long can be reclaimed; the
# expiry is the formal end, this is the silence that precedes it.
ARM_LEASE_STALE="${YMIR_ARM_LEASE_STALE:-300}"

ARM_LEASE_LOCK_NAME=".arm.leases.lock"
ARM_LEASE_HEADER='#lease{n,holder,machine,scope,hands,granted,expires,heartbeat}'

# The standing result of the last row read. Every verb fills these.
LEASE_N=""; LEASE_HOLDER=""; LEASE_MACHINE=""; LEASE_SCOPE=""
LEASE_HANDS=""; LEASE_GRANTED=""; LEASE_EXPIRES=""; LEASE_HEARTBEAT=""
LEASE_AGE=""; LEASE_LEFT=""; LEASE_LIVE=""

arm_lease_file() {  # <state-dir> — the one table
  printf '%s/.arm.leases' "${1:?arm_lease_file needs a state dir}"
}

arm_lease_journal() {  # <state-dir> — the append-only history
  printf '%s/.arm.leases.log' "${1:?arm_lease_journal needs a state dir}"
}

arm_machine_name() {  # the machine a lease is granted on: its own name, never a peer's
  hostname -s 2>/dev/null || printf 'unknown'
}

arm_lease_sexagesimal() {  # <epoch> — minutes until then, for a person to read
  local left; left=$(( ${1:-0} - $(date +%s) ))
  if [ "$left" -le 0 ]; then printf 'expired'; return 0; fi
  if [ "$left" -ge 3600 ]; then printf '%sh%02dm' "$((left / 3600))" "$(((left % 3600) / 60))"
  elif [ "$left" -ge 60 ]; then printf '%sm' "$((left / 60))"
  else printf '%ss' "$left"; fi
}

# ── the lock: one writer at a time, mkdir-based so nothing has to be installed ──
arm_lease_lock() {  # <state-dir>
  local lock="${1:?}/${ARM_LEASE_LOCK_NAME}" tries=0
  while ! mkdir "$lock" 2>/dev/null; do
    tries=$((tries + 1))
    if [ "$tries" -ge 100 ]; then
      # A lock left behind by a killed writer must not stop the house for ever: a lock
      # older than ten seconds is broken BY NAME, and the break is journalled.
      if [ -n "$(find "$lock" -maxdepth 0 -mmin +0.16 2>/dev/null)" ]; then
        rmdir "$lock" 2>/dev/null || true
        printf '%s break %s %s\n' "$(date +%s)" "-" "-" >> "$(arm_lease_journal "$1")" 2>/dev/null || true
        continue
      fi
      printf 'arm-lease: the lease table lock %s is held by another writer\n' "$lock" >&2
      return 1
    fi
    sleep 0.05
  done
  return 0
}

arm_lease_unlock() {  # <state-dir>
  rmdir "${1:?}/${ARM_LEASE_LOCK_NAME}" 2>/dev/null || true
}

# ── reading ───────────────────────────────────────────────────────────────────
# arm_lease_row <table> <n> — fill the LEASE_* fields from row <n>. 0 found · 1 absent.
arm_lease_row() {
  local table="${1:?}" want="${2:?}" line n holder machine scope hands granted expires heartbeat
  LEASE_N=""; LEASE_HOLDER=""; LEASE_MACHINE=""; LEASE_SCOPE=""; LEASE_HANDS=""
  LEASE_GRANTED=""; LEASE_EXPIRES=""; LEASE_HEARTBEAT=""
  [ -r "$table" ] || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) continue ;; esac
    IFS=$'\t' read -r n holder machine scope hands granted expires heartbeat <<<"$line"
    [ "$n" = "$want" ] || continue
    LEASE_N="$n"; LEASE_HOLDER="$holder"; LEASE_MACHINE="$machine"; LEASE_SCOPE="$scope"
    LEASE_HANDS="$hands"; LEASE_GRANTED="$granted"; LEASE_EXPIRES="$expires"
    LEASE_HEARTBEAT="$heartbeat"
    return 0
  done <"$table"
  return 1
}

# arm_lease_fresh — is the row just read still beating? 0 live · 1 dead. Sets LEASE_AGE,
# LEASE_LEFT, LEASE_LIVE and LEASE_WHY.
arm_lease_fresh() {
  local now; now="$(date +%s)"
  LEASE_WHY=""
  case "$LEASE_HEARTBEAT" in ''|*[!0-9]*)
    LEASE_LIVE=no; LEASE_WHY="the row carries no heartbeat — freshness cannot be proved"
    return 1 ;;
  esac
  LEASE_AGE=$(( now - LEASE_HEARTBEAT )); [ "$LEASE_AGE" -ge 0 ] || LEASE_AGE=0
  case "$LEASE_EXPIRES" in ''|*[!0-9]*) LEASE_LEFT=0 ;; *) LEASE_LEFT=$(( LEASE_EXPIRES - now )) ;; esac
  if [ "$LEASE_AGE" -gt "$ARM_LEASE_STALE" ]; then
    LEASE_LIVE=no
    LEASE_WHY="the heartbeat stopped ${LEASE_AGE}s ago (silence over ${ARM_LEASE_STALE}s) — this lease is reclaimable"
    return 1
  fi
  if [ "$LEASE_LEFT" -le 0 ]; then
    LEASE_LIVE=no
    LEASE_WHY="the lease expired $((-LEASE_LEFT))s ago and was never renewed"
    return 1
  fi
  LEASE_LIVE=yes
  LEASE_WHY="live — heartbeat ${LEASE_AGE}s ago, $(arm_lease_sexagesimal "$LEASE_EXPIRES") left"
  return 0
}

# arm_lease_live_for <state-dir> <scope> [machine] — a live lease covering this scope on
# this machine. 0 found (LEASE_* filled) · 1 none. A scope of `*` covers anything.
arm_lease_live_for() {
  local state="${1:?}" want="${2:?}" mach="${3:-}" table line n
  table="$(arm_lease_file "$state")"
  [ -r "$table" ] || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) continue ;; esac
    n="${line%%$'\t'*}"
    arm_lease_row "$table" "$n" || continue
    [ -n "$mach" ] && [ "$LEASE_MACHINE" != "$mach" ] && continue
    [ "$LEASE_SCOPE" = "$want" ] || [ "$LEASE_SCOPE" = '*' ] || continue
    arm_lease_fresh || continue
    return 0
  done <"$table"
  return 1
}

arm_lease_next_n() {  # <table> — one past the highest number this table has ever carried
  local table="${1:?}" line n max=0
  [ -r "$table" ] || { printf '1'; return 0; }
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) continue ;; esac
    n="${line%%$'\t'*}"
    case "$n" in ''|*[!0-9]*) continue ;; esac
    [ "$n" -gt "$max" ] && max="$n"
  done <"$table"
  # The journal remembers numbers the table no longer carries, so a reclaim never frees a
  # number for reuse. Ask it too.
  local j; j="$(arm_lease_journal "${table%/*}")"
  if [ -r "$j" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      set -- $line
      n="${3:-}"
      case "$n" in ''|*[!0-9]*) continue ;; esac
      [ "$n" -gt "$max" ] && max="$n"
    done <"$j"
  fi
  printf '%s' "$((max + 1))"
}

arm_lease_journal_add() {  # <state-dir> <event> <n> <holder> <machine> <scope> <detail>
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$(date +%s)" "${2:--}" "${3:--}" "${4:--}" "${5:--}" "${6:--}" "${7:--}" \
    >> "$(arm_lease_journal "$1")"
}

# ── writing ───────────────────────────────────────────────────────────────────
# arm_lease_grant <state-dir> <holder> <scope> [hands] [ttl] [machine]
# Appends one row and returns 0; sets LEASE_* to the new row.
arm_lease_grant() {
  local state="${1:?}" holder="${2:?}" scope="${3:?}"
  local hands="${4:-$ARM_LEASE_HANDS}" ttl="${5:-$ARM_LEASE_TTL}" machine="${6:-}"
  local table n now expires tmp
  [ -n "$machine" ] || machine="$(arm_machine_name)"
  case "$hands" in ''|*[!0-9]*|0) hands="$ARM_LEASE_HANDS" ;; esac
  case "$ttl" in ''|*[!0-9]*|0) ttl="$ARM_LEASE_TTL" ;; esac
  mkdir -p "$state" || return 1
  table="$(arm_lease_file "$state")"
  arm_lease_lock "$state" || return 1
  n="$(arm_lease_next_n "$table")"
  now="$(date +%s)"; expires=$(( now + ttl ))
  tmp="$table.$$"
  {
    if [ -r "$table" ]; then cat "$table"; else printf '%s\n' "$ARM_LEASE_HEADER"; fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$n" "$holder" "$machine" "$scope" "$hands" "$now" "$expires" "$now"
  } >"$tmp" && mv "$tmp" "$table" || { rm -f "$tmp"; arm_lease_unlock "$state"; return 1; }
  arm_lease_journal_add "$state" grant "$n" "$holder" "$machine" "$scope" "hands=$hands ttl=${ttl}s"
  arm_lease_unlock "$state"
  arm_lease_row "$table" "$n" || return 1
  return 0
}

# arm_lease_renew <state-dir> <n> [ttl] — a live lease beats again. A DEAD lease is not
# renewed (that would resurrect a claim the machine may already have reclaimed): it is
# refused and the remedy is a new grant.
arm_lease_renew() {
  local state="${1:?}" n="${2:?}" ttl="${3:-$ARM_LEASE_TTL}" table tmp line now expires
  case "$ttl" in ''|*[!0-9]*|0) ttl="$ARM_LEASE_TTL" ;; esac
  table="$(arm_lease_file "$state")"
  arm_lease_lock "$state" || return 1
  if ! arm_lease_row "$table" "$n"; then
    arm_lease_unlock "$state"; return 2
  fi
  now="$(date +%s)"; expires=$(( now + ttl ))
  tmp="$table.$$"
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) printf '%s\n' "$line"; continue ;; esac
    if [ "${line%%$'\t'*}" = "$n" ]; then
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$LEASE_N" "$LEASE_HOLDER" "$LEASE_MACHINE" "$LEASE_SCOPE" "$LEASE_HANDS" \
        "$LEASE_GRANTED" "$expires" "$now"
    else
      printf '%s\n' "$line"
    fi
  done <"$table" >"$tmp" && mv "$tmp" "$table" || { rm -f "$tmp"; arm_lease_unlock "$state"; return 1; }
  arm_lease_journal_add "$state" renew "$n" "$LEASE_HOLDER" "$LEASE_MACHINE" "$LEASE_SCOPE" "expires=$expires"
  arm_lease_unlock "$state"
  arm_lease_row "$table" "$n"
}

# arm_lease_reclaim <state-dir> <n> [why] — the machine takes the lease back, and needs
# NOBODY'S PERMISSION to do it: a stopped heartbeat IS the permission. A live lease is
# refused (exit 3) because reclaiming a living claim is theft.
arm_lease_reclaim() {
  local state="${1:?}" n="${2:?}" why="${3:-heartbeat stopped}" table tmp line
  table="$(arm_lease_file "$state")"
  arm_lease_lock "$state" || return 1
  if ! arm_lease_row "$table" "$n"; then
    arm_lease_unlock "$state"; return 2
  fi
  if arm_lease_fresh; then
    arm_lease_unlock "$state"; return 3
  fi
  tmp="$table.$$"
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) printf '%s\n' "$line"; continue ;; esac
    [ "${line%%$'\t'*}" = "$n" ] && continue
    printf '%s\n' "$line"
  done <"$table" >"$tmp" && mv "$tmp" "$table" || { rm -f "$tmp"; arm_lease_unlock "$state"; return 1; }
  arm_lease_journal_add "$state" reclaim "$n" "$LEASE_HOLDER" "$LEASE_MACHINE" "$LEASE_SCOPE" "$why"
  arm_lease_unlock "$state"
  return 0
}

# ── who may act ───────────────────────────────────────────────────────────────
arm_pid_live() {  # <pid>
  case "${1:-}" in ''|*[!0-9]*) return 1 ;; esac
  kill -0 "$1" 2>/dev/null
}

# arm_hand <state-dir> — THE HAND ON THIS MACHINE: the pid that holds the machine's own
# session lock, else the session the arm's role sidecar names, else the lease's session, else
# the lease's own pid. A DEAD pid is never a hand (a stale sidecar once named a session that
# had not existed for hours, and the digest reported it as the hand), so each candidate is
# checked for life before it is returned. A pid that is alive but cannot speak IS returned:
# the caller then says why the arm grants nothing, which is the whole point of §1.
arm_hand() {
  local state="${1:?}" owner="" sess="" pid="" side
  if [ -r "$_ARM_LEASE_DIR/../vault/gleipnir-lock-lib.sh" ]; then
    owner="$(
      unset BROKK_STATE_OVERRIDE BROKK_MACHINE_STATE_DIR
      # shellcheck source=bin/vault/gleipnir-lock-lib.sh
      . "$_ARM_LEASE_DIR/../vault/gleipnir-lock-lib.sh" 2>/dev/null || exit 0
      gleipnir_lock_owner _o 2>/dev/null || exit 0
      printf '%s' "${_o:-}"
    )"
  fi
  if arm_pid_live "$owner"; then printf '%s' "$owner"; return 0; fi
  side="$state/.arm.role"
  if [ -r "$side" ]; then
    sess="$(sed -nE 's/(^|.* )session=([^ ]*).*/\2/p' "$side" 2>/dev/null | head -1)"
    if arm_pid_live "$sess"; then printf '%s' "$sess"; return 0; fi
  fi
  if [ -r "$state/.arm.lease" ]; then
    sess="$(sed -nE 's/(^|.* )session=([^ ]*).*/\2/p' "$state/.arm.lease" 2>/dev/null | head -1)"
    if arm_pid_live "$sess"; then printf '%s' "$sess"; return 0; fi
    pid="$(sed -nE 's/(^|.* )pid=([^ ]*).*/\2/p' "$state/.arm.lease" 2>/dev/null | head -1)"
    if arm_pid_live "$pid"; then printf '%s' "$pid"; return 0; fi
  fi
  return 1
}

# arm_speaking_harness — IS THERE A MIND ON THIS MACHINE AT ALL? Walks the live harness
# processes and returns the first whose own transcript is fresh, as "<pid> <comm>".
# This is the machine-level question, and it is asked only after the narrower hands have
# failed: a lease names a project, a hand names a session, and this names the box. It says
# `borrowed` in the authority row, because a mind elsewhere on the box is not the mind that
# asked (RULES/25: a borrowed capability says so).
# Fills SPEAK_FOUND_PID, SPEAK_FOUND_PROOF and SPEAK_FOUND_AGE (the caller prints them).
arm_speaking_harness() {
  local one pid
  SPEAK_FOUND_PID=""; SPEAK_FOUND_PROOF=""; SPEAK_FOUND_AGE=""
  for one in $SPEAK_HARNESSES; do
    for pid in $(pgrep -x "$one" 2>/dev/null | head -40); do
      if speaks_probe "$pid"; then
        SPEAK_FOUND_PID="$pid"; SPEAK_FOUND_PROOF="$SPEAK_PROOF"; SPEAK_FOUND_AGE="$SPEAK_AGE"
        return 0
      fi
    done
  done
  return 1
}

# arm_scope_of [dir] — the project a caller acts for: the shape a lease's scope is granted
# in. The MAIN worktree's name (a worktree of ymir is still the ymir project), else the
# git toplevel's name, else the directory's.
arm_scope_of() {
  local dir="${1:-$PWD}" main base
  if [ -n "${YMIR_ARM_SCOPE:-}" ]; then printf '%s' "$YMIR_ARM_SCOPE"; return 0; fi
  main="$(git -C "$dir" worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p' | head -1)"
  base="${main:-$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || true)}"
  [ -n "$base" ] || base="$dir"
  base="${base%/}"
  printf '%s' "${base##*/}"
}

# arm_arm_held <state-dir> — is the MACHINE ARM held on this box? 0 held · 1 not.
# The arm door owns that judgement (a live pid, a matching starttime, a fresh heartbeat, a
# state dir that exists), so it is ASKED, never re-derived here: two answers to one question
# is the drift this house keeps paying for.
arm_arm_held() {
  local state="${1:?}" door out
  door="$_ARM_LEASE_DIR/rodd-arm.sh"
  [ -x "$door" ] || return 1
  RODD_ARM_LEASE="$state/.arm.lease" YMIR_STATE_DIR="$state" bash "$door" --check >/dev/null 2>&1
}

# arm_authority <state-dir> <scope> — WHICH authority a spawn may use here, and WHY.
# 0 granted · 3 refused. Sets AUTH_VERDICT, AUTH_SOURCE (lease|arm|none), AUTH_WHY, and the
# LEASE_* fields when a lease answered.
#
# THE LEASE COMES FIRST: it is the narrower grant (one project, N hands, until T). The
# machine arm comes second, and it is an authority only when (a) it is actually held and
# (b) A HAND THAT CAN SPEAK IS BEHIND IT — either the session asking, or the machine's own
# hand. A supervisor that beats but cannot answer is the exact fault this plan closes
# (plan 310 §1: the heart's arm read `held` all morning while every pi there was dead).
arm_authority() {
  local state="${1:?}" scope="${2:?}" machine hand= caller=""
  AUTH_VERDICT=refused; AUTH_SOURCE=none; AUTH_WHY=""
  machine="$(arm_machine_name)"
  if arm_lease_live_for "$state" "$scope" "$machine"; then
    AUTH_VERDICT=granted; AUTH_SOURCE=lease
    AUTH_WHY="lease $LEASE_N — $LEASE_HOLDER on $LEASE_MACHINE, scope $LEASE_SCOPE, $LEASE_HANDS hand(s), $(arm_lease_sexagesimal "$LEASE_EXPIRES") left, heartbeat ${LEASE_AGE}s"
    return 0
  fi
  if ! arm_arm_held "$state"; then
    hand="$(arm_hand "$state" || true)"
    if [ -n "$hand" ]; then
      AUTH_WHY="no live lease for scope '$scope' on $machine, and no machine arm is held here (the lease names pid $hand, which does not answer as an arm)"
    else
      AUTH_WHY="no live lease for scope '$scope' on $machine, and no machine arm is held here — nothing may be spawned under no authority"
    fi
    return 3
  fi
  # Each probe overwrites the SPEAK_* fields, so the reasons are captured as they are met:
  # a refusal that quotes the LAST probe instead of the RELEVANT one reads as a lie.
  speaks_claimant_pid caller
  local ask_why="" hand_why=""
  if speaks_probe "$caller"; then
    AUTH_VERDICT=granted; AUTH_SOURCE=arm
    AUTH_WHY="the machine arm on $machine — asked by session pid $caller, which speaks: $SPEAK_WHY"
    return 0
  fi
  ask_why="$SPEAK_WHY"
  hand="$(arm_hand "$state" || true)"
  if [ -n "$hand" ] && speaks_probe "$hand"; then
    AUTH_VERDICT=granted; AUTH_SOURCE=arm
    AUTH_WHY="the machine arm on $machine — its hand (pid $hand) speaks: $SPEAK_WHY"
    return 0
  fi
  [ -n "$hand" ] && hand_why="$SPEAK_WHY"
  if arm_speaking_harness; then
    AUTH_VERDICT=granted; AUTH_SOURCE=arm
    AUTH_WHY="the machine arm on $machine — borrowed hand: pid $SPEAK_FOUND_PID is speaking on this box (${SPEAK_FOUND_PROOF}, ${SPEAK_FOUND_AGE}s ago); the asking session (pid $caller) is not itself a speaker"
    return 0
  fi
  AUTH_WHY="the machine arm is held on $machine but NOBODY BEHIND IT CAN SPEAK — the asking session (pid $caller): $ask_why"
  if [ -n "$hand" ]; then
    AUTH_WHY="$AUTH_WHY; the machine's hand (pid $hand) cannot speak either: $hand_why"
  fi
  AUTH_WHY="$AUTH_WHY; no harness on this box has spoken recently; no lease covers scope '$scope'"
  return 3
}

# ── the ranks (plan 310 §3) ───────────────────────────────────────────────────
# arm_rank_line <state-dir> [session-pid] — WHICH RANK THIS SEAT HOLDS, in one line a
# digest can print. Three ranks, one lock each: the machine arm (the right to act on this
# machine), a project orchestrator (a lease's holder — hands, not sovereignty), and the
# crown (one for the fleet). A seat with none of them is read-only, and SAYS SO together
# with the one door a read-only agent keeps: it may always ASK.
arm_rank_line() {
  local state="${1:?}" sess="${2:-}" leash="" lease state_mach n_leases=0 crown=no hand rank why
  state_mach="$(arm_machine_name)"
  leash="$state/.arm.lease"
  # Crown: a live lease whose scope is the fleet itself. The crown's own service is the
  # Allfather's to seal (plan 310 §7.3); the RANK is only read here.
  if [ -r "$(arm_lease_file "$state")" ]; then
    n_leases="$(awk -F'\t' '!/^#/ && NF>=8' "$(arm_lease_file "$state")" 2>/dev/null | awk 'END{print NR}')"
  fi
  if arm_lease_live_for "$state" crown "$state_mach"; then crown=yes; fi
  # The machine arm: this session is the machine's hand, and it speaks.
  hand="$(arm_hand "$state" || true)"
  if [ -n "$sess" ] && [ "$hand" = "$sess" ] && speaks_probe "$sess"; then
    printf 'rank: this seat HOLDS THE MACHINE ARM on %s (pid %s, %s) · leases: %s · %s\n' \
      "$state_mach" "$sess" "$SPEAK_PROOF ${SPEAK_AGE}s" "${n_leases:-0}" \
      "$([ "$crown" = yes ] && printf 'the crown has a live row here' || printf 'no crown row on this machine')"
    return 0
  fi
  # A project orchestrator: a live lease whose holder is this seat's name.
  if arm_lease_live_for "$state" "$(arm_scope_of)" "$state_mach"; then
    printf 'rank: this seat holds a PROJECT LEASE on %s — lease %s, scope %s, %s hand(s), %s left · arm hand %s · %s\n' \
      "$state_mach" "$LEASE_N" "$LEASE_SCOPE" "$LEASE_HANDS" \
      "$(arm_lease_sexagesimal "$LEASE_EXPIRES")" "${hand:-none}" \
      "$([ "$crown" = yes ] && printf 'the crown has a live row here' || printf 'no crown row on this machine')"
    return 0
  fi
  rank="read-only"
  why="no machine arm and no live lease on $state_mach"
  if [ -n "$hand" ]; then
    if speaks_probe "$hand"; then
      why="the machine arm's hand (pid $hand) speaks, but this session (pid ${sess:-?}) is not it, and no lease covers $(arm_scope_of)"
    else
      why="the machine arm's hand (pid $hand) cannot speak: $SPEAK_WHY"
    fi
  fi
  printf 'rank: %s — %s. It may still ASK: bin/seat/lock-ask.sh ask "<question>"\n' "$rank" "$why"
  return 0
}

# arm_ranks_rows <state-dir> [session-pid] — who holds WHAT, one TOON row per holder.
# Read-only: it reports, it grants nothing.
arm_ranks_rows() {
  local state="${1:?}" sess="${2:-}" table line n hand machine
  machine="$(arm_machine_name)"
  table="$(arm_lease_file "$state")"
  hand="$(arm_hand "$state" || true)"
  printf 'ranks{who,rank,machine,scope,hands,standing,proof}:\n'
  if [ -n "$hand" ]; then
    if speaks_probe "$hand"; then
      printf '  "pid %s","machine arm","%s","the desk","-","held","%s %ss"\n' \
        "$hand" "$machine" "$SPEAK_PROOF" "$SPEAK_AGE"
    else
      printf '  "pid %s","machine arm (cannot speak)","%s","the desk","-","unproven","%s"\n' \
        "$hand" "$machine" "$SPEAK_WHY"
    fi
  else
    printf '  "nobody","machine arm","%s","the desk","-","vacant","no hand on this box"\n' "$machine"
  fi
  if [ -r "$table" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in ''|'#'*) continue ;; esac
      n="${line%%$'\t'*}"
      arm_lease_row "$table" "$n" || continue
      if arm_lease_fresh; then
        printf '  "%s","orchestrator","%s","%s","%s","lease %s, %s left","heartbeat %ss"\n' \
          "$LEASE_HOLDER" "$LEASE_MACHINE" "$LEASE_SCOPE" "$LEASE_HANDS" "$LEASE_N" \
          "$(arm_lease_sexagesimal "$LEASE_EXPIRES")" "$LEASE_AGE"
      else
        printf '  "%s","orchestrator (dead)","%s","%s","%s","lease %s, reclaimable","%s"\n' \
          "$LEASE_HOLDER" "$LEASE_MACHINE" "$LEASE_SCOPE" "$LEASE_HANDS" "$LEASE_N" "$LEASE_WHY"
      fi
    done <"$table"
  fi
  if arm_lease_live_for "$state" crown "$machine"; then
    printf '  "%s","the crown","%s","the fleet","%s","lease %s","heartbeat %ss"\n' \
      "$LEASE_HOLDER" "$machine" "$LEASE_HANDS" "$LEASE_N" "$LEASE_AGE"
  else
    printf '  "nobody","the crown","%s","the fleet","-","vacant","no crown row on this machine"\n' "$machine"
  fi
  return 0
}
