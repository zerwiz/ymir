#!/usr/bin/env bash
# fm-timeout-lib.sh — the vendored firstmate NAME, now a thin adapter over the
# ONE library (plan 58, Phase 5: one name, one behaviour). This file defines no
# behaviour: it maps the upstream dialect onto `bin/agents/brokk-timeout-lib.sh` and
# sources it, so the vendored callers in this folder keep resolving while the
# implementation lives in exactly one place. A change that adds behaviour here
# is a second implementation — the thing this file exists to end.

_ymir_backend_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_ymir_repo="$(cd "$_ymir_backend_dir/../.." && pwd)"

_ymir_bridge() {  # <upstream-var> <native-var>
  local _ymir_src=$1 _ymir_dst=$2 _ymir_val=
  # shellcheck disable=SC2294  # the source name is a literal passed by this file
  eval "_ymir_val=\${$_ymir_src-}"
  [ -n "$_ymir_val" ] || return 0
  printf -v "$_ymir_dst" '%s' "$_ymir_val"
}
_ymir_bridge FM_TIMEOUT_MECHANISM_OVERRIDE BROKK_TIMEOUT_MECHANISM_OVERRIDE
unset -f _ymir_bridge

# shellcheck source=bin/agents/brokk-timeout-lib.sh
. "$_ymir_repo/bin/agents/brokk-timeout-lib.sh"
unset _ymir_backend_dir _ymir_repo
