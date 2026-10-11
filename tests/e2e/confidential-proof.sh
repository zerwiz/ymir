#!/usr/bin/env bash
# confidential-proof.sh — Rule 16's boundary, proven offline.
#
# A proof is a command, not a claim. This stands a directory in for the vault mount
# and a live session marker (via YMIR_STATE_DIR), then asserts the guard's behaviour:
#   1. no session  -> clean
#   2. session live, a file staged OUTSIDE the vault -> REFUSED
#   3. session live, a file staged INSIDE the vault  -> allowed
#
#   tests/e2e/confidential-proof.sh
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GUARD="$ROOT/bin/gates/guards/confidential-guard.sh"
DOOR="$ROOT/bin/vault/confidential.sh"
[ -x "$GUARD" ] || { printf 'confidential-proof[1]{case,result}:\n  "missing","%s"\n' "$GUARD"; exit 1; }

fail=0
ok()  { printf '  "ok","%s"\n' "$1"; }
bad() { printf '  "FAIL","%s"\n' "$1"; fail=1; }
printf 'confidential-proof[1]{case,result}:\n'

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
MOUNT="$TMP/vault"; STATE="$TMP/state"; OUTREPO="$TMP/outside"; INREPO="$MOUNT/proj"
mkdir -p "$MOUNT" "$STATE" "$OUTREPO" "$INREPO"
for r in "$OUTREPO" "$INREPO"; do ( cd "$r" && git init -q && git config user.email a@a && git config user.name a ); done
MARKER="$STATE/confidential.session"

run_guard() { ( cd "$1" && YMIR_STATE_DIR="$STATE" bash "$GUARD" check >/dev/null 2>&1 ); }

# 1. no session -> clean
run_guard "$OUTREPO" && ok "no session: clean" || bad "no session refused a file"

# 2. session live, file OUTSIDE the vault -> refused
printf 'mount=%s\ntier=local\n' "$MOUNT" > "$MARKER"
printf 'outside\n' > "$OUTREPO/x.txt"; ( cd "$OUTREPO" && git add x.txt )
run_guard "$OUTREPO" && bad "a file outside the vault was allowed in a session" \
  || ok "a file outside the vault is refused in a session"

# 3. session live, file INSIDE the vault -> allowed
printf 'inside\n' > "$INREPO/y.txt"; ( cd "$INREPO" && git add y.txt )
run_guard "$INREPO" && ok "a file inside the vault is allowed in a session" \
  || bad "a file inside the vault was refused"

# 4. the door reports status honestly
if [ -x "$DOOR" ]; then
  out="$(YMIR_STATE_DIR="$STATE" YMIR_VAULT_MNT="$MOUNT" bash "$DOOR" status 2>/dev/null)"
  printf '%s' "$out" | grep -q '"live"' && ok "the door reports the session live" \
    || bad "door status: $out"
fi

# 5. the sealed one-shot runs through Utgard (read-only rootfs, only the workdir, no net)
if command -v docker >/dev/null 2>&1 && docker image inspect utgard-runner:latest >/dev/null 2>&1; then
  out="$(YMIR_STATE_DIR="$STATE" YMIR_VAULT_MNT="$MOUNT" YMIR_CONFIDENTIAL_ASSUME_OPEN=1 \
         bash "$DOOR" start --sandbox --tier none --name proof -- echo SANDBOX_OK 2>/dev/null)"
  printf '%s' "$out" | grep -q 'SANDBOX_OK' && ok "the Utgard sandbox one-shot ran" \
    || bad "sandbox run: $out"
else
  ok "Utgard image absent — sandbox case skipped (bwrap airlock still available)"
fi

[ "$fail" = 0 ] && { printf '  "ok","all confidential proofs passed"\n'; exit 0; }
printf '  "FAIL","confidential proofs failed"\n'; exit 1
