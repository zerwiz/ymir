#!/usr/bin/env bash
# trouble.sh — the trouble panel: the house says it is in trouble before it is asked (plan 339.5).
#
#   bin/ward/trouble.sh [read] [--json] [--only disk,guardian,…]   this machine's reading
#   bin/ward/trouble.sh check [--notify] [--dry-run] [--only …]   keep the reading; a notice per turn to red, retried until sent
#   bin/ward/trouble.sh fleet [--json]                             a row per machine in fleet.json (every role), each
#                                                                  read on that machine over its fleet road
#   bin/ward/trouble.sh --version
#
# Nine signals: disk · guardian · pin · unpushed · questions · errands · hyprland · tells · loops.
# What each one means, its line and the variable that moves it are in bin/ward/trouble.py's header and
# docs/features/the-trouble-panel.md. Lines are counsel until the Allfather seals them (plan 339): set
# them in <home>/config/trouble.env (TROUBLE_DISK_PCT=85 …), never in this file.
#
# The notice road is bin/notify/send.sh (HIGH: the arm, the desk, Telegram with buttons). A signal that
# stays red is not said twice; one that turns green and red again is news again.
#
# Exit: 0 no signal red · 1 a signal is red · 2 usage.
set -u
VERSION="1.0.0"
SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${SCRIPT_DIR%/bin/ward}"
case "${1:-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
# shellcheck disable=SC1091
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
HOME_R="${YMIR_HOME:-}"
[ -n "$HOME_R" ] || ymir_home_root HOME_R 2>/dev/null || true
[ -n "${HOME_R:-}" ] || { printf 'error: the home is unresolved\nhelp: set YMIR_HOME, or run bin/engine/ymir-install.sh\n' >&2; exit 1; }
STATE_R="${YMIR_STATE_DIR:-}"
if [ -z "$STATE_R" ] && declare -f hoard_state_dir >/dev/null 2>&1; then hoard_state_dir STATE_R 2>/dev/null || true; fi
[ -n "${STATE_R:-}" ] || STATE_R="$HOME_R/state"
# the operator's own lines (Rule 07): sourced env files in the home, never a value in this tree
for _env in "$HOME_R/config/runtime.env" "$HOME_R/config/trouble.env"; do
  if [ -r "$_env" ]; then set -a; . "$_env"; set +a; fi
done
exec python3 "$SCRIPT_DIR/trouble.py" "$ROOT" "$HOME_R" "$STATE_R" "$@"
