#!/usr/bin/env bash
# hnitbjorg.sh — Hnitbjörg: the encrypted document vault.
#
# Hnitbjörg is the mountain stronghold where Suttungr hid the mead of poetry —
# here, a LUKS2 container that holds the operator's private documents, SEALED by
# default and opened on demand. The name is the vault, not a person.
#
#   bin/vault/hnitbjorg.sh init [--size 2G]   # create the container (prompts for a passphrase)
#   bin/vault/hnitbjorg.sh open               # open + mount (sudo; prompts for the passphrase)
#   bin/vault/hnitbjorg.sh close              # unmount + seal
#   bin/vault/hnitbjorg.sh status             # sealed/open, mount point, usage (TOON)
#   bin/vault/hnitbjorg.sh backup --to PATH   # copy the encrypted container
#   bin/vault/hnitbjorg.sh passwd             # change the passphrase (luksChangeKey)
#   bin/vault/hnitbjorg.sh fido2-enroll       # add a FIDO2 slot (needs a token)
#   bin/vault/hnitbjorg.sh fido2-list         # list enrolled FIDO2 tokens
#   bin/vault/hnitbjorg.sh phone-enroll       # hold an unlock key on the phone (USB/MTP)
#   bin/vault/hnitbjorg.sh phone-status       # is a phone key enrolled, and is the phone here?
#   bin/vault/hnitbjorg.sh phone-remove       # revoke the phone key (removes its LUKS slot)
#
# The law of the vault:
#   · It is SEALED by default and NEVER automounts. While sealed, only LUKS
#     ciphertext is on disk — no agent, no human, recovers anything without the
#     key.
#   · While OPEN, any process running as the operator — the agents included —
#     can read the mount. Close it when done. That is the real protection.
#   · The passphrase is never stored: not here, not in the home, not in env.
#   · Opening and closing go through `sudo`, so the door costs the sudo password
#     as well as the vault passphrase.
#
# Paths resolve through bin/vault/hoard-lib.sh (Rule 07 — configuration is never
# hardcoded). The container is ONE file with an EMBEDDED LUKS2 header, so a FIDO2
# token can be enrolled later (systemd-cryptenroll has no detached-header support,
# which is why the header is not detached).
#
# Source: sealed by default, sudo-gated, passphrase never written.
set -u

VERSION="1.0.0"

# --- the hoard resolver (Rule 04/07): env → recorded home → default ----------
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _hn="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
  for _i in 1 2 3 4 5; do
    [ -n "$_hn" ] || break
    if [ -r "$_hn/bin/vault/hoard-lib.sh" ]; then . "$_hn/bin/vault/hoard-lib.sh"; YMIR_HOARD_LIB_LOADED=1; break; fi
    if [ -r "$_hn/hoard-lib.sh" ]; then . "$_hn/hoard-lib.sh"; YMIR_HOARD_LIB_LOADED=1; break; fi
    _hn="$(cd "$_hn/.." 2>/dev/null && pwd)"
  done
  unset _hn _i
fi

# The vault lives in the operator's HOME (fleet-synced), not the code tree:
# $YMIR_VAULT_DIR wins; else <home>/vault. The mount point is $YMIR_VAULT_MNT,
# else ~/Vault. One documented default each.
_ymir_home=""
if command -v ymir_home_root >/dev/null 2>&1; then ymir_home_root _ymir_home; fi
[ -n "$_ymir_home" ] || _ymir_home="${YMIR_HOME:-$HOME/Documents/ymirhome}"
VAULT_DIR="${YMIR_VAULT_DIR:-$_ymir_home/vault}"
VAULT_MNT="${YMIR_VAULT_MNT:-$HOME/Vault}"
VAULT_IMG="$VAULT_DIR/hnitbjorg.img"
VAULT_MAPPER="hnitbjorg"

# The phone key — a random LUKS keyfile held in the phone's storage (MTP over
# USB). `open` reads it back once the phone is unlocked; the operator's phone
# lock IS the validation. A marker records that a phone key is enrolled.
VAULT_PHONE_KEY="${YMIR_VAULT_PHONE_KEY:-Download/hnitbjorg.key}"
PHONE_MARKER="$VAULT_DIR/.phone-key"
# the phone library lives beside this door (MTP over USB; test seam YMIR_PHONE_ROOT)
_vd="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
[ -r "$_vd/phone-lib.sh" ] && . "$_vd/phone-lib.sh"
unset _vd

say()  { printf '%s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "$1 is not installed — help: sudo pacman -S $2"; }

is_open()    { sudo -n cryptsetup status "$VAULT_MAPPER" >/dev/null 2>&1 || cryptsetup status "$VAULT_MAPPER" >/dev/null 2>&1; }
is_mounted() { mountpoint -q "$VAULT_MNT"; }

# --- commands ----------------------------------------------------------------

cmd_init() {
  local size="2G"
  while [ $# -gt 0 ]; do case "$1" in --size) size="${2:?--size needs a value}"; shift 2 ;; *) die "unknown flag: $1" ;; esac; done
  need cryptsetup cryptsetup
  need mkfs.ext4 e2fsprogs
  [ -e "$VAULT_IMG" ] && die "the vault already exists: $VAULT_IMG (refusing to overwrite)"
  mkdir -p "$VAULT_DIR" "$VAULT_MNT"
  chmod 700 "$VAULT_DIR" "$VAULT_MNT" 2>/dev/null || true
  say "Creating a $size LUKS2 container at $VAULT_IMG"
  say "You will be asked to set a passphrase. It is NOT stored anywhere — lose it and the data is gone."
  truncate -s "$size" "$VAULT_IMG" || die "could not create the container file"
  # No --batch-mode: the operator answers the irrevocable-overwrite prompt and
  # then sets the passphrase. cryptsetup prompts on the terminal.
  sudo cryptsetup luksFormat --type luks2 --label hnitbjorg "$VAULT_IMG" || { rm -f "$VAULT_IMG"; die "luksFormat failed (container removed)"; }
  say "Formatting the inner filesystem..."
  sudo cryptsetup open "$VAULT_IMG" "$VAULT_MAPPER" || die "could not open the new container"
  sudo mkfs.ext4 -q -L hnitbjorg "/dev/mapper/$VAULT_MAPPER" || { sudo cryptsetup close "$VAULT_MAPPER"; die "mkfs failed"; }
  sudo mount "/dev/mapper/$VAULT_MAPPER" "$VAULT_MNT" || { sudo cryptsetup close "$VAULT_MAPPER"; die "mount failed"; }
  sudo chown "$(id -u):$(id -g)" "$VAULT_MNT"
  chmod 700 "$VAULT_MNT"
  sudo umount "$VAULT_MNT" && sudo cryptsetup close "$VAULT_MAPPER"
  printf 'vault[1]{action,state,img,mount}:\n  "init","sealed","%s","%s"\n' "$VAULT_IMG" "$VAULT_MNT"
}

cmd_open() {
  need cryptsetup cryptsetup
  [ -e "$VAULT_IMG" ] || die "no vault at $VAULT_IMG — run: $(basename "$0") init"
  is_open && { say "already open."; exit 0; }
  mkdir -p "$VAULT_MNT"; chmod 700 "$VAULT_MNT" 2>/dev/null || true
  local opened_by="passphrase"
  # If a phone key is enrolled AND the phone is here, unlock with it. The phone
  # must be unlocked (biometrics) to expose its storage — that IS the validation.
  # A failure (phone absent, file gone, wrong key) falls through to the prompt.
  if [ -r "$PHONE_MARKER" ] && command -v phone_get >/dev/null 2>&1; then
    local rel tmp root=""
    rel="$(cat "$PHONE_MARKER" 2>/dev/null)"
    if [ -n "$rel" ] && phone_root root; then
      tmp="$(mktemp)"; chmod 600 "$tmp"
      if phone_get "$rel" "$tmp" && sudo cryptsetup open --key-file "$tmp" "$VAULT_IMG" "$VAULT_MAPPER" 2>/dev/null; then
        opened_by="phone"
      fi
      shred -u "$tmp" 2>/dev/null || rm -f "$tmp"
    fi
  fi
  if [ "$opened_by" != "phone" ]; then
    sudo cryptsetup open "$VAULT_IMG" "$VAULT_MAPPER" || die "could not open the vault"
  fi
  sudo mount "/dev/mapper/$VAULT_MAPPER" "$VAULT_MNT" || { sudo cryptsetup close "$VAULT_MAPPER"; die "mount failed"; }
  printf 'vault[1]{action,state,img,mount,by}:\n  "open","open","%s","%s","%s"\n' "$VAULT_IMG" "$VAULT_MNT" "$opened_by"
}

cmd_close() {
  is_mounted && { sudo umount "$VAULT_MNT" || die "could not unmount $VAULT_MNT (a file may be open in it)"; }
  is_open && sudo cryptsetup close "$VAULT_MAPPER" || true
  printf 'vault[1]{action,state,img,mount}:\n  "close","sealed","%s","%s"\n' "$VAULT_IMG" "$VAULT_MNT"
}

cmd_status() {
  local state="sealed" usage="-" total="-"
  if [ ! -e "$VAULT_IMG" ]; then
    printf 'vault[1]{state,img,mount}:\n  "absent","%s","%s"\n' "$VAULT_IMG" "$VAULT_MNT"
    return 0
  fi
  total=$(du -h --apparent-size "$VAULT_IMG" 2>/dev/null | cut -f1)
  if is_mounted; then
    state="open"; usage=$(df -h "$VAULT_MNT" 2>/dev/null | awk 'NR==2{print $3" / "$2}')
  elif is_open; then
    state="open (not mounted)"
  fi
  printf 'vault[1]{state,img,size,mount,usage}:\n  "%s","%s","%s","%s","%s"\n' \
    "$state" "$VAULT_IMG" "$total" "$VAULT_MNT" "$usage"
}

cmd_backup() {
  local to=""
  while [ $# -gt 0 ]; do case "$1" in --to) to="${2:?--to needs a path}"; shift 2 ;; *) die "unknown flag: $1" ;; esac; done
  [ -n "$to" ] || die "backup needs --to <path>"
  [ -e "$VAULT_IMG" ] || die "no vault to back up"
  cp --sparse=always "$VAULT_IMG" "$to" || die "backup copy failed"
  printf 'vault[1]{action,state,copy}:\n  "backup","sealed","%s"\n' "$to"
}

cmd_passwd() { need cryptsetup cryptsetup; [ -e "$VAULT_IMG" ] || die "no vault"; sudo cryptsetup luksChangeKey "$VAULT_IMG"; }

cmd_fido2_enroll() {
  need systemd-cryptenroll systemd
  [ -e "$VAULT_IMG" ] || die "no vault"
  sudo systemd-cryptenroll --fido2-device=auto "$VAULT_IMG"
}

cmd_fido2_list() {
  need systemd-cryptenroll systemd
  [ -e "$VAULT_IMG" ] || die "no vault"
  sudo systemd-cryptenroll --fido2-device=list "$VAULT_IMG"
}

# --- the phone key (MTP over USB) --------------------------------------------
# Enroll: make a random keyfile, place it on the phone, add it as a LUKS slot.
# The key is NEVER kept on this machine (only the phone holds it), so this costs
# no local secret. Open: read it back after the phone is unlocked.
cmd_phone_enroll() {
  need cryptsetup cryptsetup
  [ -e "$VAULT_IMG" ] || die "no vault at $VAULT_IMG — run: $(basename "$0") init"
  command -v phone_put >/dev/null 2>&1 || die "phone-lib.sh is missing beside this door"
  local root=""
  phone_root root || die "no phone found — $(phone_hint)"
  local tmp; tmp="$(mktemp)"; chmod 600 "$tmp"
  head -c 64 /dev/urandom > "$tmp" || { rm -f "$tmp"; die "could not make a key"; }
  say "Placing the key on the phone at '$VAULT_PHONE_KEY' ..."
  phone_put "$tmp" "$VAULT_PHONE_KEY" || { rm -f "$tmp"; die "could not write the key to the phone — $(phone_hint)"; }
  say "Adding it as a vault slot (you will be asked for your EXISTING passphrase) ..."
  sudo cryptsetup luksAddKey "$VAULT_IMG" "$tmp" || { rm -f "$tmp"; die "luksAddKey failed"; }
  shred -u "$tmp" 2>/dev/null || rm -f "$tmp"
  printf '%s\n' "$VAULT_PHONE_KEY" > "$PHONE_MARKER"; chmod 600 "$PHONE_MARKER" 2>/dev/null || true
  printf 'vault[1]{action,state,phone-key}:\n  "phone-enroll","enrolled","%s"\n' "$VAULT_PHONE_KEY"
}

cmd_phone_status() {
  local enrolled="no" rel="-" here="no" root=""
  [ -r "$PHONE_MARKER" ] && { enrolled="yes"; rel="$(cat "$PHONE_MARKER" 2>/dev/null)"; }
  command -v phone_root >/dev/null 2>&1 && phone_root root && here="yes"
  printf 'vault[1]{enrolled,key-path,phone-present}:\n  "%s","%s","%s"\n' "$enrolled" "$rel" "$here"
}

# Revoke: remove the key's LUKS slot (using the key from the phone), then delete
# the phone copy and the marker. With no phone present, the slot cannot be
# removed by this door — say so plainly rather than leaving a live slot quietly.
cmd_phone_remove() {
  need cryptsetup cryptsetup
  [ -r "$PHONE_MARKER" ] || die "no phone key is enrolled"
  local rel; rel="$(cat "$PHONE_MARKER" 2>/dev/null)"
  local root="" tmp=""
  if command -v phone_root >/dev/null 2>&1 && phone_root root; then
    tmp="$(mktemp)"; chmod 600 "$tmp"
    if phone_get "$rel" "$tmp"; then
      sudo cryptsetup luksRemoveKey "$VAULT_IMG" "$tmp" || { shred -u "$tmp" 2>/dev/null; die "could not remove the LUKS slot"; }
      shred -u "$tmp" 2>/dev/null || rm -f "$tmp"
      rm -f "$root/$rel" 2>/dev/null || true
    else
      rm -f "$tmp"; die "the phone is here but the key file '$rel' was not found — $(phone_hint)"
    fi
  else
    die "the phone is not here — plug it in to revoke its slot (the LUKS slot is NOT removed yet)"
  fi
  rm -f "$PHONE_MARKER"
  printf 'vault[1]{action,state,phone-key}:\n  "phone-remove","removed","%s"\n' "$rel"
}

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
ACTION="$1"; shift || true
case "$ACTION" in
  init)          cmd_init "$@" ;;
  open)          cmd_open "$@" ;;
  close)         cmd_close "$@" ;;
  status)        cmd_status "$@" ;;
  backup)        cmd_backup "$@" ;;
  passwd)        cmd_passwd "$@" ;;
  fido2-enroll)  cmd_fido2_enroll "$@" ;;
  fido2-list)    cmd_fido2_list "$@" ;;
  phone-enroll)  cmd_phone_enroll "$@" ;;
  phone-status)  cmd_phone_status "$@" ;;
  phone-remove)  cmd_phone_remove "$@" ;;
  *) die "unknown action: $ACTION — help: $(basename "$0") --help" ;;
esac
