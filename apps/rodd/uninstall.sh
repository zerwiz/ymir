#!/usr/bin/env bash
# uninstall.sh — take the window's launcher entry and unit away. Ymir's voice, the arm and the helm are the house's
# and are never touched; neither is the window's state.
set -euo pipefail
data="${XDG_DATA_HOME:-$HOME/.local/share}"; units="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
systemctl --user stop ymir-rodd.service >/dev/null 2>&1 || true
rm -f "$data/applications/rodd.desktop" "$units/ymir-rodd.service"
systemctl --user daemon-reload >/dev/null 2>&1 || true
printf 'rodd: launcher entry and unit removed\n'
