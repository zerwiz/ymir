#!/usr/bin/env bash
# hodd.sh — the Allfather's private hoard: path, init, ls, load, emit, get, names, tenant.
#
#   bin/vault/hodd.sh path                 # the Hoard root
#   bin/vault/hodd.sh init                 # create the layout
#   bin/vault/hodd.sh ls                   # what the Hoard holds (names, not contents)
#   bin/vault/hodd.sh load secrets/platform.env   # source a hoard env (quoted, safely)
#   eval "$(bin/vault/hodd.sh emit secrets/platform.env)"   # set them in YOUR shell
#   bin/vault/hodd.sh get secrets/platform.env KEY   # ONE value (multi-line safe)
#   bin/vault/hodd.sh names secrets/platform.env     # the KEY names only
#   bin/vault/hodd.sh tenant acme          # source a tenant's .env (that tenant only)
#
# The SEALED copy (`.age`) is the truth: when it exists it is decrypted and used, and a
# plaintext left beside it is never read — a stale sibling serving 74 keys while the vault
# held 91 is the fault of 2026-11-20. Entries are read as WHOLE ENTRIES by
# `bin/vault/envfile.py`, so a value may span lines (a PEM/OpenSSH block, a quoted value).
#
# Secrets are REFERENCED by path — `$YMIR_HOARD`, else `$YMIR_HOME`, else
# `$HOME/Documents/ymirhome`. The hoard is NEVER inside the repo (Rule 04); the
# repo's `hodd/` keeps only the guard, the README and *.example scaffolds.
set -u
# The ONE resolver (Rule 07): env -> the recorded choice -> the one default.
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _yh="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
  for _i in 1 2 3 4 5; do
    [ -n "$_yh" ] || break
    if [ -r "$_yh/bin/vault/hoard-lib.sh" ]; then . "$_yh/bin/vault/hoard-lib.sh"; YMIR_HOARD_LIB_LOADED=1; break; fi
    if [ -r "$_yh/hoard-lib.sh" ]; then . "$_yh/hoard-lib.sh"; YMIR_HOARD_LIB_LOADED=1; break; fi
    _yh="$(cd "$_yh/.." 2>/dev/null && pwd)"
  done
  unset _yh _i
fi
# WHICH KEY OPENS THE VAULT lives in one library (plan 342): this seat's own SSH
# identity first, the retiring `age.key` only while it still exists.
if [ -z "${YMIR_VAULT_IDENTITY_LIB_LOADED:-}" ]; then
  _yv="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
  if [ -r "$_yv/vault-identity-lib.sh" ]; then
    # shellcheck source=bin/vault/vault-identity-lib.sh
    . "$_yv/vault-identity-lib.sh"; YMIR_VAULT_IDENTITY_LIB_LOADED=1
  fi
  unset _yv
fi
if [ -z "${YMIR_HOME:-}" ] && command -v ymir_home_root >/dev/null 2>&1; then
  ymir_home_root YMIR_HOME
fi

VERSION="1.1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"
# shellcheck source=bin/vault/hoard-lib.sh
. "$SCRIPT_DIR/hoard-lib.sh"
hoard_root HOARD

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
ACTION="${1:-path}"; shift || true

# Source a KEY=value file through the shared whole-entry parser, with proper quoting,
# so values containing spaces — or spanning lines — survive (a plain `source` silently
# drops those lines, and a line reader truncates a PEM block to its first line).
load_env() {
  local f=$1
  [ -r "$f" ] || { printf 'error: not readable: %s\n' "$f" >&2; return 1; }
  eval "$(python3 "$SCRIPT_DIR/envfile.py" emit "$f")" \
    || { printf 'error: the entries of %s could not be read\n' "$f" >&2; return 1; }
  printf 'hodd[1]{action,file}:\n  "load","%s"\n' "$f"
}

# Resolve a secrets path: if the plaintext is absent but an .age sibling exists, decrypt
# it to a 0600 temp and hand back that path. Secrets stay encrypted at rest; the agent
# never reads ciphertext directly — it asks for the resolved path.
#
# THE KEY (plan 342). The vault is locked to the owner's GitHub SSH keys, so the reader
# opens it with THIS machine's SSH identity (~/.ssh/id_ed25519, or one named in the home's
# config/vault-recipients.yaml, or $YMIR_VAULT_IDENTITY). The retired `age.key` is still
# tried LAST while it exists, so a seat that has not yet been given a GitHub key keeps
# working through the switch instead of going dark.
age_decrypt_any() {  # <age-file> <out-file> — 0 when some identity opened it
  local src=$1 out=$2 id
  command -v age >/dev/null 2>&1 || return 1
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    if age -d -i "$id" "$src" >"$out" 2>/dev/null && [ -s "$out" ]; then return 0; fi
  done < <(vault_identity_candidates 2>/dev/null)
  return 1
}

# Resolve a secrets path to a readable file through the result var: the SEALED copy is
# decrypted to a temp, and when no sealed copy exists the plaintext is the file itself.
# Secrets stay encrypted at rest; the agent never reads ciphertext directly.
resolve_secret() {  # <file> <result-var>
  local f=$1 var=$2 tmp
  # THE SEALED COPY IS THE SOURCE OF TRUTH, and it is read ALONE.
  #
  # 2026-11-05: a plaintext left beside the .age went stale in silence and every reader
  # saw 74 keys while the vault held 77, so the mail grant read as missing.
  # 2026-11-20: the same stale plaintext was read by `hodd-set.sh` as its SOURCE, and a
  # 91-key vault was written back with 75. A fallback is how both happened.
  #
  # So when a sealed copy exists it either decrypts and is used, or this door REFUSES. It
  # never quietly serves the older plaintext, because a reader that cannot tell a stale
  # copy from the vault is a reader that reports the wrong truth as confidently as the
  # right one.
  if [ -r "$f.age" ]; then
    command -v age >/dev/null 2>&1 || { printf 'error: %s is encrypted but age is not installed\nhelp: sudo pacman -S age\n' "$f.age" >&2; return 1; }
    [ -n "$(vault_identity_candidates 2>/dev/null | head -1)" ] \
      || { printf 'error: encrypted %s and this seat holds no key that could open it\nhelp: put a key at ~/.ssh/id_ed25519, or name one in config/vault-recipients.yaml\n' "$f.age" >&2; return 1; }
    tmp="$(mktemp)"; chmod 600 "$tmp"
    age_decrypt_any "$f.age" "$tmp" \
      || { rm -f "$tmp"; printf 'error: cannot decrypt %s — this seat is not a recipient, and a plaintext beside it is NOT used in its place\nhelp: bin/vault/vault-relock.sh --check\n' "$f.age" >&2; return 1; }
    printf -v "$var" '%s' "$tmp"; return 0
  fi
  if [ -s "$f" ]; then printf -v "$var" '%s' "$f"; return 0; fi
  printf 'error: not readable: %s (and no %s.age)\n' "$f" "$f" >&2; return 1
}
case "$ACTION" in
  path)  printf '%s\n' "$HOARD" ;;
  init)
    mkdir -p "$HOARD"/{secrets,docs,tenants,identity} || exit 1
    printf 'hodd[1]{action,path}:\n  "init","%s"\n' "$HOARD" ;;
  ls)
    printf 'hodd[4]{section,path,files}:\n'
    for d in secrets docs tenants identity; do
      n="$(find "$HOARD/$d" -type f 2>/dev/null | wc -l | tr -d ' ')"
      printf '  "%s","%s",%s\n' "$d" "$HOARD/$d" "$n"
    done ;;
  load)
    f="${1:-}"; [ -n "$f" ] || { printf 'error: load needs a path under the Hoard\n' >&2; exit 2; }
    case "$f" in /*) ;; *) f="$HOARD/$f" ;; esac
    resolve_secret "$f" rf || exit 1
    load_env "$rf"
    case "$rf" in "$f") ;; *) rm -f "$rf" ;; esac ;;
  emit)
    # Print `export KEY=value` lines (quoting-safe) for the CALLER to eval, so
    # `eval "$(bin/vault/hodd.sh emit <file>)"` sets the vars in the invoking shell. The
    # value is the WHOLE entry, so a multi-line secret arrives intact.
    f="${1:-}"; [ -n "$f" ] || { printf 'error: emit needs a path under the Hoard\n' >&2; exit 2; }
    case "$f" in /*) ;; *) f="$HOARD/$f" ;; esac
    resolve_secret "$f" rf || exit 1
    python3 "$SCRIPT_DIR/envfile.py" emit "$rf"
    rc=$?
    case "$rf" in "$f") ;; *) rm -f "$rf" ;; esac
    exit "$rc"
    ;;
  get)
    # ONE value, printed as it is: a token, a password, or a whole armoured block.
    f="${1:-}"; k="${2:-}"
    [ -n "$f" ] && [ -n "$k" ] || { printf 'error: get needs <file> <KEY>\n' >&2; exit 2; }
    case "$f" in /*) ;; *) f="$HOARD/$f" ;; esac
    resolve_secret "$f" rf || exit 1
    python3 "$SCRIPT_DIR/envfile.py" get "$rf" "$k"
    rc=$?
    case "$rf" in "$f") ;; *) rm -f "$rf" ;; esac
    exit "$rc"
    ;;
  names)
    # The KEY NAMES only — never a value.
    f="${1:-}"; [ -n "$f" ] || { printf 'error: names needs a path under the Hoard\n' >&2; exit 2; }
    case "$f" in /*) ;; *) f="$HOARD/$f" ;; esac
    resolve_secret "$f" rf || exit 1
    python3 "$SCRIPT_DIR/envfile.py" names "$rf"
    rc=$?
    case "$rf" in "$f") ;; *) rm -f "$rf" ;; esac
    exit "$rc"
    ;;
  tenant)
    t="${1:-}"; [ -n "$t" ] || { printf 'error: tenant needs a name\n' >&2; exit 2; }
    resolve_secret "$HOARD/tenants/$t/.env" rf || exit 1
    load_env "$rf"
    case "$rf" in "$HOARD/tenants/$t/.env") ;; *) rm -f "$rf" ;; esac ;;
  *) printf 'error: unknown action %s\nhelp: bin/vault/hodd.sh [path|init|ls|load|emit|get|names|tenant]\n' "$ACTION" >&2; exit 2 ;;
esac
