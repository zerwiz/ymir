#!/usr/bin/env bash
# vault-guard-proof.sh — Rule 15's ward, proven offline (no open vault, no NDA data).
#
# A proof is a command, not a claim. This stands a directory in for an open vault
# mount (the `YMIR_VAULT_GUARD_SRC` seam), stages a file in a throwaway repo, and
# asserts the ward's behaviour:
#   1. a file byte-identical to a vault file is REFUSED
#   2. a file that does not match is allowed
#   3. with the vault sealed (no seam), the ward is clean and says why
#
#   tests/e2e/vault-guard-proof.sh
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GUARD="$ROOT/bin/gates/guards/vault-guard.sh"
[ -x "$GUARD" ] || { printf 'vault-guard-proof[1]{case,result}:\n  "missing","%s"\n' "$GUARD"; exit 1; }

fail=0
ok()  { printf '  "ok","%s"\n' "$1"; }
bad() { printf '  "FAIL","%s"\n' "$1"; fail=1; }
printf 'vault-guard-proof[1]{case,result}:\n'

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
VAULT="$TMP/vault"; REPO="$TMP/repo"
mkdir -p "$VAULT" "$REPO"
printf 'NDA-CONFIDENTIAL-DO-NOT-LEAK\n' > "$VAULT/secret.txt"
( cd "$REPO" && git init -q && git config user.email t@t && git config user.name t )

# 1. a verbatim copy is refused
cp "$VAULT/secret.txt" "$REPO/copied.txt"
( cd "$REPO" && git add copied.txt )
if ( cd "$REPO" && YMIR_VAULT_GUARD_SRC="$VAULT" bash "$GUARD" check >/dev/null 2>&1 ); then
  bad "a verbatim copy of a vault file was allowed"
else
  ok "a verbatim copy of a vault file is refused"
fi

# 2. a file that does not match is allowed
( cd "$REPO" && git rm -q --cached copied.txt && rm -f copied.txt )
printf 'ordinary project code\n' > "$REPO/readme.txt"
( cd "$REPO" && git add readme.txt )
if ( cd "$REPO" && YMIR_VAULT_GUARD_SRC="$VAULT" bash "$GUARD" check >/dev/null 2>&1 ); then
  ok "an ordinary file is allowed"
else
  bad "an ordinary file was refused"
fi

# 3. sealed: clean, and it says so
out="$( cd "$REPO" && YMIR_VAULT_GUARD_SRC="" bash "$GUARD" check 2>/dev/null )"
printf '%s' "$out" | grep -q 'sealed' && ok "a sealed vault is reported, not silently passed" \
  || bad "sealed-vault message: $out"

# 4. NO ARGS scans the staged change — the pre-commit path (a guard that prints
#    help on no args is a guard that never runs).
cp "$VAULT/secret.txt" "$REPO/copied2.txt"
( cd "$REPO" && git add copied2.txt )
if ( cd "$REPO" && YMIR_VAULT_GUARD_SRC="$VAULT" bash "$GUARD" >/dev/null 2>&1 ); then
  bad "no-args (pre-commit) did not scan"
else
  ok "no-args (pre-commit) scans the staged change"
fi

[ "$fail" = 0 ] && { printf '  "ok","all vault-guard proofs passed"\n'; exit 0; }
printf '  "FAIL","vault-guard proofs failed"\n'; exit 1
