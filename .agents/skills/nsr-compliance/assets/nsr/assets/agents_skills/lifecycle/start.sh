#!/usr/bin/env bash
# WIRE ME — start lifecycle. Bind this to your app's real boot command.
#
# Replace this stub with your stack's boot command, e.g.:
#   Elixir/Phoenix:  exec mix phx.server
#   Node:            exec npm run dev            (APP_ENV=prod -> npm run start)
#   Python/Django:   exec python manage.py runserver 0.0.0.0:"${PORT:-8000}"
#   Wrapper:         existing scripts/.../start*.sh delegated + guard
#
# Wrapping an existing procedure never rewrites it:
#   [ "${APP_ENV:-development}" != "prod" ] || { scripts/cloudflare/startprod.sh; exit $?; }
#   exec scripts/cloudflare/startdev.sh
#
# After wiring, prove it: .compliance/gates/check_wiring.sh --strict
set -e
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"
echo "[lifecycle/start] WIRE ME: replace this stub with the app's real boot command (env=${APP_ENV:-development})"
exit 1