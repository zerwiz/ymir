#!/usr/bin/env bash
# fleet-deploy.sh — refresh the machine's fleet services from THIS package.
#
# Why this exists: `npm install -g @zerwiz/ymir` updates the package under
# node_modules, but a running service executes a copy under `~/.fleet/` (see
# bin/fleet-ensure.sh). So an install left the LIVE server stale — the ticket
# hall kept running the old code until someone re-ran the deployer by hand
# (2026-09-23: a `rows(q(...))` bug survived an install for exactly this reason).
# This is the postinstall step: copy the tools from the package and, where the
# unit is already installed, restart it. Best-effort — it never fails an install.
#
#   fleet-deploy.sh            # copy tools -> ~/.fleet, restart installed units
#   fleet-deploy.sh --dry-run  # report what would change; copy nothing
#   fleet-deploy.sh --version
#
# Rule 10: every server runs from a file the repo owns and is deployed from it.
set -u

VERSION="1.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
DRY=0
[ "${1-}" = "--dry-run" ] && DRY=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
DST="${YMIR_FLEET_DIR:-$HOME/.fleet}"

# tool file in the package -> deployed name under ~/.fleet
TOOLS=(
  "tools/well-mcp/server.ts:well-mcp-server.ts"
  "tools/ratatoskr-node/server.ts:ratatoskr-server.ts"
  "tools/mill/worker.sh:mill-worker.sh"
  "tools/skills-mcp/server.mjs:skills-mcp-server.mjs"
  "tools/tickets-mcp/server.mjs:tickets-mcp-server.mjs"
)
# unit -> the unit name systemd knows
UNITS=( "well-mcp" "ratatoskr" "mill-worker" "cards" "skuld" )

[ -d "$DST" ] || { printf 'fleet-deploy: no %s on this machine — nothing to refresh\n' "$DST"; exit 0; }
[ "$DRY" = 1 ] || mkdir -p "$DST"

changed=0
for pair in "${TOOLS[@]}"; do
  src="${pair%%:*}"; name="${pair#*:}"
  [ -r "$ROOT/$src" ] || continue
  if [ -r "$DST/$name" ] && cmp -s "$ROOT/$src" "$DST/$name"; then continue; fi
  if [ "$DRY" = 1 ]; then
    printf 'fleet-deploy: would refresh %s\n' "$name"
  else
    cp -f "$ROOT/$src" "$DST/$name" 2>/dev/null || continue
    printf 'fleet-deploy: refreshed %s\n' "$name"
  fi
  changed=$((changed + 1))
done

# restart the units that are actually installed and running (try-restart: a
# stopped unit is left alone; a running one picks up the new code)
if command -v systemctl >/dev/null 2>&1 && [ -d "$HOME/.config/systemd/user" ]; then
  [ "$DRY" = 1 ] || systemctl --user daemon-reload >/dev/null 2>&1 || true
  for u in "${UNITS[@]}"; do
    [ -f "$HOME/.config/systemd/user/$u.service" ] || continue
    if [ "$DRY" = 1 ]; then printf 'fleet-deploy: would try-restart %s\n' "$u"; continue; fi
    if systemctl --user try-restart "$u" >/dev/null 2>&1; then printf 'fleet-deploy: %s restarted\n' "$u"; fi
  done
fi

# desktop launcher entries + Hyprland placement — the four/five apps in the menu.
# An install must refresh these too: the entries outlive the tree that wrote them,
# and a stale or missing one (Smiðja was deleted by a stray line) is invisible until
# an operator looks at the menu. Best-effort and host-gated; opt out with
# YMIR_SKIP_DESKTOP=1.
if [ "${YMIR_SKIP_DESKTOP:-0}" != 1 ] && [ -d "$HOME/.local/share/applications" ]; then
  if [ "$DRY" = 1 ]; then
    printf 'fleet-deploy: would refresh desktop entries (design-icon install) + placement\n'
  else
    [ -x "$ROOT/bin/design-icon.sh" ] && bash "$ROOT/bin/design-icon.sh" install >/dev/null 2>&1 || true
    [ -x "$ROOT/bin/desktop-place.sh" ] && bash "$ROOT/bin/desktop-place.sh" apply >/dev/null 2>&1 || true
    printf 'fleet-deploy: desktop entries refreshed\n'
  fi
fi

printf 'fleet-deploy: %s file(s) refreshed\n' "$changed"
exit 0
