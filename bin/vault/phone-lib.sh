#!/usr/bin/env bash
# phone-lib.sh — reach the operator's phone storage for the vault's phone key.
#
# Hnitbjörg can hold an unlock key ON the operator's phone: a random LUKS keyfile
# lives in the phone's storage, and `open` reads it back after the phone is
# unlocked (the phone's biometric lock is the validation). This library finds the
# phone's storage and reads/writes one file there.
#
# Transport: **MTP over USB**. MTP over Bluetooth is in the spec but Android does
# not implement it, and no Linux MTP client supports it — so this is USB-only.
# MTP is reached through GVfs (`gvfs-mtp`, present on this seat); no app is needed
# on the phone (license-clean, Apache-2.0).
#
# Test seam: set `YMIR_PHONE_ROOT` to a local directory and every function works
# against it, so the whole flow is provable without a phone.
#
# Source-safe: defines functions only; call `<fn> <result-var>`.

set -u

# The phone's storage root: `$YMIR_PHONE_ROOT` (tests) else the first GVfs MTP
# mount. Prints the path via the result var; returns non-zero when none stands.
phone_root() {  # <result-var>
  local var=${1-} r=""
  [ -n "$var" ] || return 2
  if [ -n "${YMIR_PHONE_ROOT:-}" ]; then
    [ -d "$YMIR_PHONE_ROOT" ] && r="$YMIR_PHONE_ROOT"
  else
    r="$(ls -d /run/user/"$(id -u)"/gvfs/mtp:host=* 2>/dev/null | head -1)"
  fi
  printf -v "$var" '%s' "$r"
  [ -n "$r" ]
}

# The plain-language next step when no phone is reachable.
phone_hint() {
  printf '%s' "plug the phone in by USB, unlock it (biometrics), tap 'File transfer / MTP' on the phone, then retry"
}

# Read <relpath> from the phone into <localfile>. Non-zero when the phone or the
# file is not reachable (so a caller can fall back to the passphrase).
phone_get() {  # <relpath> <localfile>
  local rel=${1:?} out=${2:?} root=""
  phone_root root || return 1
  if [ -n "${YMIR_PHONE_ROOT:-}" ]; then
    [ -r "$root/$rel" ] || return 1
    cp -f "$root/$rel" "$out"
  else
    command -v gio >/dev/null 2>&1 || return 1
    gio cat "$root/$rel" >"$out" 2>/dev/null || return 1
    [ -s "$out" ]
  fi
}

# Write <localfile> onto the phone at <relpath>. Parent dirs are created when the
# backend allows it (GVfs/MTP cannot always mkdir — Download/ usually exists).
phone_put() {  # <localfile> <relpath>
  local src=${1:?} rel=${2:?} root=""
  [ -r "$src" ] || return 1
  phone_root root || return 1
  if [ -n "${YMIR_PHONE_ROOT:-}" ]; then
    mkdir -p "$(dirname "$root/$rel")" 2>/dev/null || true
    cp -f "$src" "$root/$rel"
  else
    command -v gio >/dev/null 2>&1 || return 1
    gio copy "$src" "$root/$rel" 2>/dev/null
  fi
}
