#!/usr/bin/env bash
# ymir-config-check.sh — the DOOR to the config layer (`src/ymir_runtime/config/`).
#
# Plan 58, Phase 7. Every config the runtime reads is validated against a JSON
# Schema before a value is trusted; a shape fault is a loud refusal that names the
# key and the file. This door is how a shell reaches that check without a second
# interface:
#
#   ymir-config-check.sh examples              # validate the shipped *.example shapes
#   ymir-config-check.sh validate <file>...    # validate named configs
#   ymir-config-check.sh kinds                 # the registered config kinds
#   ymir-config-check.sh --host <name> validate <fleet.json>
#
# Interpreters: the engine's private venv ($YMIR_ENGINE_VENV, built by
# bin/ymir-engine-ensure.sh) when it exists, else the system python3. The config
# layer needs `jsonschema`; when it is absent this door refuses (exit 3) rather
# than returning an unvalidated config — run `bin/ymir-engine-ensure.sh ensure`.
#
# Exit: 0 every config valid · 1 a config refused · 2 usage · 3 a dependency missing.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VENV="${YMIR_ENGINE_VENV:-$HOME/.fleet/ymir-engine-venv}"

case "${1-}" in
  -h|--help|"") sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

[ -d "$ROOT/src/ymir_runtime/config" ] || {
  printf 'error: the config layer is missing at %s/src/ymir_runtime/config\nhelp: this tree predates plan 58 Phase 7 — update it\n' "$ROOT" >&2
  exit 1
}

PY="${YMIR_ENGINE_PYTHON:-}"
if [ -z "$PY" ] && [ -x "$VENV/bin/python" ]; then PY="$VENV/bin/python"; fi
if [ -z "$PY" ]; then PY="$(command -v python3 2>/dev/null || true)"; fi
[ -n "$PY" ] || { printf 'error: no python3 — the config layer cannot run\nhelp: bin/prereq-ensure.sh\n' >&2; exit 1; }

export PYTHONPATH="$ROOT/src${PYTHONPATH:+:$PYTHONPATH}"
export YMIR_ENGINE_ROOT="$ROOT"
exec "$PY" -m ymir_runtime.config "$@"
