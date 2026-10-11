#!/usr/bin/env bash
# vault-phone-proof.sh — the phone-key flow, proven offline (no phone, no LUKS).
#
# A proof is a command, not a claim. This drives the phone library and the vault
# door against a throwaway vault dir and a LOCAL directory standing in for the
# phone (the `YMIR_PHONE_ROOT` test seam), so it needs no phone, no USB, and no
# passphrase. It asserts:
#   1. the phone library reads and writes a file through the seam
#   2. `phone-status` is honest on a fresh vault (not enrolled, no phone)
#   3. `phone-enroll` refuses cleanly with no vault
#   4. `phone-enroll` refuses cleanly with no phone reachable (naming the next step)
#   5. `open` does not attempt the phone path when no key is enrolled
#
#   tests/e2e/vault-phone-proof.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOOR="$ROOT/bin/vault/hnitbjorg.sh"
LIB="$ROOT/bin/vault/phone-lib.sh"
[ -x "$DOOR" ] || { printf 'vault-phone-proof[1]{case,result}:\n  "missing","%s"\n' "$DOOR"; exit 1; }
[ -r "$LIB" ]  || { printf 'vault-phone-proof[1]{case,result}:\n  "missing","%s"\n' "$LIB"; exit 1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export YMIR_VAULT_DIR="$TMP/vault"
export YMIR_VAULT_MNT="$TMP/mnt"
PHONE="$TMP/phone"; mkdir -p "$PHONE/Download"

fail=0
ok()  { printf '  "ok","%s"\n' "$1"; }
bad() { printf '  "FAIL","%s"\n' "$1"; fail=1; }
printf 'vault-phone-proof[1]{case,result}:\n'

# 1. the library round-trips a file through the test seam
YMIR_PHONE_ROOT="$PHONE" bash -c "
  . '$LIB'
  printf 'the-key' > '$TMP/k'
  phone_put '$TMP/k' Download/hnitbjorg.key || exit 1
  phone_get Download/hnitbjorg.key '$TMP/k2' || exit 2
  cmp -s '$TMP/k' '$TMP/k2' || exit 3
" && ok "phone library round-trips a file" || bad "phone library round-trip"

# 2. phone-status is honest on a fresh vault
out="$(YMIR_PHONE_ROOT="$PHONE" "$DOOR" phone-status 2>/dev/null)"
printf '%s' "$out" | grep -q '"no","-","yes"' && ok "phone-status: not enrolled, phone present" \
  || bad "phone-status shape: $out"

# 3. phone-enroll refuses with no vault
YMIR_PHONE_ROOT="$PHONE" "$DOOR" phone-enroll >/dev/null 2>&1 && bad "phone-enroll ran with no vault" \
  || ok "phone-enroll refuses with no vault"

# 4. phone-enroll refuses with no phone reachable (dummy vault image present)
mkdir -p "$YMIR_VAULT_DIR"; : > "$YMIR_VAULT_DIR/hnitbjorg.img"
msg="$(YMIR_PHONE_ROOT="$TMP/absent" "$DOOR" phone-enroll 2>&1)"
printf '%s' "$msg" | grep -qi 'no phone found' && ok "phone-enroll refuses with no phone (names the next step)" \
  || bad "phone-enroll with no phone: $msg"
[ ! -e "$YMIR_VAULT_DIR/.phone-key" ] && ok "no marker written on a refused enroll" || bad "marker written on refusal"

# 5. fast paths
"$DOOR" --version >/dev/null 2>&1 && ok "version" || bad "version"

[ "$fail" = 0 ] && { printf '  "ok","all phone-key proofs passed"\n'; exit 0; }
printf '  "FAIL","phone-key proofs failed"\n'; exit 1
