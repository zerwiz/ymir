#!/usr/bin/env bash
# fm-lease-lib.sh — the vendored firstmate NAME, now a thin adapter over the ONE
# library (plan 58, Phase 5: one name, one behaviour).
#
# This file defines no behaviour of its own. It maps the upstream dialect onto
# `bin/brokk-lease-lib.sh` and sources it, so the vendored callers in this
# folder keep resolving while the implementation lives in exactly one place. The
# lease contract's own variables are the native ones (`BROKK_LEASE_*`); the
# vendored door that read the old `FM_LEASE_*` names was repointed in the same
# change. A body added here would be the second implementation this file exists
# to remove.

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
for _ymir_v in HOME ROOT ROOT_OVERRIDE STATE_OVERRIDE \
               SUPERVISION_ACTOR SUPERVISION_MODEL \
               LEASE_ACTOR LEASE_HOLDER_PID LEASE_PID LEASE_EPOCH LEASE_REFUSE_EXIT; do
  _ymir_bridge "FM_$_ymir_v" "BROKK_$_ymir_v"
done
unset _ymir_v
unset -f _ymir_bridge

# shellcheck source=bin/brokk-lease-lib.sh
. "$_ymir_repo/bin/brokk-lease-lib.sh"
unset _ymir_backend_dir _ymir_repo
