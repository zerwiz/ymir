#!/usr/bin/env bash
# fm-wake-lib.sh — the vendored firstmate NAME, now a thin adapter over the ONE
# library (plan 58, Phase 5: one name, one behaviour).
#
# This file defines no behaviour of its own. It maps the upstream dialect onto
# `bin/brokk-wake-lib.sh`, sources it, and re-exports the upstream verb names as
# one-line aliases, so the vendored callers in this folder keep resolving while
# the implementation lives in exactly one place. A body added here would be the
# second implementation this file exists to remove.

_ymir_backend_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_ymir_repo="$(cd "$_ymir_backend_dir/../.." && pwd)"

# The upstream env dialect -> the one library's. A caller's native name wins.
# The upstream caller's own word is final: when the island set an FM_* name it
# is the caller's dialect for that value, and it wins over anything ambient.
_ymir_bridge() {  # <upstream-var> <native-var>
  local _ymir_src=$1 _ymir_dst=$2 _ymir_val=
  # shellcheck disable=SC2294  # the source name is a literal passed by this file
  eval "_ymir_val=\${$_ymir_src-}"
  [ -n "$_ymir_val" ] || return 0
  printf -v "$_ymir_dst" '%s' "$_ymir_val"
}
for _ymir_v in HOME ROOT ROOT_OVERRIDE STATE_OVERRIDE PROC_ROOT_OVERRIDE \
               SUPERVISION_ACTOR SUPERVISION_MODEL GUARD_GRACE LOCK_STALE_AFTER \
               WAKE_QUEUE WAKE_QUEUE_LOCK WAKE_ENRICH_TEST_DELAY WAKE_STATUS_KEY \
               WAKE_STATUS_HISTORICAL WAKE_UNREAD_LINES WAKE_EVENT_LINE \
               LEASE_ACTOR LEASE_HOLDER_PID LEASE_PID LEASE_EPOCH LEASE_REFUSE_EXIT \
               LEASE_GUARD_LOCK CREW_STATE_BIN PAUSE_RESURFACE_SECS STALE_ESCALATE_SECS \
               PENDING_REPLY_CORR_RE WORKTREE_WRITE_MAXDEPTH WORKTREE_WRITE_PRUNE \
               WORKTREE_WRITE_TIMEOUT OPEN_DECISIONS_READ_PROBE \
               OPEN_DECISIONS_FOLD_VERSION TIMEOUT_MECHANISM_OVERRIDE; do
  _ymir_bridge "FM_$_ymir_v" "BROKK_$_ymir_v"
done
unset _ymir_v
_ymir_bridge FM_CAPTAIN_RE BROKK_ALLFATHER_RE
_ymir_bridge FM_CLASSIFY_CAPTAIN_HELD_VERB BROKK_CLASSIFY_ALLFATHER_HELD_VERB
_ymir_bridge FM_CLASSIFY_CAPTAIN_RE_DEFAULT BROKK_CLASSIFY_ALLFATHER_RE_DEFAULT
_ymir_bridge FM_CLASSIFY_CAPTAIN_HELD_VERB_DEFAULT BROKK_CLASSIFY_ALLFATHER_HELD_VERB_DEFAULT
unset -f _ymir_bridge

# The island resolved its own home (root = its parent, `.agents/`) and never read
# the ambient BROKK_* names. Keep that resolution when the caller set no FM_
# location, so an island caller that passes nothing reads exactly where it read
# before the collapse; a caller that set an FM_ location has already won above.
if [ -z "${FM_ROOT_OVERRIDE+x}" ] && [ -z "${FM_ROOT+x}" ] \
   && [ -z "${FM_HOME+x}" ] && [ -z "${FM_STATE_OVERRIDE+x}" ]; then
  BROKK_ROOT_OVERRIDE=""
  BROKK_ROOT="$(cd "$_ymir_backend_dir/.." && pwd)"
  BROKK_HOME="$BROKK_ROOT"
  BROKK_STATE_OVERRIDE=""
fi

# shellcheck source=bin/brokk-wake-lib.sh
. "$_ymir_repo/bin/brokk-wake-lib.sh"
unset _ymir_backend_dir _ymir_repo

# The upstream callers that used the older verb names were repointed onto the
# one library's names in the same change; this file defines no verbs of its own.
