#!/usr/bin/env bash
# omarchy-hook-install.sh — let Ymir notice when Omarchy updates.
#
# Omarchy runs `~/.config/omarchy/hooks/post-update.d/*` after `omarchy update`
# applies packages and migrations. Installing our sensor there means Ymir learns
# the machine again the moment Omarchy moves — no polling, no cron.
#
# This writes only into ~/.config/omarchy/hooks/ (user config, per the Omarchy
# skill: never /usr/share/omarchy/).
#
# Usage:
#   bin/omarchy-hook-install.sh install|status|remove
#   bin/omarchy-hook-install.sh --version
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK_DIR="$HOME/.config/omarchy/hooks/post-update.d"
HOOK="$HOOK_DIR/ymir-omarchy-sense.sh"

is_omarchy() { [ -d /usr/share/omarchy ]; }
have() { command -v "$1" >/dev/null 2>&1; }

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

ACTION="${1:-status}"

case "$ACTION" in
  status)
    if [ -f "$HOOK" ]; then
      printf 'omarchy-hook[1]{hook,state}:\n  "%s","installed"\n' "$HOOK"
    else
      printf 'omarchy-hook[1]{hook,state}:\n  "%s","absent"\n' "$HOOK"
    fi
    ;;
  install)
    if ! is_omarchy; then
      printf 'omarchy-hook[1]{state,detail}:\n  "skipped","not an Omarchy host (/usr/share/omarchy absent)"\n'
      exit 0
    fi
    mkdir -p "$HOOK_DIR"
    cat >"$HOOK" <<EOF
#!/usr/bin/env bash
# Installed by Ymir (bin/omarchy-hook-install.sh). Re-learns the machine after
# an Omarchy update so the agent stays current with this user's setup.
exec "$ROOT/bin/omarchy-sense.sh" observe --quiet
EOF
    chmod +x "$HOOK"
    printf 'omarchy-hook[1]{hook,state}:\n  "%s","installed"\n' "$HOOK"
    ;;
  remove)
    rm -f "$HOOK"
    printf 'omarchy-hook[1]{hook,state}:\n  "%s","removed"\n' "$HOOK"
    ;;
  *) printf 'error: unknown action %s\nhelp: bin/omarchy-hook-install.sh [install|status|remove]\n' "$ACTION" >&2; exit 2 ;;
esac
