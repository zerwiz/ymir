#!/usr/bin/env bash
# units.sh — the ONE writer of every Ymir systemd user unit and desktop launcher (plan 269).
#
#   bin/engine/units.sh list [--names|--restart]   the register, and every app under apps/
#   bin/engine/units.sh check                      exit 1 when a Ymir unit or launcher is off the pin
#                                                  or not in config/units.yaml
#   bin/engine/units.sh drift                      exit 1 when an installed unit still runs a value its
#                                                  source retired (config/units.yaml `retired:`, plan 278)
#   bin/engine/units.sh write [name…] [--set K=V] [--dry-run] [--no-restart] [--render]
#                                                  render and retarget everything against the pinned
#                                                  runtime; write only what changed; daemon-reload;
#                                                  log every old line it replaced
#
# The register is config/units.yaml. The root is the pinned runtime (~/ymir-runtime by default,
# YMIR_RUNTIME_DIR in <home>/config/runtime.env). Every installer that used to write its own unit
# calls this instead, so a service can never run from the tree it was installed from.
#
# Test seams (never real units): YMIR_UNIT_DIR, YMIR_APPLICATIONS_DIR, YMIR_AUTOSTART_DIR,
# YMIR_UNITS_NO_SYSTEMCTL=1, YMIR_UNITS_ROLES, YMIR_UNITS_NO_ROLE_PROBE=1.
set -uo pipefail
HERE="$(CDPATH='' cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "${1:-}" in
  -h|--help|"") sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
command -v python3 >/dev/null 2>&1 || { printf 'error: python3 is required by units.sh\n' >&2; exit 2; }
exec python3 -I "$HERE/units.py" "$@"
