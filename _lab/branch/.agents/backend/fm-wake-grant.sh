#!/usr/bin/env bash
# fm-wake-grant.sh — the vendored firstmate NAME, now a thin adapter over the ONE
# door (plan 58, Phase 5: one name, one behaviour).
#
# This file defines no behaviour of its own. It maps the upstream dialect onto
# `bin/time/brokk-wake-grant.sh` and hands the verb over with `exec`, so the vendored
# callers in this folder keep resolving while the implementation lives in exactly
# one place. A body added here would be the second implementation this file
# exists to remove.
set -u

_ymir_backend_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_ymir_repo="$(cd "$_ymir_backend_dir/../.." && pwd)"

# The upstream caller's own word is final: an FM_* value the island set is the
# caller's dialect for that value, and it wins over anything ambient.
[ -z "${FM_HOME+x}" ] || export BROKK_HOME="$FM_HOME"
[ -z "${FM_ROOT+x}" ] || export BROKK_ROOT="$FM_ROOT"
[ -z "${FM_ROOT_OVERRIDE+x}" ] || export BROKK_ROOT_OVERRIDE="$FM_ROOT_OVERRIDE"
[ -z "${FM_STATE_OVERRIDE+x}" ] || export BROKK_STATE_OVERRIDE="$FM_STATE_OVERRIDE"
[ -z "${FM_WAKE_QUEUE+x}" ] || export BROKK_WAKE_QUEUE="$FM_WAKE_QUEUE"
[ -z "${FM_WAKE_QUEUE_LOCK+x}" ] || export BROKK_WAKE_QUEUE_LOCK="$FM_WAKE_QUEUE_LOCK"

exec "$_ymir_repo/bin/time/brokk-wake-grant.sh" "$@"
