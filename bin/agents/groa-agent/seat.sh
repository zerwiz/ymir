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
# - installs groa-agent.timer (systemd --user, daily, staggered) and eir-night.service, which Gróa's unit
#   starts after it on success and on failure (plan 350 C); on macOS one launch agent runs both in turn;
#   with no user service manager it says so and skips (RULES/05)
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

# Stagger per host so installs never update at the same minute. The minute is DERIVED from the
# host's own name (a stable hash, never a table of our machines): a list here named this fleet in a
# public repository and left every other operator's fleet on the same fallback minute (Rule 07).
if [ -z "$MINUTE" ]; then
  # A per-machine minute, OFF the hour, never a machine named in this file (RULES/04): the host name
  # is hashed to one of five minutes, so two seats sharing a clock do not start together.
  MINUTE=$(( 10 + 4 * ( $(printf '%s' "$(hostname -s)" | cksum | cut -d' ' -f1) % 5 ) ))
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

# 3. the runners: Gróa's leash, and Eir's night (plan 350 C: Eir runs after Gróa, every night)
mkdir -p "$HOME/.local/bin"
install -m 755 "$HERE/groa-agent.sh" "$HOME/.local/bin/groa-agent.sh"
install -m 755 "$HERE/eir-night.sh" "$HOME/.local/bin/eir-night.sh"
mkdir -p "$HOME/.local/share/groa-agent"
install -m 644 "$HERE/prompt.md" "$HOME/.local/share/groa-agent/prompt.md"

# 4. the nightly pair, on THIS platform's user service manager (RULES/05: every layer, a clean skip elsewhere).
#    Never root: YMIR_NO_SUDO=1 rides in every unit, so a step that needs root is skipped and named.
UNIT_DIR="${SEAT_UNIT_DIR:-$HOME/.config/systemd/user}"
LAUNCHD_DIR="${SEAT_LAUNCHD_DIR:-$HOME/Library/LaunchAgents}"
PLATFORM="${SEAT_PLATFORM:-}"
if [ -z "$PLATFORM" ]; then
  if [ "$(uname -s)" = Darwin ]; then PLATFORM=launchd
  elif command -v systemctl >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1; then PLATFORM=systemd
  else PLATFORM=none; fi
fi
case "$PLATFORM" in
systemd)
mkdir -p "$UNIT_DIR"
# Gróa's exit 4 means "updated, surfaces owed" — the very night Eir is for — so it is a success here, and Eir
# is started after Gróa on success AND on failure (a failed Gróa is still a night Eir must report).
cat > "$UNIT_DIR/groa-agent.service" <<EOF
[Unit]
Description=Gróa — the updater, one per install (runs groa-update.sh; GROA_MODE=$MODE)
OnSuccess=eir-night.service
OnFailure=eir-night.service

[Service]
Type=oneshot
Environment=YMIR_REPO=$REPO
Environment=GROA_MODE=$MODE
Environment=YMIR_NO_SUDO=1
SuccessExitStatus=4
TimeoutStartSec=3600
ExecStart=%h/.local/bin/groa-agent.sh tick
Nice=10
EOF

cat > "$UNIT_DIR/eir-night.service" <<EOF
[Unit]
Description=Eir — the healer, after Gróa every night (check, mend what is safe, renew the apps, tell the arm)

[Service]
Type=oneshot
Environment=YMIR_REPO=$REPO
Environment=YMIR_NO_SUDO=1
TimeoutStartSec=2700
ExecStart=%h/.local/bin/eir-night.sh
Nice=10
EOF

cat > "$UNIT_DIR/groa-agent.timer" <<EOF
[Unit]
Description=Wake Gróa daily

[Timer]
OnCalendar=*-*-* 04:$MINUTE:00
Persistent=true
RandomizedDelaySec=120

[Install]
WantedBy=timers.target
EOF

if [ -z "${SEAT_UNIT_DIR:-}" ]; then
  # plan 272, fault 12: the register settles the unit onto the pin before the manager reads it
  if [ -r "$HERE/../../engine/unit-settle-lib.sh" ]; then . "$HERE/../../engine/unit-settle-lib.sh"; unit_settle groa-agent || true; fi
  systemctl --user daemon-reload
  systemctl --user enable --now groa-agent.timer
  systemctl --user list-timers groa-agent.timer --no-pager | head -3
fi
echo "timer: daily 04:$MINUTE, then Eir (eir-night.service)"
;;
launchd)
mkdir -p "$LAUNCHD_DIR"
cat > "$LAUNCHD_DIR/org.ymir.renewal.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>org.ymir.renewal</string>
  <key>ProgramArguments</key>
  <array><string>/bin/bash</string><string>-c</string><string>\$HOME/.local/bin/groa-agent.sh tick; \$HOME/.local/bin/eir-night.sh</string></array>
  <key>EnvironmentVariables</key>
  <dict><key>YMIR_REPO</key><string>$REPO</string><key>GROA_MODE</key><string>$MODE</string><key>YMIR_NO_SUDO</key><string>1</string></dict>
  <key>StartCalendarInterval</key><dict><key>Hour</key><integer>4</integer><key>Minute</key><integer>$((10#$MINUTE))</integer></dict>
  <key>StandardOutPath</key><string>/tmp/ymir-renewal.log</string>
  <key>StandardErrorPath</key><string>/tmp/ymir-renewal.log</string>
</dict>
</plist>
EOF
if [ -z "${SEAT_LAUNCHD_DIR:-}" ]; then
  launchctl unload "$LAUNCHD_DIR/org.ymir.renewal.plist" >/dev/null 2>&1 || true
  launchctl load "$LAUNCHD_DIR/org.ymir.renewal.plist" || echo "launchctl did not load the renewal agent" >&2
fi
echo "launch agent: daily 04:$MINUTE, Gróa then Eir (org.ymir.renewal)"
;;
*)
echo "skip: no user service manager on this machine (systemd --user or launchd) — the nightly pair cannot be seated; run bin/agents/groa-update.sh and bin/agents/eir-doctor.sh by hand"
exit 0
;;
esac

# 5. prove the leash
[ "$QUIET" = 1 ] || echo "proving the leash (check only, no changes)…"
[ "$QUIET" = 1 ] || [ -n "${SEAT_UNIT_DIR:-}${SEAT_LAUNCHD_DIR:-}" ] || YMIR_REPO="$REPO" timeout 900 "$HOME/.local/bin/groa-agent.sh" check || true
