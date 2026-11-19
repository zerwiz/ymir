#!/usr/bin/env bash
# uninstall.sh — take the smithy's doors off PATH. Its trace, its config and Völundr's memory stay.
set -euo pipefail
for n in smidja smidja-mcp; do
  l="$HOME/.local/bin/$n"
  if [ -L "$l" ] && case "$(readlink "$l")" in */ymir-apps/smidja/*) true ;; *) false ;; esac; then rm "$l"; printf 'smidja: %s removed from PATH\n' "$n"; fi
done
printf 'smidja: the MCP entry stays in pi'"'"'s set until `bin/bridge/mcp-config.sh seat` is run without it\n'
