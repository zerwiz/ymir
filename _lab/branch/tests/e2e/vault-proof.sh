#!/usr/bin/env bash
# vault-proof.sh — Hnitbjörg's contract, proven offline (no LUKS, no passphrase).
#
# A proof is a command, not a claim. This drives the vault door and its ensure
# surface against a throwaway vault dir, so it creates no container, touches no
# real home, and asks for no passphrase. It asserts:
#   1. the `--version` and `--help` fast paths answer
#   2. a fresh vault is ABSENT and `status` says so (never silently "ready")
#   3. `open` refuses when no vault exists (no surprise)
#   4. `init` refuses to overwrite an existing container (never destructive)
#   5. the ensure surface reports the tooling (cryptsetup)
#
#   tests/e2e/vault-proof.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOOR="$ROOT/bin/vault/hnitbjorg.sh"
ENS="$ROOT/bin/vault/hnitbjorg-ensure.sh"
[ -x "$DOOR" ] || { printf 'vault-proof[1]{case,result}:\n  "missing","%s"\n' "$DOOR"; exit 1; }
[ -x "$ENS" ]  || { printf 'vault-proof[1]{case,result}:\n  "missing","%s"\n' "$ENS"; exit 1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export YMIR_VAULT_DIR="$TMP/vault"
export YMIR_VAULT_MNT="$TMP/mnt"

fail=0
ok()   { printf '  "ok","%s"\n' "$1"; }
bad()  { printf '  "FAIL","%s"\n' "$1"; fail=1; }
printf 'vault-proof[1]{case,result}:\n'

# 1. fast paths
"$DOOR" --version >/dev/null 2>&1 && ok "version" || bad "version"
"$DOOR" --help    >/dev/null 2>&1 && ok "help"    || bad "help"

# 2. sealed by default — a fresh vault is absent, and status says so
out="$("$DOOR" status 2>/dev/null)"; rc=$?
[ "$rc" = 0 ] && ok "status exits 0 on an absent vault" || bad "status exit ($rc)"
printf '%s' "$out" | grep -q '"absent"' && ok "status reports absent" || bad "status did not say absent"

# 3. open refuses without a vault
"$DOOR" open >/dev/null 2>&1 && bad "open ran without a vault" || ok "open refuses without a vault"

# 4. init never overwrites an existing container
mkdir -p "$YMIR_VAULT_DIR"; printf 'sentinel' > "$YMIR_VAULT_DIR/hnitbjorg.img"
"$DOOR" init >/dev/null 2>&1 && bad "init overwrote an existing container" || ok "init refuses to overwrite"
[ "$(cat "$YMIR_VAULT_DIR/hnitbjorg.img")" = "sentinel" ] && ok "existing container untouched" || bad "container was modified"

# 5. the ensure surface reports the tooling
if command -v cryptsetup >/dev/null 2>&1; then
  "$ENS" status >/dev/null 2>&1 && ok "ensure status (cryptsetup present)" || bad "ensure status"
fi

[ "$fail" = 0 ] && { printf '  "ok","all vault proofs passed"\n'; exit 0; }
printf '  "FAIL","vault proofs failed"\n'; exit 1
