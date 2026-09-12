#!/usr/bin/env bash
# omarchy-install.sh — the Omarchy installation layer (Rule 05).
#
# Ymir is **Omarchy-first**: this is the first-class desktop layer. It owns
# everything that is true of Omarchy and not of the core — learning the host, the
# post-update hook, the suggested shell plugins, each app's numbered Hyprland
# desktop, the launcher entries, the editor's own desktop, the away-mode alarm
# channel, and the terminal backend Ymir needs.
#
# The core installer (bin/ymir-install.sh) is portable and runs on any platform;
# it calls THIS only when the host is Omarchy. Every step here therefore detects
# its host and reports a clean skip elsewhere — the layer is never assumed.
#
# Usage:
#   bin/omarchy-install.sh            # apply (idempotent)
#   bin/omarchy-install.sh --check    # report state only, change nothing
#   bin/omarchy-install.sh --list     # the steps, in order
#   bin/omarchy-install.sh --version
#
# Output: Galdr TOON. Exit 0 ok, 1 a step failed, 2 usage.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# portability shim (bin/ymir-platform.sh)
if [ -z "${YMIR_PLATFORM_LOADED:-}" ]; then
  _ymir_dir="$SCRIPT_DIR"
  for _ymir_c in "$_ymir_dir/ymir-platform.sh" "$(dirname "$_ymir_dir")/bin/ymir-platform.sh"; do
    [ -r "$_ymir_c" ] && { . "$_ymir_c"; YMIR_PLATFORM_LOADED=1; break; }
  done
  unset _ymir_dir _ymir_c
fi

CHECK=0
for a in "$@"; do
  case "$a" in
    --check)   CHECK=1 ;;
    --list)    printf 'omarchy-steps[7]{order,step,owns}:\n'
               printf '  1,"sense","learn the host: packages, configs, monitors, scale, Omarchy version"\n'
               printf '  2,"hook","re-learn after every `omarchy update` (post-update.d)"\n'
               printf '  3,"plugins","offer the shell plugins that render Ymir'"'"'s organs; never forced"\n'
               printf '  4,"desktops","one numbered Hyprland desktop per app + the launcher entries"\n'
               printf '  5,"editor","the editor opens on its own desktop"\n'
               printf '  6,"alarm","the away-mode alarm channel and the crash sensor"\n'
               printf '  7,"backend","the terminal backend Ymir needs (herdr 0.14+/0.8.0+, else tmux)"\n'
               exit 0 ;;
    --version|-v) printf '%s\n' "$VERSION"; exit 0 ;;
    -h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'error: unknown flag %s\nhelp: bin/omarchy-install.sh [--check|--list]\n' "$a" >&2; exit 2 ;;
  esac
done

declare -a T S D
add() { T+=("$1"); S+=("$2"); D+=("$3"); }
isfail=0

have() { command -v "$1" >/dev/null 2>&1; }
is_omarchy() { [ -d /usr/share/omarchy ] && return 0; [ "$(ymir_os 2>/dev/null)" = linux ] && [ -d "$HOME/.config/omarchy" ]; }

# ── the gate ─────────────────────────────────────────────────────────────────
if ! is_omarchy; then
  printf 'omarchy[1]{step,status,detail}:\n'
  printf '  "layer","SKIP","not an Omarchy host — the core runs without this layer"\n'
  exit 0
fi

run() {  # <step> <label> <cmd...>
  local step=$1 label=$2; shift 2
  if [ "$CHECK" = 1 ]; then add "$step" OK "$label (check)"; return 0; fi
  if "$@" >/dev/null 2>&1; then add "$step" OK "$label"; else add "$step" WARN "$label — command reported failure"; fi
}

# ── 1. learn the host ────────────────────────────────────────────────────────
if [ -x "$SCRIPT_DIR/omarchy-sense.sh" ]; then
  if [ "$CHECK" = 1 ]; then
    snap="$("$SCRIPT_DIR/omarchy-sense.sh" status 2>&1 | sed -n '2p' | tr -d '"' | cut -c1-60)"
    add sense OK "${snap:-no snapshot yet}"
  else
    "$SCRIPT_DIR/omarchy-sense.sh" observe --quiet >/dev/null 2>&1 && add sense OK "host recorded" || add sense WARN "could not record the host"
  fi
else
  add sense SKIP "no omarchy-sense.sh"
fi

# ── 2. the post-update hook ──────────────────────────────────────────────────
if [ "$CHECK" = 1 ]; then
  [ -e "$HOME/.config/omarchy/hooks/post-update.d/ymir-omarchy-sense.sh" ] && add hook OK "installed" || add hook WARN "not installed (run without --check)"
else
  run hook "installed" "$SCRIPT_DIR/omarchy-hook-install.sh" install
fi

# ── 3. the suggested shell plugins (offered, never forced) ───────────────────
if [ "$CHECK" = 1 ]; then
  add plugins OK "offered via bin/omarchy-plugins.sh add"
else
  "$SCRIPT_DIR/omarchy-plugins.sh" suggest >/dev/null 2>&1 && add plugins OK "offered (add with: bin/omarchy-plugins.sh add)" || add plugins WARN "could not list the plugins"
fi

# ── 4. desktops + launcher entries ───────────────────────────────────────────
if [ "$CHECK" = 1 ]; then
  add desktops OK "would place each app on its own numbered desktop + install the entries"
else
  if [ -x "$SCRIPT_DIR/desktop-place.sh" ]; then
    if "$SCRIPT_DIR/desktop-place.sh" apply >/dev/null 2>&1; then
      n=$(ls "$HOME/.local/share/applications"/ymir-*.desktop 2>/dev/null | wc -l | tr -d ' ')
      add desktops OK "numbered desktops placed; $n launcher entr(y|ies) installed"
    else
      add desktops WARN "desktop-place.sh reported failure"; isfail=1
    fi
  else
    add desktops SKIP "no desktop-place.sh"
  fi
fi

# ── 5. the editor's own desktop ──────────────────────────────────────────────
if [ -x "$SCRIPT_DIR/editor-place.sh" ]; then
  run editor "the editor opens on its own desktop" "$SCRIPT_DIR/editor-place.sh" apply
else
  add editor SKIP "no editor-place.sh"
fi

# ── 6. the away-mode alarm channel + the crash sensor ────────────────────────
if [ -e "$ROOT/config/wedge-alarm" ]; then
  add alarm OK "channel kept"
elif [ "$CHECK" = 1 ]; then
  add alarm WARN "channel not written (run without --check)"
elif mkdir -p "$ROOT/config" 2>/dev/null && \
     printf '# The channel the away-mode wedge alarm fires on when an escalation\n# cannot be delivered into the pane. See bin/wedge-notify.sh.\ndesktop\n' >"$ROOT/config/wedge-alarm" 2>/dev/null; then
  add alarm OK "channel written (config/wedge-alarm)"
else
  add alarm WARN "could not write config/wedge-alarm"
fi

# ── 7. the terminal backend Ymir needs ───────────────────────────────────────
if [ "$CHECK" = 1 ]; then
  if have herdr || have tmux; then add backend OK "present"; else add backend WARN "no herdr and no tmux"; fi
elif [ -x "$SCRIPT_DIR/herdr-ensure.sh" ]; then
  if "$SCRIPT_DIR/herdr-ensure.sh" >/dev/null 2>&1 || have tmux; then add backend OK "herdr or tmux ready"; else add backend WARN "no terminal backend — bin/herdr-ensure.sh"; fi
else
  add backend SKIP "no herdr-ensure.sh"
fi

printf 'omarchy[%s]{step,status,detail}:\n' "${#T[@]}"
for i in "${!T[@]}"; do printf '  "%s","%s","%s"\n' "${T[$i]}" "${S[$i]}" "${D[$i]}"; done
[ "$isfail" = 1 ] && exit 1
exit 0
