#!/usr/bin/env bash
# local-model-lock.sh — serialize LOCAL model inference on one machine.
#
# Most machines cannot run several local models at once. This runs a command
# under an exclusive lock so only one local inference is active per host (a
# second invocation waits). Different machines are independent; a big box may
# allow more via `local_concurrency` in config/agents.yaml.
#
#   bin/local-model-lock.sh <command...>     # run a command under the lock
#   bin/local-model-lock.sh check            # is a local-model slot free?
#
# `check` is for the SEAT roads. A herdr seat is long-lived, so wrapping it in
# `flock` is awkward; instead the seat asks whether a slot is free and refuses
# when the host is at capacity. Exit 0 free, 3 busy (a local seat already runs).
#
#   local_concurrency: 1        # in config/agents.yaml (default 1)
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# The operator's settings and secrets live in the home they chose, never in the
# code tree — a packaged install replaces its tree on upgrade, and a credential
# must never sit in a tree that ships (Rule 04).
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _yr="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _yc in "$_yr/hoard-lib.sh" "$(dirname "$_yr")/bin/hoard-lib.sh"; do
    [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yr _yc
fi
hoard_settings_dir YMIR_SETTINGS_DIR
hoard_local_env YMIR_ENV_FILE
hoard_state_dir YMIR_STATE_DIR
hoard_data_dir YMIR_DATA_DIR

# The roots that live OUTSIDE the code tree: this machine's records and the
# runtime state belong to the home the operator chose at installation, never in
# the tree — a packaged install replaces its tree on upgrade (Rule 04).
CFG="${YMIR_AGENTS_YAML:-$YMIR_SETTINGS_DIR/agents.yaml}"
LOCK="$YMIR_STATE_DIR/local-model.lock"
WAIT="${LOCAL_MODEL_WAIT:-1800}"

[ $# -gt 0 ] || { printf 'error: usage: bin/local-model-lock.sh <command...> | check\n' >&2; exit 2; }

# check — how many seats are inferring locally right now, and is there room?
if [ "$1" = "check" ]; then
  N0="$(python3 - "$CFG" <<'PY' 2>/dev/null || echo 1
import sys
try:
    import yaml
except Exception:
    print(1); raise SystemExit
d = yaml.safe_load(open(sys.argv[1])) or {}
v = d.get("local_concurrency", 1)
print(int(v) if str(v).isdigit() else 1)
PY
)"
  [ -n "$N0" ] || N0=1
  # A seat is "local" when its pane shows a local provider marker. Two traps,
  # both found live 2026-09-23: `herdr agent read --lines N` returns EMPTY (the
  # option is not honoured), and the marker sits at the far right of the status
  # line where a narrow pane can truncate it. So: read the WHOLE pane, and match
  # the provider name anywhere in it. Verified — a seat on llama-swap yields two
  # matches in the full read.
  busy=0
  holders=""
  if command -v herdr >/dev/null 2>&1; then
    for a in $(herdr agent list 2>/dev/null | python3 -c '
import json,sys
try:
    for x in json.load(sys.stdin)["result"]["agents"]: print(x.get("name",""))
except Exception: pass' 2>/dev/null); do
      [ -n "$a" ] || continue
      if herdr agent read "$a" 2>/dev/null | grep -qE '\((llama-swap|llamacpp-whynot|llama\.cpp|lmstudio)\)'; then
        busy=$((busy + 1))
        [ -n "$holders" ] && holders="$holders,"
        holders="$holders$a"
      fi
    done
  fi
  if [ "$busy" -lt "$N0" ]; then
    printf 'local-model-lock[1]{check,slots,used,state}:\n  "free",%s,%s,"go"\n' "$N0" "$busy"
    exit 0
  fi
  printf 'local-model-lock[1]{check,slots,used,state}:\n  "busy",%s,%s,"a local seat already runs — wait, or use a remote/online model"\n' "$N0" "$busy"
  [ -n "$holders" ] && printf '"%s"\n' "$holders"
  exit 3
fi

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

mkdir -p "$YMIR_STATE_DIR"

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
