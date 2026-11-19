#!/usr/bin/env bash
# uninstall.sh — take the hall's launcher entry away. Its data home (the database, the agents, the engines,
# the desk, .env) is NEVER touched: it is the operator's, and outlives every release.
set -euo pipefail
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
desk="$DATA_HOME/applications/ymir-bilskirnir.desktop"
[ -f "$desk" ] && rm "$desk" && printf 'bilskirnir: launcher entry removed\n'
printf 'bilskirnir: the data home is kept (scripts/data-home.sh names it)\n'
