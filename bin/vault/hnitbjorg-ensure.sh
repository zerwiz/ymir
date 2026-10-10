#!/usr/bin/env bash
# hnitbjorg-ensure.sh — ensure the vault's tooling stands and its path is sound.
#
# Hnitbjörg is the encrypted document vault (bin/vault/hnitbjorg.sh). This ensure
# surface checks the ONE dependency (cryptsetup) and the vault directory, and
# mends what it can. It NEVER creates a vault: creation asks for a passphrase that
# only the operator may type, so `init` stays a deliberate, human act.
#
# Usage:
#   hnitbjorg-ensure.sh status
#   hnitbjorg-ensure.sh ensure [--install]
#   hnitbjorg-ensure.sh --version
#
# Exit: 0 ready (or made ready), 1 not ready, 2 usage.
set -u

VERSION="1.0.0"

# The hoard resolver (Rule 04/07): env → recorded home → default.
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _he="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
  for _i in 1 2 3 4 5; do
    [ -n "$_he" ] || break
    if [ -r "$_he/bin/vault/hoard-lib.sh" ]; then . "$_he/bin/vault/hoard-lib.sh"; YMIR_HOARD_LIB_LOADED=1; break; fi
    if [ -r "$_he/hoard-lib.sh" ]; then . "$_he/hoard-lib.sh"; YMIR_HOARD_LIB_LOADED=1; break; fi
    _he="$(cd "$_he/.." 2>/dev/null && pwd)"
  done
  unset _he _i
fi

_home=""
command -v ymir_home_root >/dev/null 2>&1 && ymir_home_root _home
[ -n "$_home" ] || _home="${YMIR_HOME:-$HOME/Documents/ymirhome}"
VAULT_DIR="${YMIR_VAULT_DIR:-$_home/vault}"
VAULT_IMG="$VAULT_DIR/hnitbjorg.img"

have() { command -v "$1" >/dev/null 2>&1; }

install_cryptsetup() {
  case "$(uname -s)" in
    Linux)
      if have pacman;  then sudo pacman -S --needed --noconfirm cryptsetup >/dev/null 2>&1
      elif have apt-get; then sudo apt-get install -y cryptsetup >/dev/null 2>&1
      elif have dnf;   then sudo dnf install -y cryptsetup >/dev/null 2>&1
      elif have zypper; then sudo zypper --non-interactive install cryptsetup >/dev/null 2>&1
      else return 1; fi ;;
    *) return 1 ;;
  esac
  have cryptsetup
}

state() {  # prints sealed|open|absent
  if [ -e "$VAULT_IMG" ]; then
    if cryptsetup status hnitbjorg >/dev/null 2>&1; then printf 'open'; else printf 'sealed'; fi
  else
    printf 'absent'
  fi
}

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
CMD="${1-}"; shift || true
DO_INSTALL=0
case "$CMD" in status|ensure) ;; *) printf 'error: unknown command %s\nhelp: bin/vault/hnitbjorg-ensure.sh [status|ensure]\n' "$CMD" >&2; exit 2 ;; esac
while [ $# -gt 0 ]; do case "$1" in --install) DO_INSTALL=1; shift ;; *) shift ;; esac; done

if [ "$CMD" = status ]; then
  have cryptsetup || { printf 'vault[1]{component,status,detail}:\n  "cryptsetup","missing","install it: sudo pacman -S cryptsetup"\n'; exit 1; }
  printf 'vault[3]{component,status,detail}:\n'
  printf '  "cryptsetup","ok","%s"\n' "$(cryptsetup --version 2>/dev/null | head -1)"
  printf '  "vault-dir","%s","%s"\n' "$([ -d "$VAULT_DIR" ] && echo ok || echo missing)" "$VAULT_DIR"
  printf '  "vault","%s","%s"\n' "$(state)" "$VAULT_IMG"
  # A sealed or absent vault is healthy; a missing directory is not yet ready.
  [ -d "$VAULT_DIR" ] || exit 1
  exit 0
fi

# ensure
have cryptsetup || { [ "$DO_INSTALL" = 1 ] && install_cryptsetup; }
have cryptsetup || { printf 'error: cryptsetup absent — install it (bin/vault/hnitbjorg-ensure.sh ensure --install)\n' >&2; exit 1; }
mkdir -p "$VAULT_DIR" 2>/dev/null || true
chmod 700 "$VAULT_DIR" 2>/dev/null || true
printf 'vault[2]{component,status}:\n  "cryptsetup","ok"\n  "vault-dir","ok"\n'
exit 0
