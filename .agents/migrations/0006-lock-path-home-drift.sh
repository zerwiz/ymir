#!/usr/bin/env bash
# 0006-lock-path-home-drift — heal a session-lock pointer that names another
# machine's home.
#
# `state/.lock-path` records the resolved session-lock path. The lock itself is
# machine-global, but the pointer lives in the synced home — so a box reinstalled
# under a new username (heimdallomarchy -> heimdall) inherits a pointer to the OLD
# home. The harness readers trusted it blindly, and the arm then tried to mkdir a
# foreign home it cannot own, failing with EACCES and stranding supervision
# (2026-09-23). This migration re-derives the pointer for THIS machine.
#
# Idempotent: safe to run repeatedly.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# shellcheck source=bin/gleipnir-lock-lib.sh
. "$ROOT/bin/gleipnir-lock-lib.sh"

gleipnir_lock_path want
gleipnir_lock_pointer_path pointer

if [ ! -e "$pointer" ]; then
  echo "0006-lock-path-home-drift: no pointer to heal"
  exit 0
fi

recorded="$(head -n1 "$pointer" 2>/dev/null | tr -d '[:space:]')"
if [ -z "$recorded" ]; then
  echo "0006-lock-path-home-drift: pointer is empty"
  exit 0
fi

# A path under the current user's home is this machine's own; leave it.
if [ -n "${HOME:-}" ] && { [ "$recorded" = "$HOME" ] || [ "${recorded#"$HOME"/}" != "$recorded" ]; }; then
  echo "0006-lock-path-home-drift: pointer already under \$HOME"
  exit 0
fi

if [ "$recorded" = "$want" ]; then
  echo "0006-lock-path-home-drift: pointer already current"
  exit 0
fi

mkdir -p "$(dirname "$pointer")" 2>/dev/null || true
printf '%s\n' "$want" >"$pointer" 2>/dev/null || true
printf '0006-lock-path-home-drift: healed %s -> %s\n' "$recorded" "$want"
echo "0006-lock-path-home-drift: done"
