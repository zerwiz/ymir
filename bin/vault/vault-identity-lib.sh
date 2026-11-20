#!/usr/bin/env bash
# vault-identity-lib.sh — WHICH KEY OPENS THE VAULT, and WHICH KEYS MAY (plan 342 phase 1).
#
# The vault (`hodd/secrets/platform.env.age`) used to be encrypted to a key file that
# travelled in the same repository as the vault itself (`hodd/secrets/age.key`). That is
# one lock with its key taped to it. Plan 342 moves the lock onto the owner's **GitHub
# SSH keys**: an `age` file encrypted to every key GitHub lists for the owner that the
# home DECLARES, and each machine opens it with its own private SSH key, which never
# leaves that machine.
#
# This library is the one place that answers the two questions the rest of the house
# asks, so the reader (`hodd.sh`), the writer (`hodd-set.sh`), the re-lock door
# (`vault-relock.sh`) and Eir's surface can never disagree:
#
#   vault_identity_resolve <var>     which private key THIS seat opens the vault with
#   vault_identity_is_legacy <path>  is that key the retired age.key?
#   vault_recipients_yaml <var>      the home's recipients file
#   vault_declared_rows <file|->     the declared recipients, one TSV row each (title, fingerprint, machine)
#   vault_declared_top <file> <key>  one top-level value from that file (vault · identity · login)
#   vault_pub_fingerprint <file|->   the SHA256 fingerprint of a public key, as `ssh-keygen -lf` says it
#
# THE ORDER IS LAW (Rule 07: one documented default, never a guess):
#
#   1. `$YMIR_VAULT_IDENTITY`                       an explicit word from the machine
#   2. `identity:` in the home's recipients file     a seat may name its own key
#   3. `~/.ssh/id_ed25519`, `id_ed25519_sk`, `id_rsa`  the ordinary ssh identities
#   4. `<hoard>/secrets/age.key`                     the LEGACY key, while it still exists
#
# Step 4 is a fallback during the switch and is reported as `legacy` wherever it is
# used, so a seat that has not yet been given a GitHub key says so out loud instead of
# looking healthy by accident.
#
# Source-safe: defines functions only; every answer is returned through a `<result-var>`.
set -u

_vi_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ] && [ -r "$_vi_here/hoard-lib.sh" ]; then
  # shellcheck source=bin/vault/hoard-lib.sh
  . "$_vi_here/hoard-lib.sh"; YMIR_HOARD_LIB_LOADED=1
fi

# The home's declaration of who may open the vault. Settings live in the home's
# `config/` shelf (plan 331), so a packaged install reads the operator's file, never
# the package's example.
vault_recipients_yaml() {  # <result-var>
  local result_var=${1-} settings=""
  [ -n "$result_var" ] || return 2
  if [ -n "${YMIR_VAULT_RECIPIENTS:-}" ]; then
    printf -v "$result_var" '%s' "$YMIR_VAULT_RECIPIENTS"; return 0
  fi
  hoard_settings_dir settings 2>/dev/null || settings=""
  [ -n "$settings" ] || return 1
  printf -v "$result_var" '%s' "$settings/vault-recipients.yaml"
}

# EVERY candidate, in order, one per line, deduped, only the ones that exist. A reader
# that wants to fall back (ssh key first, then the retiring age.key) walks this list; a
# caller that wants "which key does this seat use" takes the first line.
vault_identity_candidates() {
  local yaml="" named="" hoard="" k out=""
  if [ -n "${YMIR_VAULT_IDENTITY:-}" ] && [ -r "${YMIR_VAULT_IDENTITY}" ]; then
    out="$YMIR_VAULT_IDENTITY"
  fi
  if vault_recipients_yaml yaml 2>/dev/null && [ -r "$yaml" ]; then
    named="$(vault_declared_top "$yaml" identity 2>/dev/null || true)"
    case "$named" in "~/"*) named="$HOME/${named#\~/}" ;; esac
    if [ -n "$named" ] && [ -r "$named" ]; then out="$out
$named"; fi
  fi
  for k in "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_ed25519_sk" "$HOME/.ssh/id_rsa"; do
    [ -r "$k" ] && out="$out
$k"
  done
  hoard_root hoard 2>/dev/null || hoard=""
  if [ -n "$hoard" ] && [ -r "$hoard/secrets/age.key" ]; then out="$out
$hoard/secrets/age.key"; fi
  printf '%s\n' "$out" | awk 'NF && !seen[$0]++'
}

# THE SAME ORDER, ONE PLACE. A caller that needs a different order does not have one.
vault_identity_resolve() {  # <result-var>
  local result_var=${1-} cand="" yaml="" hoard="" named="" k
  [ -n "$result_var" ] || return 2
  if [ -n "${YMIR_VAULT_IDENTITY:-}" ] && [ -r "${YMIR_VAULT_IDENTITY}" ]; then
    printf -v "$result_var" '%s' "$YMIR_VAULT_IDENTITY"; return 0
  fi
  if vault_recipients_yaml yaml 2>/dev/null && [ -r "$yaml" ]; then
    named="$(vault_declared_top "$yaml" identity 2>/dev/null || true)"
    case "$named" in
      "~/"*) named="$HOME/${named#\~/}" ;;
    esac
    if [ -n "$named" ] && [ -r "$named" ]; then
      printf -v "$result_var" '%s' "$named"; return 0
    fi
  fi
  for k in "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_ed25519_sk" "$HOME/.ssh/id_rsa"; do
    if [ -r "$k" ]; then printf -v "$result_var" '%s' "$k"; return 0; fi
  done
  hoard_root hoard 2>/dev/null || hoard=""
  if [ -n "$hoard" ] && [ -r "$hoard/secrets/age.key" ]; then
    printf -v "$result_var" '%s' "$hoard/secrets/age.key"; return 0
  fi
  printf -v "$result_var" '%s' ""
  return 1
}

# Is this identity the retired key file? A legacy answer is not an error — it is a
# seat that has not yet been given a GitHub key, and every caller says so.
vault_identity_is_legacy() {  # <path>
  local p=${1-} hoard=""
  [ -n "$p" ] || return 1
  hoard_root hoard 2>/dev/null || return 1
  [ "$p" = "$hoard/secrets/age.key" ]
}

# The declared recipients, one TSV row each: title <TAB> fingerprint <TAB> machine.
# Comments and blank lines are ignored; a row with no title is a MALFORMED finding
# (rc 2) rather than a silently dropped key — a declaration that does nothing is the
# worst kind of declaration.
vault_declared_rows() {  # [file] — a missing file prints nothing and exits 3
  local file=${1-} yaml=""
  if [ -z "$file" ]; then vault_recipients_yaml yaml || return 3; file="$yaml"; fi
  [ -r "$file" ] || return 3
  python3 - "$file" <<'PY'
import re, sys
path = sys.argv[1]
rows, cur, section, top = [], None, None, {}
try:
    lines = open(path, errors="replace").read().splitlines()
except OSError:
    sys.exit(3)

def flush():
    global cur
    if cur is not None:
        rows.append(cur)
        cur = None

for raw in lines:
    line = raw.split("#", 1)[0].rstrip()
    if not line.strip():
        continue
    indent = len(line) - len(line.lstrip())
    s = line.strip()
    if indent == 0:
        flush()
        if s.endswith(":"):
            section = s[:-1].strip()
        else:
            k, _, v = s.partition(":")
            top[k.strip()] = v.strip()
        continue
    if section != "recipients":
        continue
    if s.startswith("- "):
        flush()
        cur = {}
        s = s[2:].strip()
        if not s:
            continue
    if cur is None:
        cur = {}
    k, _, v = s.partition(":")
    cur[k.strip().lower()] = v.strip()
flush()

bad = 0
out = sys.stdout
for r in rows:
    title = (r.get("title") or "").strip()
    fp = (r.get("fingerprint") or "").strip()
    machine = (r.get("machine") or "").strip()
    if not title and not fp:
        bad = 1
        print("vault-identity: a recipient has neither title nor fingerprint — it declares nothing",
              file=sys.stderr)
        continue
    if not title:
        bad = 1
        print("vault-identity: a recipient carries a fingerprint but no title — name it",
              file=sys.stderr)
        continue
    out.write("\t".join([title, fp, machine]) + "\n")
sys.exit(1 if bad else 0)
PY
}

# One top-level value (`vault:` · `identity:` · `login:`), from the same parser shape.
vault_declared_top() {  # <file> <key>
  local file=${1-} want=${2-}
  [ -r "$file" ] && [ -n "$want" ] || return 1
  python3 - "$file" "$want" <<'PY'
import sys
path, want = sys.argv[1], sys.argv[2]
try:
    lines = open(path, errors="replace").read().splitlines()
except OSError:
    sys.exit(1)
for raw in lines:
    line = raw.split("#", 1)[0].rstrip()
    if not line.strip() or len(line) != len(line.lstrip()):
        continue
    k, _, v = line.partition(":")
    if k.strip() == want:
        print(v.strip())
        sys.exit(0)
sys.exit(1)
PY
}

# The SHA256 fingerprint of a public key, exactly as ssh-keygen writes it: the second
# field of `ssh-keygen -lf`. Two keys with the same fingerprint are the same key, which
# is why the declaration carries one: a TITLE can be reused, a fingerprint cannot.
vault_pub_fingerprint() {  # <file> | -
  local file=${1-}
  [ -n "$file" ] || return 2
  if [ "$file" = "-" ]; then
    ssh-keygen -lf - 2>/dev/null | awk '{print $2}'
  else
    [ -r "$file" ] || return 1
    ssh-keygen -lf "$file" 2>/dev/null | awk '{print $2}'
  fi
}
