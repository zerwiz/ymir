#!/usr/bin/env bash
# heimdall-ssh-keys.sh — Heimdall's SSH-keys surface.
#
# Heimdall is the authentication guardian: he admits an entrant only by the rune
# of introduction they carry. For the OpenSSH server on a Ymir host, those runes
# live on GitHub — this script fetches `https://github.com/<user>.keys`, validates
# every key, and authorizes the valid ones in `~/.ssh/authorized_keys`, so a new
# machine joins the fleet by publishing its public key to GitHub and nothing else.
#
# The mechanism follows Omarchy's `omarchy-setup-security-sshd --gh-keys`: fetch,
# validate, authorize; and only *then* offer to turn password logins off.
#
# Portability (Rule 05): this ward is the UNIVERSAL door — one published GitHub
# key opens every warded computer. Proven seats (2026-09-22): Omarchy (omarchy,
# heimdallomarchy) and Ubuntu/Debian (zerwizserver, whynot) — plain bash, the
# systemd user timer, Debian's `ssh` unit vs Arch's `sshd` both handled. The
# install wires it in via bin/heimdall-ensure.sh (step `heimdall`), so a fresh
# seat is warded at setup, Omarchy or Ubuntu alike.
#
# Usage:
#   heimdall-ssh-keys.sh status
#   heimdall-ssh-keys.sh add [<github-user> ...] [--key=<public-key>] [--quiet]
#   heimdall-ssh-keys.sh harden | unharden
#   heimdall-ssh-keys.sh timer install | remove | status
#   heimdall-ssh-keys.sh --version
#
# Examples:
#   heimdall-ssh-keys.sh add zerwiz
#   heimdall-ssh-keys.sh add --key 'ssh-ed25519 AAAA… laptop'   # paste a key instead
#   heimdall-ssh-keys.sh add --quiet          # refresh every configured user
#   heimdall-ssh-keys.sh harden              # needs sudo; disables password logins
#   heimdall-ssh-keys.sh timer install       # user timer, refresh every 15 min
#
# Env:
#   HEIMDALL_GH_USERS   extra/user list when none is configured (space separated)
#   HEIMDALL_KEYS_FILE  override the authorized_keys target
#   HEIMDALL_HTTP_TIMEOUT  curl timeout seconds (default 15)
#
# Exit: 0 ok, 1 failure, 2 usage, 3 nothing to do.
set -u

VERSION="1.1.0"
KEYS_FILE="${HEIMDALL_KEYS_FILE:-$HOME/.ssh/authorized_keys}"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/heimdall"
USERS_FILE="$CONF_DIR/gh-users"
DROPIN="/etc/ssh/sshd_config.d/10-heimdall-hardening.conf"
HTTP_TIMEOUT="${HEIMDALL_HTTP_TIMEOUT:-15}"
QUIET=0

case "${1-}" in
  -v | -V | --version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h | --help | "")
    sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
esac

say() { [ "$QUIET" = 1 ] || printf '%s\n' "$*" >&2; }
die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}
usage() {
  printf 'error: %s\nhelp: bin/heimdall-ssh-keys.sh {status|add|harden|unharden|timer}\n' "$1" >&2
  exit 2
}

need_curl() { command -v curl >/dev/null 2>&1 || die "curl not found — cannot reach github.com"; }
need_sshkeygen() { command -v ssh-keygen >/dev/null 2>&1 || die "ssh-keygen not found"; }

fingerprint() {
  ssh-keygen -lf /dev/stdin 2>/dev/null <<<"$1" | awk '{print $2}'
}

fetch_keys() {
  local user="$1" out
  out="$(curl -fsSL --max-time "$HTTP_TIMEOUT" "https://github.com/$user.keys")" || return 1
  [ -n "$out" ] || return 1
  printf '%s\n' "$out"
}

valid_users() {
  local u
  if [ -s "$USERS_FILE" ]; then
    while IFS= read -r u; do
      [ -n "$u" ] && printf '%s\n' "$u"
    done <"$USERS_FILE"
  fi
  [ -n "${HEIMDALL_GH_USERS:-}" ] && printf '%s\n' ${HEIMDALL_GH_USERS}
  return 0
}

remember_user() {
  local user="$1"
  mkdir -p "$CONF_DIR"
  if [ -s "$USERS_FILE" ] && grep -qxF "$user" "$USERS_FILE"; then return 0; fi
  printf '%s\n' "$user" >>"$USERS_FILE"
}

# Merge existing + supplied files into one authorized_keys-shaped stream:
# comments kept, blanks dropped, CRLF normalised, duplicates collapsed by key
# fingerprint, every line newline-terminated.
merge_keys() {
  local target="$1"
  shift
  declare -A seen=()
  local src line fp
  for src in "$target" "$@"; do
    [ -r "$src" ] || continue
    while IFS= read -r line || [ -n "$line" ]; do
      line="${line%$'\r'}"
      [ -z "$line" ] && continue
      case "$line" in \#*)
        printf '%s\n' "$line"
        continue
        ;;
      esac
      fp="$(fingerprint "$line")"
      [ -n "$fp" ] || continue
      [ "${seen[$fp]:-}" = 1 ] && continue
      seen[$fp]=1
      printf '%s\n' "$line"
    done <"$src"
  done
}

count_keys_in() {
  local n
  n="$(ssh-keygen -lf "$1" 2>/dev/null | wc -l)"
  printf '%s' "$((n))"
}

count_keys() {
  [ -r "$KEYS_FILE" ] || {
    printf '0'
    return
  }
  count_keys_in "$KEYS_FILE"
}

password_auth_state() {
  command -v sshd >/dev/null 2>&1 || {
    printf 'unknown'
    return
  }
  if grep -qiE '^[[:space:]]*PasswordAuthentication[[:space:]]+no' "$DROPIN" 2>/dev/null; then
    printf 'no'
  else
    printf 'yes'
  fi
}

cmd_status() {
  need_sshkeygen
  local users keys pw hardened file
  users="$(valid_users | paste -sd, -)"
  keys="$(count_keys)"
  pw="$(password_auth_state)"
  hardened=false
  [ "$pw" = no ] && hardened=true
  [ -n "$users" ] || users="—"
  file="$KEYS_FILE"
  printf 'heimdall[1]{keys,gh_users,password_auth,hardened,file}:\n'
  printf '  "%s","%s","%s","%s","%s"\n' "$keys" "$users" "$pw" "$hardened" "$file"
}

cmd_add() {
  need_sshkeygen
  local users=() literals=() arg
  while [ $# -gt 0 ]; do
    case "$1" in
      --quiet)
        QUIET=1
        shift
        ;;
      --key=*)
        literals+=("${1#--key=}")
        shift
        ;;
      --key)
        shift
        [ $# -gt 0 ] || usage "--key needs a public key"
        literals+=("$1")
        shift
        ;;
      -*) usage "unknown option '$1'" ;;
      *)
        users+=("$1")
        shift
        ;;
    esac
  done
  if [ "${#users[@]}" -eq 0 ] && [ "${#literals[@]}" -eq 0 ]; then
    while IFS= read -r arg; do
      [ -n "$arg" ] && users+=("$arg")
    done < <(valid_users)
  fi
  [ "${#users[@]}" -gt 0 ] || [ "${#literals[@]}" -gt 0 ] ||
    die "nothing to authorize — use: add <github-user> or add --key '<public-key>'"

  mkdir -p "$(dirname "$KEYS_FILE")"
  chmod 700 "$(dirname "$KEYS_FILE")" 2>/dev/null || true
  [ -e "$KEYS_FILE" ] || : >"$KEYS_FILE"
  chmod 600 "$KEYS_FILE"

  local staging fetched_keys raw added label tmp before after k key user
  staging="$(mktemp)"
  fetched_keys="$(mktemp)"
  cp -a "$KEYS_FILE" "$staging"

  printf 'heimdall_add[%d]{source,fetched,added,total}:\n' "$((${#users[@]} + ${#literals[@]}))"
  local rc=0

  absorb() {
    before="$(count_keys_in "$staging")"
    tmp="$(mktemp)"
    merge_keys "$staging" "$fetched_keys" >"$tmp"
    mv "$tmp" "$staging"
    after="$(count_keys_in "$staging")"
    added=$((after - before))
    [ "$added" -lt 0 ] && added=0
    printf '  "%s","%s","%s","%s"\n' "$label" "$(grep -c . "$fetched_keys")" "$added" "$after"
  }

  for key in "${literals[@]}"; do
    label="key"
    : >"$fetched_keys"
    if [ -z "$(fingerprint "$key")" ]; then
      say "heimdall: skipping invalid key: ${key:0:32}…"
      rc=1
      continue
    fi
    printf '%s\n' "$key" >>"$fetched_keys"
    absorb
  done

  if [ "${#users[@]}" -gt 0 ]; then
    need_curl
    for user in "${users[@]}"; do
      label="$user"
      : >"$fetched_keys"
      if raw="$(fetch_keys "$user")"; then
        while IFS= read -r k; do
          [ -z "$k" ] && continue
          [ -n "$(fingerprint "$k")" ] || {
            say "heimdall: skipping invalid key advertised by $user"
            continue
          }
          printf '%s github:%s\n' "$k" "$user" >>"$fetched_keys"
        done <<<"$raw"
      else
        say "heimdall: could not fetch keys for '$user' (offline or unknown user)"
        printf '  "%s","0","0","%s"\n' "$user" "$(count_keys)"
        rc=1
        continue
      fi
      absorb
      remember_user "$user"
    done
  fi
  rm -f "$fetched_keys"
  chmod 600 "$staging"

  if cmp -s "$staging" "$KEYS_FILE"; then
    rm -f "$staging"
    say "heimdall: authorized keys already current"
  else
    cp -a "$KEYS_FILE" "$KEYS_FILE.bak.$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
    mv "$staging" "$KEYS_FILE"
    say "heimdall: authorized keys updated ($(count_keys) keys)"
  fi
  return $rc
}

as_root() {
  if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi
}

write_dropin() {
  as_root tee "$DROPIN" >/dev/null <<'CONF'
# Written by bin/heimdall-ssh-keys.sh once an SSH key was authorized.
# Delete this file and reload sshd to allow password logins again.
PasswordAuthentication no
KbdInteractiveAuthentication no
CONF
}

reload_sshd() {
  as_root systemctl reload ssh 2>/dev/null || as_root systemctl reload sshd
}

cmd_harden() {
  need_sshkeygen
  [ "$(count_keys)" -gt 0 ] || die "no authorized keys — refusing to disable password logins (that would strand the machine)"
  say "heimdall: disabling SSH password authentication"
  write_dropin
  if ! as_root sshd -t; then
    as_root rm -f "$DROPIN"
    die "sshd rejected the hardening config; removed it, passwords stay on"
  fi
  local effective
  if ! effective="$(as_root sshd -T)" ||
    ! grep -qixF 'passwordauthentication no' <<<"$effective" ||
    ! grep -qixF 'kbdinteractiveauthentication no' <<<"$effective"; then
    as_root rm -f "$DROPIN"
    die "sshd did not apply the restrictions (an earlier rule wins); removed the ineffective config"
  fi
  reload_sshd
  cmd_status
}

cmd_unharden() {
  if [ ! -e "$DROPIN" ]; then
    say "heimdall: not hardened; nothing to remove"
    cmd_status
    return 0
  fi
  as_root rm -f "$DROPIN"
  as_root sshd -t && reload_sshd
  cmd_status
}

timer_unit_dir() { printf '%s' "${HEIMDALL_UNIT_DIR:-$HOME/.config/systemd/user}"; }

cmd_timer() {
  local action="${1-}"
  local self unit_dir
  self="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
  unit_dir="$(timer_unit_dir)"
  case "$action" in
    install)
      mkdir -p "$unit_dir"
      cat >"$unit_dir/heimdall-ssh-keys.service" <<UNIT
[Unit]
Description=Heimdall — refresh SSH authorized keys from GitHub

[Service]
Type=oneshot
ExecStart=$self add --quiet
UNIT
      cat >"$unit_dir/heimdall-ssh-keys.timer" <<'UNIT'
[Unit]
Description=Heimdall — SSH authorized keys refresh timer

[Timer]
OnBootSec=2min
OnUnitActiveSec=15min
Persistent=true

[Install]
WantedBy=timers.target
UNIT
      systemctl --user daemon-reload
      systemctl --user enable --now heimdall-ssh-keys.timer
      say "heimdall: timer enabled (every 15 min). For headless hosts: sudo loginctl enable-linger $USER"
      cmd_timer status
      ;;
    remove)
      systemctl --user disable --now heimdall-ssh-keys.timer 2>/dev/null || true
      rm -f "$unit_dir/heimdall-ssh-keys.service" "$unit_dir/heimdall-ssh-keys.timer"
      systemctl --user daemon-reload
      say "heimdall: timer removed"
      ;;
    status)
      systemctl --user is-active heimdall-ssh-keys.timer 2>/dev/null || printf 'inactive\n'
      systemctl --user list-timers heimdall-ssh-keys.timer --no-pager 2>/dev/null | head -3
      ;;
    *) usage "timer needs install|remove|status" ;;
  esac
}

CMD="${1-}"
shift || true
case "$CMD" in
  status) cmd_status ;;
  add) cmd_add "$@" ;;
  harden) cmd_harden ;;
  unharden) cmd_unharden ;;
  timer) cmd_timer "${1-}" ;;
  *) usage "unknown command '$CMD'" ;;
esac
