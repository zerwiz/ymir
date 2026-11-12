#!/usr/bin/env bash
# heimdall-ensure.sh — ensure the Heimdall SSH-key ward is present and armed.
#
# **Heimdall** is the authentication guardian: he admits an entrant only by the
# rune of introduction they carry (github.com/<user>.keys — validated, merged
# into this seat's authorized_keys, refreshed every 15 minutes). One key
# published to the operator's GitHub opens every warded computer — Omarchy,
# Ubuntu, or any Linux that the install stands up. This ensure surface makes
# the ward part of the install itself, so a new seat is warded at setup, not
# by a later errand.
#
# Usage:
#   heimdall-ensure.sh status                 # is the ward present + armed?
#   heimdall-ensure.sh ensure [--install]     # arm it (--install may add openssh)
#   heimdall-ensure.sh install                # = ensure --install
#   heimdall-ensure.sh --version
#
# WHOSE KEYS (2026-11-12). The ward admits ONLY the GitHub user(s) the operator
# names: HEIMDALL_GH_USERS, or the recorded file ($XDG_CONFIG_HOME/heimdall/gh-users).
# It never infers a user from the checkout's remote, and it never adds a built-in
# user: on a collaborator's machine that hands the upstream owner SSH access. With
# no user named, `ensure` refuses to arm (no keys written, no timer) and says how.
# The ward script is copied from THIS tree; a URL is fetched only when
# HEIMDALL_DISTRO_URL is set on purpose.
#
# Exit: 0 armed/present, 1 not armed, 2 usage.
set -u

VERSION="1.0.0"

# Where the ward lives once ensured — a stable path, independent of the repo
# tree, so the systemd user timer keeps working across repo moves/upgrades.
WARD_DEST="${HEIMDALL_WARD_DEST:-$HOME/.local/bin/host/heimdall-ssh-keys.sh}"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/heimdall"
USERS_FILE="$CONF_DIR/gh-users"
# The ward script ships in this tree; a remote copy is fetched only when asked for.
LOCAL_WARD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/heimdall-ssh-keys.sh"
DISTRO_URL="${HEIMDALL_DISTRO_URL:-}"
# The GitHub user(s) whose keys the seat admits. Resolved: env > recorded file
# > empty (reported honestly). Never the remote's owner, never a built-in name.
gh_users_of() {
  if [ -n "${HEIMDALL_GH_USERS:-}" ]; then printf '%s\n' ${HEIMDALL_GH_USERS}; return 0; fi
  if [ -s "$USERS_FILE" ]; then grep -v '^[[:space:]]*\(#\|$\)' "$USERS_FILE"; return 0; fi
  return 1
}

sshd_bin() {
  command -v sshd 2>/dev/null || [ -x /usr/sbin/sshd ] && { printf /usr/sbin/sshd; return 0; }
  return 1
}

ward_present() { [ -x "$WARD_DEST" ]; }
timer_active() { systemctl --user is-active heimdall-ssh-keys.timer >/dev/null 2>&1; }
linger_on() { loginctl show-user "$(id -un)" -p Linger 2>/dev/null | grep -q '=yes'; }

status() {
  local users keys tim on ln ward_ver ss
  users="$(gh_users_of 2>/dev/null | paste -sd, -)"; [ -n "$users" ] || users="—"
  keys="—"; on="false"; ln="false"; ward_ver="—"; ss="absent"
  if ward_present; then
    ward_ver="$("$WARD_DEST" --version 2>/dev/null || printf '?')"
    keys="$("$WARD_DEST" status 2>/dev/null | sed -n '2p' | cut -d, -f1 | tr -d ' "')"
    timer_active && on="true"
    linger_on && ln="true"
  fi
  if sshd_bin >/dev/null; then ss="present"; else ss="absent"; fi
  printf 'heimdall[1]{ward,version,gh_users,keys,timer,linger,sshd}:\n'
  printf '  "%s","%s","%s","%s","%s","%s","%s"\n' \
    "$(ward_present && printf true || printf false)" "$ward_ver" "$users" "$keys" "$on" "$ln" "$ss"
  ward_present || return 1
}

ensure_openssh() {  # only with --install; honest WARN, never a silent lockout
  if sshd_bin >/dev/null 2>&1; then return 0; fi
  printf 'heimdall: no sshd on this seat — installing openssh …\n' >&2
  if command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --noconfirm --needed openssh || return 1
  elif command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -y >/dev/null 2>&1
    sudo apt-get install -y --no-install-recommends openssh-server || return 1
  else
    printf 'heimdall: no pacman/apt — install an OpenSSH server on this host yourself\nhelp: sudo pacman -S --noconfirm openssh | sudo apt-get install -y openssh-server\n' >&2
    return 1
  fi
  sudo systemctl enable --now sshd 2>/dev/null || sudo systemctl enable --now ssh 2>/dev/null || true
  sshd_bin >/dev/null 2>&1
}

fetch_ward() {
  mkdir -p "$(dirname "$WARD_DEST")"
  if [ -z "$DISTRO_URL" ]; then
    [ -r "$LOCAL_WARD" ] || { printf 'heimdall: no ward script beside this one (%s)\n' "$LOCAL_WARD" >&2; return 1; }
    cp "$LOCAL_WARD" "$WARD_DEST.tmp" || { rm -f "$WARD_DEST.tmp"; return 1; }
  else
    command -v curl >/dev/null 2>&1 || { printf 'heimdall: curl missing — cannot fetch %s\n' "$DISTRO_URL" >&2; return 1; }
    curl -fsSL --max-time 30 "$DISTRO_URL" -o "$WARD_DEST.tmp" || { rm -f "$WARD_DEST.tmp"; return 1; }
  fi
  chmod +x "$WARD_DEST.tmp" && mv "$WARD_DEST.tmp" "$WARD_DEST"
}

ensure() {
  local users="" failed=0
  [ "$DO_OPENSSH" = 1 ] && { ensure_openssh || { printf 'heimdall: sshd could not be installed — console sudo required\n' >&2; return 1; }; }
  users="$(gh_users_of 2>/dev/null || true)"
  if [ -z "$users" ]; then
    # Refuse to arm: no keys written, no timer. Guessing a user is how a stranger gets in.
    printf 'heimdall: no GitHub user named — the ward stays unarmed (no keys written, no timer)\nhelp: printf '"'"'<your-github-user>\\n'"'"' > %s (or HEIMDALL_GH_USERS=<user>), then re-run ensure\n' "$USERS_FILE" >&2
    return 1
  fi
  ward_present || { fetch_ward || { printf 'heimdall: ward could not be installed — re-run later; the guard stands unarmed until then\n' >&2; return 1; }; }
  # shellcheck disable=SC2086
  "$WARD_DEST" add --quiet $users >/dev/null 2>&1 || failed=1
  "$WARD_DEST" timer install >/dev/null 2>&1 || failed=1
  if [ "$failed" = 1 ]; then printf 'heimdall: ward present but could not be fully armed (offline? no user bus?) — run %s add <user> and %s timer install later\n' "$WARD_DEST" "$WARD_DEST" >&2; return 1; fi
  status
}

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
CMD="${1-}"; shift || true
DO_OPENSSH=0
case "$CMD" in
  ensure|status|install) ;;
  *) printf 'error: unknown command %s\nhelp: bin/host/heimdall-ensure.sh [status|ensure|install]\n' "$CMD" >&2; exit 2 ;;
esac
while [ $# -gt 0 ]; do
  case "$1" in
    --install) DO_OPENSSH=1 ;;
    --quiet) : ;;
    *) : ;;
  esac
  shift
done
[ "$CMD" = install ] && DO_OPENSSH=1

case "$CMD" in
  status) status ;;
  ensure|install) ensure ;;
esac