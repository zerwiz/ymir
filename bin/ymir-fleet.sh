#!/usr/bin/env bash
# ymir-fleet.sh — FLEET MODE, one command for npm users. Raise (or report)
# this seat's fleet surfaces — the served well-MCP, the A2A node, the mill,
# the stone, the cards — and
# point your pi/opencode at the well.

set -u
case "${1-}" in
  -h|--help|"") sed -n '1,9p' "$0" | sed 's/^# \{0,1\}//' ;;
  status) bin/fleet-ensure.sh status ;;
  ensure|"")
    bin/fleet-ensure.sh ensure "${2:+--well-url $2}"
    echo "fleet mode: the well URL is the seat's mcp.json (well) — run 'pi' and your tools drink one store."
    ;;
  *) echo "error: ymir-fleet.sh [status|ensure [--well-url <url>]]" >&2; exit 2 ;;
esac
