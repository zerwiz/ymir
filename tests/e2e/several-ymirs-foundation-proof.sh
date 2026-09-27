#!/usr/bin/env bash
# several-ymirs-foundation-proof.sh — plan 58's federation foundation, proven offline.
#
# A proof is a command, not a claim. This drives the grants law and the
# namespace-scoped journal against synthetic fixtures, so it needs no heart and
# no network, and asserts:
#   1. a signed, cross-operator grant pair            -> validates
#   2. the same grant with one Heimdall's signature  -> REFUSED, naming the Heimdall
#      removed                                          that did not sign
#   3. a company-namespaced journal entry            -> folds into its namespace only
#   4. the typed-card contract (packages/contracts)   -> aligned when it has landed,
#      dependency declared when it has not
#
#   tests/e2e/several-ymirs-foundation-proof.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHECK="$ROOT/bin/ymir-config-check.sh"
APPEND="$ROOT/bin/journal-append.sh"
RECEIVE="$ROOT/bin/journal-receive.sh"
for f in "$CHECK" "$APPEND" "$RECEIVE"; do
  [ -f "$f" ] || { printf 'proof[1]{gate,result}:\n  "missing","%s"\n' "$f"; exit 1; }
done

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fail=0
ok()  { printf '  "%s","PASS"\n' "$1"; }
bad() { printf '  "%s","FAIL","%s"\n' "$1" "$2"; fail=1; }

printf 'several_ymirs_proof[4]{gate,result,detail}:\n'

# ── 1 + 2. the grants law ────────────────────────────────────────────────────
cat >"$TMP/grants.yaml" <<'YAML'
version: 1
operator: proof-operator-a
grants:
  - grant_id: "proof-grant-0001"
    namespace: example-project
    role: member
    state: active
    grantor:
      ymir: proof-a
      operator: proof-operator-a
      heimdall: heimdall-a
      card: {protocol: "a2a/1.0", endpoint: "http://proof-a:8301/", signed: true}
    grantee:
      ymir: proof-b
      operator: proof-operator-b
      heimdall: heimdall-b
      card: {protocol: "a2a/1.0", endpoint: "http://proof-b:8301/", signed: true}
    signatures:
      - {signer: heimdall-a, alg: ed25519, key_id: heimdall-a-key, sig: c2ln}
      - {signer: heimdall-b, alg: ed25519, key_id: heimdall-b-key, sig: c2ln}
YAML
mkdir -p "$TMP/unsigned"
sed '/key_id: heimdall-b-key/d' "$TMP/grants.yaml" >"$TMP/unsigned/grants.yaml"

if out="$(bash "$CHECK" validate "$TMP/grants.yaml" 2>&1)" && printf '%s' "$out" | grep -q '"ok"'; then
  ok "a signed cross-operator grant validates"
else
  bad "signed grant refused" "$out"
fi

rc=0; out="$(bash "$CHECK" validate "$TMP/unsigned/grants.yaml" 2>&1)" || rc=$?
if [ "$rc" != 0 ] && printf '%s' "$out" | grep -q "'heimdall-b'"; then
  ok "a cross-operator grant missing a signature is refused, naming heimdall-b"
else
  bad "unsigned grant not refused" "rc=$rc $out"
fi

# ── 3. the namespace-scoped journal ──────────────────────────────────────────
export BROKK_STATE_OVERRIDE="$TMP/state"
export YMIR_JOURNAL_INBOX="$TMP/inbox"
export YMIR_HOST=proofbody
mkdir -p "$TMP/inbox"
bash "$APPEND" --op note --data '{"own":1}' >/dev/null 2>&1
bash "$APPEND" --op note --namespace example-project --data '{"shared":1}' >/dev/null 2>&1
cp "$TMP/state/journal/proofbody.jsonl" "$TMP/inbox/proofbody.jsonl"
out="$(bash "$RECEIVE" 2>/dev/null)"
own="$TMP/state/journal/folded/proofbody.jsonl"
scoped="$TMP/state/journal/folded/example-project/proofbody.jsonl"
if [ "$(wc -l <"$own" 2>/dev/null | tr -d '[:space:]')" = "1" ] \
   && [ "$(wc -l <"$scoped" 2>/dev/null | tr -d '[:space:]')" = "1" ] \
   && printf '%s' "$out" | grep -q 'folded 2 new'; then
  ok "a namespaced entry folds into its namespace only (own=1, scoped=1)"
else
  bad "namespace fold wrong" "$out own=$(cat "$own" 2>/dev/null) scoped=$(cat "$scoped" 2>/dev/null)"
fi

# ── 4. typed-card alignment (gated on the Phase 6 contract) ──────────────────
if [ -f "$ROOT/packages/contracts/src/agent-card.ts" ]; then
  fields_ok=1
  for field in protocol endpoint signed; do
    grep -q "$field" "$ROOT/packages/contracts/src/agent-card.ts" || fields_ok=0
    grep -q "\"$field\"" "$ROOT/config/grants.schema.json" || fields_ok=0
  done
  if [ "$fields_ok" = 1 ]; then
    ok "the grants card block matches the shared AgentInterface contract"
  else
    bad "card block drifted from the shared contract" "packages/contracts AgentInterface vs config/grants.schema.json"
  fi
else
  ok "typed-card dependency declared: phase6 packages/contracts not yet on this tree (gate holds; see the fix note)"
fi

printf 'several_ymirs_proof_verdict[1]{verdict,detail}:\n'
if [ "$fail" = 0 ]; then
  printf '  "pass","grants law + namespace-scoped journal proven"\n'
else
  printf '  "fail","see the FAIL row above"\n'
fi
exit "$fail"
