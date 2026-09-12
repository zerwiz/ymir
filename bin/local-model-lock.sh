#!/usr/bin/env bash
# local-model-lock.sh — serialize LOCAL model inference on one machine.
#
# Most machines cannot run several local models at once. This runs a command
# under an exclusive lock so only one local inference is active per host (a
# second invocation waits). Different machines are independent; a big box may
# allow more via `local_concurrency` in config/agents.yaml.
#
#   bin/local-model-lock.sh <command...>
#   local_concurrency: 1        # in config/agents.yaml (default 1)
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CFG="${YMIR_AGENTS_YAML:-$ROOT/config/agents.yaml}"
LOCK="$ROOT/state/local-model.lock"
WAIT="${LOCAL_MODEL_WAIT:-1800}"

[ $# -gt 0 ] || { printf 'error: usage: bin/local-model-lock.sh <command...>\n' >&2; exit 2; }

# How many local models this host may run at once (default 1).
N="$(python3 - "$CFG" <<'PY' 2>/dev/null || echo 1
import sys, yaml
try:
    d = yaml.safe_load(open(sys.argv[1])) or {}
    v = d.get("local_concurrency", 1)
    print(int(v) if str(v).isdigit() else 1)
except Exception:
    print(1)
PY
)"
[ -n "$N" ] || N=1

mkdir -p "$ROOT/state"

if [ "$N" -le 1 ]; then
  # one at a time — exclusive lock, wait for the peer to finish
  command -v flock >/dev/null 2>&1 || { printf 'local-model-lock: flock missing; running unlocked\n' >&2; exec "$@"; }
  echo "local-model-lock: acquired (concurrency=1)" >&2
  exec flock -w "$WAIT" "$LOCK" "$@"
else
  # a big host: N slots — take the first free lock in the pool
  command -v flock >/dev/null 2>&1 || exec "$@"
  for i in $(seq 1 "$N"); do
    if flock -n "$LOCK.$i" -c "true" 2>/dev/null; then
      exec flock -w "$WAIT" "$LOCK.$i" "$@"
    fi
  done
  echo "local-model-lock: all $N slots busy; waiting on slot 1" >&2
  exec flock -w "$WAIT" "$LOCK.1" "$@"
fi
