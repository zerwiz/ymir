#!/usr/bin/env bash
# hodd-set.sh — set, replace or remove ONE key in an age-encrypted secret file.
# usage-start
#
#   bin/vault/hodd-set.sh KEY VALUE [FILE]     # FILE defaults to secrets/platform.env
#   bin/vault/hodd-set.sh --stdin KEY [FILE]   # the VALUE arrives on stdin, so it never
#                                              # appears in a process listing (a token, a
#                                              # password); same guards, same report
#   bin/vault/hodd-set.sh --del KEY [FILE]     # remove ONE key — revocation as a verb;
#                                              # refuses to empty the file, keeps the backup
#   bin/vault/hodd-set.sh --get KEY [FILE]     # print one value (never the file)
#   bin/vault/hodd-set.sh --list [FILE]        # print the KEY NAMES only
#
# The sealed copy is the ONLY source. `FILE.age` is decrypted and that is what is read,
# edited and written back; a plaintext `FILE` left beside it is never read while the
# sealed copy exists (2026-11-20: reading a stale plaintext took a 91-key vault to 75).
#
# Guards, each of which failed on 2026-11-20:
#   1. WHOLE ENTRIES. The file is parsed by `bin/vault/envfile.py`: a value may span
#      lines (a quoted value, a backslash continuation, a PEM/OpenSSH block), and every
#      entry that is not being edited is carried through byte for byte.
#   2. AN INDEPENDENT COUNT. The vault is decrypted AGAIN from disk and its entries are
#      counted with the same parser; the write is refused unless the result holds
#      exactly before+1 (a new key), before (a replaced key) or before-1 (a deleted one).
#      The entries that would go missing are printed — by NAME only.
#   3. A ROUND TRIP. The re-encrypted file is decrypted again and every entry except the
#      touched one is compared byte for byte with the vault on disk; any difference
#      refuses the write and the old file stays.
#   4. the old file is kept as a timestamped backup beside it;
#   5. the write is atomic (temp file + mv), mode 0600, and any plaintext temp is shredded.
#
# Exit: 0 ok · 1 a guard refused · 2 usage · 3 --del found no such key.
# usage-end
set -u
VERSION="2.0.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
# WHICH KEY OPENS THE VAULT (plan 342): this seat's own SSH identity, the retiring
# `age.key` only as the last fallback. One library answers it for every door.
# shellcheck disable=SC1091
. "$ROOT/bin/vault/vault-identity-lib.sh" 2>/dev/null || true
HOARD=""
ymir_home_root YMIR_HOME_R 2>/dev/null || true
[ -n "${YMIR_HOME_R:-}" ] || { printf 'error: the home is unresolved\n' >&2; exit 1; }
HOARD="$YMIR_HOME_R/hodd"
PARSER="$SCRIPT_DIR/envfile.py"

usage() { sed -n '/^# usage-start$/,/^# usage-end$/p' "$0" | sed 's/^# \{0,1\}//' | sed '1d;$d'; }
die()   { printf 'error: %s\n' "$*" >&2; exit 1; }
need_py() {
  command -v python3 >/dev/null 2>&1 || die "python3 is missing — cannot read the entries"
  [ -r "$PARSER" ] || die "the entry parser is missing at $PARSER"
}

mode="set"; key=""; value=""; rel="secrets/platform.env"; value_file=""
case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  --version|-v) printf '%s\n' "$VERSION"; exit 0 ;;
  --get) mode="get"; key="${2:-}"; rel="${3:-$rel}" ;;
  --stdin|--set-stdin) mode="stdin"; key="${2:-}"; rel="${3:-$rel}" ;;
  --del|--delete) mode="del"; key="${2:-}"; rel="${3:-$rel}" ;;
  --list) mode="list"; rel="${2:-$rel}" ;;
  "") usage >&2; exit 2 ;;
  *) key="$1"; value="${2:-}"; rel="${3:-$rel}" ;;
esac

plain="$HOARD/$rel"
secret="$plain.age"

[ -r "$secret" ] || [ -s "$plain" ] || die "no secret at $plain (nor $plain.age)"
need_py

work="$(mktemp -d)"; chmod 700 "$work"
cleanup() { find "$work" -type f -exec shred -u {} + 2>/dev/null || true; rm -rf "$work"; }
trap cleanup EXIT

# ── which key opens the vault, and to whom it is re-encrypted (plan 342) ───────────
# Both walk ONE resolver (bin/vault/vault-identity-lib.sh): the SSH identity this seat
# holds, then the retiring `age.key` while it still exists. The lock is the declared
# GitHub keys once `age.key` is gone, so the recipient is the declaration, read through
# the re-lock door — never a second copy of the rules in this script.
decrypt_vault() {  # <age-file> <out-file>
  local src=$1 out=$2 id
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    age -d -i "$id" "$src" >"$out" 2>/dev/null && return 0
  done < <(vault_identity_candidates 2>/dev/null)
  return 1
}
reencrypt() {  # <plaintext> <out.age>
  local src=$1 out=$2 recipient=""
  if [ -r "$HOARD/secrets/age.key" ]; then
    recipient="$(age-keygen -y "$HOARD/secrets/age.key" 2>/dev/null || true)"
    [ -n "$recipient" ] || { printf 'could not read the recipient from age.key' >&2; return 1; }
    age -e -r "$recipient" -o "$out" "$src" 2>"$work/err"
    return $?
  fi
  "$ROOT/bin/vault/vault-relock.sh" --recipients > "$work/recipients" 2>"$work/err" \
    || { printf 'the declared recipients could not be read — %s' "$(head -c 200 "$work/err")" >&2; return 1; }
  age -e -R "$work/recipients" -o "$out" "$src" 2>"$work/err"
}

# ── THE SOURCE OF TRUTH: the sealed copy on disk ─────────────────────────────────
# A plaintext beside the sealed file is a record that has gone stale in silence: the
# writer never refreshed it (2026-11-05) and, on 2026-11-20, reading it took a 91-key
# vault to 75 in one write. So: when the .age exists, the plaintext is not opened at all.
sealed=0
if [ -r "$secret" ]; then
  decrypt_vault "$secret" "$work/vault" \
    || die "cannot decrypt $secret — this seat holds no key that opens it (help: bin/vault/vault-relock.sh --check)"
  [ -s "$work/vault" ] || die "$secret decrypted to NOTHING — refusing to touch it"
  sealed=1
  cp "$work/vault" "$work/current"
  truth="$work/vault"
  if [ -s "$plain" ]; then
    printf 'note: a plaintext %s sits beside the sealed copy and is STALE — this door reads only %s\n' \
      "$plain" "$(basename "$secret")" >&2
  fi
else
  # The first write of a file that has never been sealed: the plaintext is the only
  # source there is, and this write is what creates the sealed copy.
  cp "$plain" "$work/current"
  truth="$work/current"
  printf 'note: no sealed copy yet — reading %s once; this write creates %s\n' "$plain" "$(basename "$secret")" >&2
fi

before_count="$(python3 "$PARSER" count "$truth")" || die "the entries could not be read from $(basename "$truth")"
# An armoured block whose END was lost is CARRIED THROUGH, never repaired and never used
# as a reason to swallow the entries below it. It is named, so the operator can see it.
unterminated="$(python3 "$PARSER" unterminated "$truth" 2>/dev/null || true)"
[ -n "$unterminated" ] \
  && printf 'warning: %s holds a block with no END line — %s; carried through as it is\n' \
       "$(basename "$truth")" "$(printf '%s' "$unterminated" | tr '\n' ' ')" >&2

case "$mode" in
  list)
    python3 "$PARSER" names "$truth"
    exit 0 ;;
  get)
    [ -n "$key" ] || { usage >&2; exit 2; }
    python3 "$PARSER" get "$truth" "$key"
    exit $? ;;
esac

[ -n "$key" ] || { usage >&2; exit 2; }
case "$key" in
  *[!A-Za-z0-9_]*|[0-9]*) printf 'error: %s is not a key name\n' "$key" >&2; exit 2 ;;
esac

if [ "$mode" = "stdin" ]; then
  # The value never touches argv: a token on a command line is visible to every
  # process of the same user, and a mail grant is exactly that kind of secret.
  cat > "$work/value.raw" || die "stdin could not be read — nothing written"
  # One trailing newline is the shell's line end, not part of the secret; anything else
  # (a multi-line value, a whole armoured block) is the value, kept as it arrived.
  python3 - "$work/value.raw" "$work/value" <<'PY' || die "the value could not be read"
import sys
raw = open(sys.argv[1], "rb").read().decode("utf-8", "surrogateescape")
open(sys.argv[2], "wb").write(raw.rstrip("\n").encode("utf-8", "surrogateescape"))
PY
  value_file="$work/value"
  [ -s "$value_file" ] || die "--stdin received nothing — nothing written"
  mode="set"
fi

if [ "$mode" = "set" ] && [ -z "$value_file" ]; then
  value_file="$work/value"
  printf '%s' "$value" > "$value_file"
fi

# ── the edit, through the whole-entry parser ─────────────────────────────────────
if [ "$mode" = "del" ]; then
  python3 "$PARSER" has "$truth" "$key" \
    || { printf 'hodd-set[1]{action,key}:\n  "absent","%s"\n' "$key"; exit 3; }
  python3 "$PARSER" del "$truth" "$key" --out "$work/next" || die "the entry could not be removed"
else
  python3 "$PARSER" set "$truth" "$key" --value-file "$value_file" --out "$work/next" \
    || die "the entry could not be written"
fi

# ── guard 2: an INDEPENDENT count, taken from the vault on disk ──────────────────
# Not a count of the thing we just built compared against itself: the sealed file is
# decrypted a second time, straight from disk, and that copy is what the guard judges.
if [ "$sealed" = 1 ]; then
  decrypt_vault "$secret" "$work/before" \
    || die "the sealed file could not be read again — nothing written"
else
  cp "$truth" "$work/before"
fi

action="set"
if [ "$mode" = "del" ]; then
  action="del"
elif python3 "$PARSER" has "$work/before" "$key"; then
  action="replace"
fi

python3 "$PARSER" guard --before "$work/before" --after "$work/next" --key "$key" --action "$action" \
  || exit 1

if [ "$mode" = "del" ] && [ "$(python3 "$PARSER" count "$work/next")" -lt 1 ]; then
  die "$key is the only key — deleting it would empty the vault, refused"
fi

# ── guards 3–5: re-encrypt, decrypt again, compare every other entry; keep the old ──
reencrypt "$work/next" "$work/next.age" \
  || die "re-encryption failed — $(head -c 200 "$work/err" 2>/dev/null)"
decrypt_vault "$work/next.age" "$work/verify" \
  || die "the re-encrypted file does not decrypt — nothing written"
python3 "$PARSER" diff "$work/before" "$work/verify" --except "$key" > "$work/diff" 2>&1 \
  || { printf 'error: the round trip changed an entry this edit did not touch — nothing written\n' >&2
       sed -n '1,10p' "$work/diff" >&2; exit 1; }

after_count="$(python3 "$PARSER" count "$work/verify")"
backup="$secret.bak-$(date -u +%Y%m%dT%H%M%SZ)"
[ -s "$secret" ] && cp -p "$secret" "$backup"
install -m 600 "$work/next.age" "$secret.new" && mv "$secret.new" "$secret"

printf 'hodd-set[5]{file,action,key,entries,backup}:\n  "%s","%s","%s","%s → %s","%s"\n' \
  "$rel" "${action}" "$key" "$before_count" "$after_count" "$(basename "$backup" 2>/dev/null)"
