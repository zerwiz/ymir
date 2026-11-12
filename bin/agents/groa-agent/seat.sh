#!/usr/bin/env bash
# seat.sh — seat Gróa on THIS machine, once. Idempotent: one Gróa per install.
#
# Called by bin/engine/ymir-install.sh (step_groa) and re-run after every update by
# bin/agents/groa-update.sh, so her body always matches the tree it lives in.
#
#   bash bin/agents/groa-agent/seat.sh [--repo PATH] [--auth PATH] [--minute MM]
#
# - installs OpenCode (npm -g opencode-ai) if it is absent
# - copies the OpenCode auth file from --auth if given (0600, never committed)
# - writes ~/.local/bin/groa-agent.sh (the leash: start|stop|status|tick|check)
# - installs groa-agent.timer (systemd --user, daily, staggered)
# - runs one `check` to prove the leash works
set -euo pipefail
QUIET=0
for a in "$@"; do [ "$a" = "--quiet" ] && QUIET=1; done

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# plan 275 S8b: Gróa runs from the pin (what the icons and units run), never a working tree
REPO="${YMIR_REPO:-}"
[ -n "$REPO" ] || { [ -d "${YMIR_RUNTIME_DIR:-$HOME/ymir-runtime}/.git" ] && REPO="${YMIR_RUNTIME_DIR:-$HOME/ymir-runtime}"; }
[ -n "$REPO" ] || REPO="$HOME/ymir"
MODE="${GROA_MODE:-script}"
AUTH_SRC="${OC_AUTH_SRC:-}"
MINUTE="${GROA_MINUTE:-}"

while [ $# -gt 0 ]; do case "$1" in
  --repo) REPO="${2-}"; shift 2 ;;
  --auth) AUTH_SRC="${2-}"; shift 2 ;;
  --minute) MINUTE="${2-}"; shift 2 ;;
  --quiet) QUIET=1; shift ;;
  *) echo "unknown option: $1" >&2; exit 2 ;;
esac; done

[ -d "$REPO/.git" ] || { echo "no Ymir checkout at $REPO" >&2; exit 1; }

# stagger per host so installs never update at the same minute
if [ -z "$MINUTE" ]; then
  case "$(hostname -s)" in
    heimdall) MINUTE=10 ;;
    omarchy) MINUTE=14 ;;
    whynot) MINUTE=18 ;;
    zerwizserver) MINUTE=22 ;;
    *) MINUTE=26 ;;
  esac
fi

# 1. OpenCode
if [ "$MODE" = agent ] && ! command -v opencode >/dev/null 2>&1; then
  echo "installing opencode…"
  if ! npm i -g opencode-ai </dev/null >/dev/null 2>&1; then
    # never block on a password prompt — sudo hangs pi when there is no tty.
    if sudo -n true 2>/dev/null; then
      sudo -n npm i -g opencode-ai </dev/null >/dev/null 2>&1 || { echo "could not install opencode" >&2; exit 1; }
    else
      echo "opencode install needs a password — run: npm i -g opencode-ai (user prefix) or sudo npm i -g opencode-ai" >&2
      exit 1
    fi
  fi
fi
[ "$MODE" != agent ] || command -v opencode >/dev/null || { echo "opencode still absent" >&2; exit 1; }

# 2. auth
if [ -n "$AUTH_SRC" ] && [ -r "$AUTH_SRC" ]; then
  mkdir -p "$HOME/.local/share/opencode"
  install -m 600 "$AUTH_SRC" "$HOME/.local/share/opencode/auth.json"
  echo "auth installed"
fi

# 3. the runner
mkdir -p "$HOME/.local/bin"
install -m 755 "$HERE/groa-agent.sh" "$HOME/.local/bin/groa-agent.sh"
mkdir -p "$HOME/.local/share/groa-agent"
install -m 644 "$HERE/prompt.md" "$HOME/.local/share/groa-agent/prompt.md"
mkdir -p "$HOME/.config/systemd/user"

# 4. the timer
cat > "$HOME/.config/systemd/user/groa-agent.service" <<EOF
[Unit]
Description=Gróa — the updater, one per install (runs groa-update.sh; GROA_MODE=$MODE)

[Service]
Type=oneshot
Environment=YMIR_REPO=$REPO
Environment=GROA_MODE=$MODE
TimeoutStartSec=3600
ExecStart=%h/.local/bin/groa-agent.sh tick
Nice=10
EOF

cat > "$HOME/.config/systemd/user/groa-agent.timer" <<EOF
[Unit]
Description=Wake Gróa daily

[Timer]
OnCalendar=*-*-* 04:$MINUTE:00
Persistent=true
RandomizedDelaySec=120

[Install]
WantedBy=timers.target
EOF

# plan 272, fault 12: the register settles the unit onto the pin before the manager reads it
if [ -r "$HERE/../../engine/unit-settle-lib.sh" ]; then . "$HERE/../../engine/unit-settle-lib.sh"; unit_settle groa-agent || true; fi
systemctl --user daemon-reload
systemctl --user enable --now groa-agent.timer
echo "timer: daily 04:$MINUTE"
systemctl --user list-timers groa-agent.timer --no-pager | head -3

# 5. prove the leash
[ "$QUIET" = 1 ] || echo "proving the leash (check only, no changes)…"
[ "$QUIET" = 1 ] || YMIR_REPO="$REPO" timeout 900 "$HOME/.local/bin/groa-agent.sh" check || true
