#!/usr/bin/env bash
# hermes-session-hook.sh — a one-line launcher: Hermes' session side (the Sága digest on the first turn, in any cwd)
# is src/ymir_runtime/hermes/session_hook.py (plan 177 H4, plan 317 slice 7). Installed by: bin/pi/arm.sh hook hermes --install
exec env PYTHONPATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/src${PYTHONPATH:+:$PYTHONPATH}" python3 -m ymir_runtime.hermes session-hook
