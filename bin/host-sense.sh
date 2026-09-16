#!/usr/bin/env bash
# host-sense.sh — learn THIS machine: distro, kernel, session, desktop, and what
# the desktop can actually do.
#
# Ymir is **Omarchy-first**: the Omarchy layer is first-class (host sensing,
# numbered-desktop placement, launcher entries, shell plugins, post-update hook),
# and Rule 05 keeps the core portable so other hosts carry their own layer.
# "First" is not "only": an operator may run Ubuntu, Fedora, Arch, Debian, on
# Wayland or X11, under GNOME, KDE, Hyprland or Sway. A layer is gated on its
# host and reports a clean skip elsewhere — never assumed, never faked.
#
# This is the one place that looks before anything acts.
# It is a sensor: it observes and reports. It changes nothing.
#
# Usage:
#   bin/host-sense.sh                     # the host, as TOON
#   bin/host-sense.sh --json              # the same facts, machine-readable
#   bin/host-sense.sh capability <name>   # yes|partial|no — for scripting
#   bin/host-sense.sh --version
#
# Capabilities asked of a desktop:
#   placement  can a window be pinned to its own numbered workspace from a script
#   launcher   do .desktop entries land in a menu / taskbar / app grid
#   tray       is there a native system-tray host (icons beside the clock)
set -u

VERSION="1.0.0"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

MODE="toon"
CAP=""
case "${1-}" in
  --json) MODE="json"; shift ;;
  capability) CAP="${2:-}"; shift 2 2>/dev/null || true ;;
  *) : ;;
esac

have() { command -v "$1" >/dev/null 2>&1; }

# ── os ───────────────────────────────────────────────────────────────────────
OS_NAME="unknown"; OS_ID="unknown"; OS_LIKE=""; OS_VERSION=""
if [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  OS_NAME="$(. /etc/os-release 2>/dev/null; printf '%s' "${PRETTY_NAME:-${NAME:-unknown}}")"
  OS_ID="$(. /etc/os-release 2>/dev/null; printf '%s' "${ID:-unknown}")"
  OS_LIKE="$(. /etc/os-release 2>/dev/null; printf '%s' "${ID_LIKE:-}")"
  OS_VERSION="$(. /etc/os-release 2>/dev/null; printf '%s' "${VERSION_ID:-}")"
fi
[ "$OS_ID" = "unknown" ] && [ -r /etc/lsb-release ] && { . /etc/lsb-release 2>/dev/null; OS_ID="${DISTRIB_ID:-unknown}"; OS_NAME="${DISTRIB_DESCRIPTION:-$OS_NAME}"; }

# The family is what a package-manager choice actually keys on.
FAMILY="other"
case " $OS_ID ${OS_LIKE:-} " in
  *" ubuntu "*|*" debian "*|*" linuxmint "*|*" pop "*) FAMILY="debian" ;;
  *" fedora "*|*" rhel "*|*" centos "*|*" rocky "*|*" almalinux "*) FAMILY="rhel" ;;
  *" arch "*|*" endeavouros "*|*" manjaro "*) FAMILY="arch" ;;
  *" opensuse "*|*" sles "*) FAMILY="suse" ;;
  *" alpine "*) FAMILY="alpine" ;;
esac
case "$OS_ID" in
  ubuntu|debian|linuxmint|pop) FAMILY="debian" ;;
  fedora|rhel|centos|rocky|almalinux) FAMILY="rhel" ;;
  arch|endeavouros|manjaro|omarchy) FAMILY="arch" ;;
  opensuse*|sles) FAMILY="suse" ;;
  alpine) FAMILY="alpine" ;;
esac

PKG="none"
for pm in apt dnf pacman zypper apk yum; do have "$pm" && { PKG="$pm"; break; }; done

KERNEL="$(uname -sr 2>/dev/null || printf 'unknown')"
ARCH="$(uname -m 2>/dev/null || printf 'unknown')"

# ── platform ─────────────────────────────────────────────────────────────────
# The core is portable; the host must be named before any layer can gate on it.
# A Windows operator reaches Ymir through WSL, so WSL is its own platform, not
# "linux with a strange kernel".
PLATFORM="linux"; WSL="no"
case "$(uname -s 2>/dev/null)" in
  Darwin) PLATFORM="macos" ;;
  MINGW*|MSYS*|CYGWIN*) PLATFORM="windows" ;;
  Linux)
    if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then PLATFORM="wsl"; WSL="yes"; fi ;;
esac

# ── session ──────────────────────────────────────────────────────────────────
SESSION="none"
if [ -n "${WAYLAND_DISPLAY:-}" ] || [ "${XDG_SESSION_TYPE:-}" = "wayland" ]; then
  SESSION="wayland"
elif [ -n "${DISPLAY:-}" ] || [ "${XDG_SESSION_TYPE:-}" = "x11" ]; then
  SESSION="x11"
fi

# ── desktop ──────────────────────────────────────────────────────────────────
# XDG_CURRENT_DESKTOP is a colon list ("ubuntu:GNOME"); DESKTOP_SESSION is a
# fallback. Match the first token we recognise, and prefer a live compositor
# binary over a stale environment variable.
DESKTOP="unknown"
for d in "${XDG_CURRENT_DESKTOP:-}" "${DESKTOP_SESSION:-}" "${XDG_SESSION_DESKTOP:-}"; do
  [ -n "$d" ] || continue
  for tok in $(printf '%s' "$d" | tr 'A-Z:' 'a-z '); do
    case "$tok" in
      hyprland) DESKTOP="hyprland" ;;
      gnome|ubuntu) [ "$DESKTOP" = "unknown" ] && DESKTOP="gnome" ;;
      kde|plasma) DESKTOP="kde" ;;
      sway) DESKTOP="sway" ;;
      niri) DESKTOP="niri" ;;
      river) DESKTOP="river" ;;
      xfce) DESKTOP="xfce" ;;
      cinnamon) DESKTOP="cinnamon" ;;
      mate) DESKTOP="mate" ;;
      cosmic) DESKTOP="cosmic" ;;
    esac
  done
  [ "$DESKTOP" != "unknown" ] && break
done
# A running compositor does not lie; an inherited variable can.
have hyprctl && hyprctl version >/dev/null 2>&1 && DESKTOP="hyprland"
have swaymsg && DESKTOP="sway"
have gnome-shell && [ "${XDG_CURRENT_DESKTOP:-}" != "" ] && DESKTOP="gnome"
have plasmashell && DESKTOP="kde"

COMPOSITOR="none"
have hyprctl && COMPOSITOR="hyprland"
have swaymsg && COMPOSITOR="sway"
have gnome-shell && COMPOSITOR="gnome-shell"
have plasmashell && COMPOSITOR="plasmashell"
have kwin_wayland && COMPOSITOR="kwin_wayland"

# ── what the desktop can actually do ─────────────────────────────────────────
# placement: a script can pin a window to its own numbered workspace.
PLACEMENT="no"
case "$COMPOSITOR" in
  hyprland) have hyprctl && PLACEMENT="yes" ;;   # hyprctl keyword windowrule/dispatch
  sway)     have swaymsg && PLACEMENT="yes" ;;   # swaymsg assign
  *)        PLACEMENT="no" ;;                    # GNOME/KDE: dynamic workspaces, no rule
esac

# launcher: .desktop entries are a freedesktop standard, so this is the one
# capability nearly every desktop has.
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
APPS_DIR="$DATA_HOME/applications"
LAUNCHER="no"
[ -d "$APPS_DIR" ] && [ -w "$APPS_DIR" ] && LAUNCHER="yes"
[ "$LAUNCHER" = "no" ] && [ -w "$DATA_HOME" ] && LAUNCHER="yes"   # can be created

# tray: an icon beside the clock. GNOME needs an extension; KDE/Hyprland have
# native hosts; the rest vary.
TRAY="no"
case "$DESKTOP" in
  kde)      TRAY="yes" ;;
  hyprland) TRAY="partial" ;;   # via a bar (waybar etc.), if one is running
  gnome)    TRAY="partial" ;;   # only with an AppIndicator extension
  *)        TRAY="no" ;;
esac

# A desktop that is managed by Ymir's own Omarchy layer, or merely compatible.
OMARCHY="no"
{ have omarchy || [ -d "$HOME/.local/share/omarchy" ]; } && OMARCHY="yes"

if [ -n "$CAP" ]; then
  case "$CAP" in
    placement) printf '%s\n' "$PLACEMENT" ;;
    launcher)  printf '%s\n' "$LAUNCHER" ;;
    tray)      printf '%s\n' "$TRAY" ;;
    *) printf 'error: unknown capability %s\nhelp: bin/host-sense.sh capability [placement|launcher|tray]\n' "$CAP" >&2; exit 2 ;;
  esac
  exit 0
fi

if [ "$MODE" = "json" ]; then
  python3 - "$OS_NAME" "$OS_ID" "$FAMILY" "$OS_VERSION" "$KERNEL" "$ARCH" "$SESSION" "$DESKTOP" "$COMPOSITOR" "$PKG" "$PLACEMENT" "$LAUNCHER" "$TRAY" "$OMARCHY" "$PLATFORM" "$WSL" <<'PY'
import json, sys
keys = ["os","id","family","version","kernel","arch","session","desktop",
        "compositor","package_manager","placement","launcher","tray","omarchy",
        "platform","wsl"]
print(json.dumps(dict(zip(keys, sys.argv[1:])), indent=2))
PY
  exit 0
fi

# human default: a small TOON block. Keys are plain; values quoted.
printf 'host[1]{os,id,family,session,desktop}:\n'
printf '  "%s","%s","%s","%s","%s"\n' "$OS_NAME" "$OS_ID" "$FAMILY" "$SESSION" "$DESKTOP"
printf 'machine[5]{platform,wsl,kernel,arch,package_manager}:\n'
printf '  "%s","%s","%s","%s","%s"\n' "$PLATFORM" "$WSL" "$KERNEL" "$ARCH" "$PKG"
printf 'capabilities[3]{name,state,note}:\n'
case "$PLACEMENT" in
  yes) printf '  "placement","yes","%s can pin a window to its own workspace"\n' "$COMPOSITOR" ;;
  *)   printf '  "placement","no","%s has no scriptable per-window workspace rule — placement is skipped, never faked"\n' "${DESKTOP:-desktop}" ;;
esac
printf '  "launcher","%s","%s"\n' "$LAUNCHER" "$APPS_DIR"
printf '  "tray","%s","%s"\n' "$TRAY" "$([ "$TRAY" = yes ] && printf 'native tray host' || printf 'no native tray host — an icon needs an extension or a bar')"
printf 'layer[1]{name,state}:\n'
printf '  "omarchy","%s"\n' "$([ "$OMARCHY" = yes ] && printf 'FIRST-CLASS LAYER — Omarchy detected, the Omarchy layer applies here' || printf 'first-class layer, not on THIS host — Omarchy is absent, so its layer skips cleanly (Rule 05); the portable core runs, and this host gets its own layer')"
