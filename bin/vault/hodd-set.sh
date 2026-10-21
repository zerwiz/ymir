#!/usr/bin/env bash
# hodd-set.sh — set ONE key in an age-encrypted secret file, with guards that make a
# hand-edit unnecessary (and a hand-edit's failure impossible).
#
# Why this exists: on 2026-10-21 a hand-edit of `hodd/secrets/platform.env.age` decrypted
# to nothing (the cause was never proven), the append still ran, and the re-encrypted file
# replaced 87 secrets with 3. A backup taken seconds earlier restored the vault — luck, not
# design. This door exists so the guard is the code, not the operator's care.
#
#   bin/vault/hodd-set.sh KEY VALUE [FILE]     # FILE defaults to secrets/platform.env
#   bin/vault/hodd-set.sh --get KEY [FILE]     # print one value (never the file)
#   bin/vault/hodd-set.sh --list [FILE]        # print the KEY NAMES only
#
# Guards, each of which failed that day:
#   1. the decrypted plaintext must be NON-EMPTY, and must contain at least as many keys
#      as the encrypted copy claims — otherwise nothing is written at all;
#   2. the re-encrypted file is decrypted AGAIN and compared before it replaces anything;
#   3. the old file is kept as a timestamped backup beside it;
#   4. the write is atomic (temp file + mv), mode 0600, and any plaintext temp is shredded.
#
# Exit: 0 ok · 1 a guard refused · 2 usage.
set -u
VERSION="1.0.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
HOARD=""
ymir_home_root YMIR_HOME_R 2>/dev/null || true
[ -n "${YMIR_HOME_R:-}" ] || { printf 'error: the home is unresolved\n' >&2; exit 1; }
HOARD="$YMIR_HOME_R/hodd"

usage() { sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; }

mode="set"; key=""; value=""; rel="secrets/platform.env"
case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  --version|-v) printf '%s\n' "$VERSION"; exit 0 ;;
  --get) mode="get"; key="${2:-}"; rel="${3:-$rel}" ;;
  --list) mode="list"; rel="${2:-$rel}" ;;
  "") usage >&2; exit 2 ;;
  *) key="$1"; value="${2:-}"; rel="${3:-$rel}" ;;
esac

plain="$HOARD/$rel"
secret="$plain.age"

[ -r "$secret" ] || [ -s "$plain" ] || { printf 'error: no secret at %s (nor %s.age)\n' "$plain" "$secret" >&2; exit 1; }

work="$(mktemp -d)"; chmod 700 "$work"
cleanup() { shred -u "$work"/* 2>/dev/null || rm -f "$work"/*; rmdir "$work" 2>/dev/null; }
trap cleanup EXIT

# ── guard 1: the plaintext must be real ────────────────────────────────────────────
if [ -s "$plain" ]; then
  cp "$plain" "$work/current"
else
  age -d -i "$HOARD/secrets/age.key" "$secret" > "$work/current" 2>"$work/err" \
    || { printf 'error: cannot decrypt %s — %s\n' "$secret" "$(head -c 200 "$work/err")" >&2; exit 1; }
fi
[ -s "$work/current" ] || { printf 'error: %s decrypted to NOTHING — refusing to touch it\n' "$secret" >&2; exit 1; }
keys_before="$(grep -cE '^[A-Za-z_][A-Za-z0-9_]*=' "$work/current" || true)"
[ "${keys_before:-0}" -gt 0 ] || { printf 'error: no KEY=value lines in %s — refusing to touch it\n' "$secret" >&2; exit 1; }

case "$mode" in
  list)
    grep -oE '^[A-Za-z_][A-Za-z0-9_]*' "$work/current"
    exit 0 ;;
  get)
    [ -n "$key" ] || { usage >&2; exit 2; }
    grep -E "^${key}=" "$work/current" | head -1 | cut -d= -f2-
    exit 0 ;;
esac

[ -n "$key" ] || { usage >&2; exit 2; }

# ── replace or append, idempotently ───────────────────────────────────────────────
awk -v k="$key" -v v="$value" '
  BEGIN { done = 0 }
  $0 ~ "^" k "=" { if (!done) { print k "=" v; done = 1 } ; next }
  { print }
  END { if (!done) print k "=" v }
' "$work/current" > "$work/next"

keys_after="$(grep -cE '^[A-Za-z_][A-Za-z0-9_]*=' "$work/next" || true)"
[ "${keys_after:-0}" -ge "${keys_before:-0}" ] \
  || { printf 'error: the edit would LOSE keys (%s → %s) — refused\n' "$keys_before" "$keys_after" >&2; exit 1; }

# ── guard 2 and 3: re-encrypt, decrypt again, compare; keep the old ───────────────
recipient="$(age-keygen -y "$HOARD/secrets/age.key" 2>/dev/null || true)"
[ -n "$recipient" ] || { printf 'error: could not read the recipient from age.key\n' >&2; exit 1; }
age -e -r "$recipient" -o "$work/next.age" "$work/next" 2>"$work/err" \
  || { printf 'error: re-encryption failed — %s\n' "$(head -c 200 "$work/err")" >&2; exit 1; }
age -d -i "$HOARD/secrets/age.key" "$work/next.age" > "$work/verify" 2>/dev/null \
  || { printf 'error: the re-encrypted file does not decrypt — nothing written\n' >&2; exit 1; }
cmp -s "$work/next" "$work/verify" \
  || { printf 'error: the round-trip does not match — nothing written\n' >&2; exit 1; }

backup="$secret.bak-$(date -u +%Y%m%dT%H%M%SZ)"
[ -s "$secret" ] && cp -p "$secret" "$backup"
install -m 600 "$work/next.age" "$secret.new" && mv "$secret.new" "$secret"

printf 'hodd-set[3]{file,key,keys}:\n  "%s","%s","%s → %s"\n  "backup","%s",""\n' \
  "$rel" "$key" "$keys_before" "$keys_after" "$(basename "$backup" 2>/dev/null)"
