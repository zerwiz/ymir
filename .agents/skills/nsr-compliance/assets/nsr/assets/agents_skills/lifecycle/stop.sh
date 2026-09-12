#!/usr/bin/env bash
# WIRE ME — stop lifecycle. Graceful shutdown. Never force-kill processes.
#
# Replace with your stack's graceful shutdown, e.g.:
#   docker:    exec docker compose down
#   systemd:   systemctl stop <service>
#   wrapper:   existing scripts/.../stop*.sh delegated + guard
#
# Tip: keep a pidfile at runtime (write $! in start.sh) so stop.sh can
# terminate exactly the process the compliance started.
set -e
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"
echo "[lifecycle/stop] WIRE ME: replace this stub with the app's graceful shutdown"
exit 1
