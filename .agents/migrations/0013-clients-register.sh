#!/usr/bin/env bash
# 0013-clients-register — give an existing home the CLIENTS register: the companies it SERVES.
#
# Before this migration a client had nowhere to live in the home: the only client-shaped
# realm it carried — inmostinvest — sat in `companies.yaml` as a house with its owner listed
# among the members, the relationship living only in prose. This migration creates the
# register from the shipped template when it is ABSENT, and does nothing else.
#
# It NEVER edits a register it finds (the operator's clients are his word, not a script's),
# NEVER invents a client, and does NOT touch companies.yaml: re-filing a house as a client
# is a decision, and the decision is the Allfather's.
#
# Idempotent: it creates, or it says why it did nothing.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
ymir_home_root HOME_R 2>/dev/null || true
[ -n "${HOME_R:-}" ] || { echo "0013: the hoard is unresolved — nothing touched"; exit 0; }
ID="$HOME_R/hodd/identity"
REGISTER="$ID/clients.yaml"
TEMPLATE="$ROOT/registry/clients.yaml.example"
if [ -f "$REGISTER" ]; then
  echo "0013: clients register already stands at $REGISTER — nothing touched (an existing register is never edited)"
  exit 0
fi
if [ ! -f "$TEMPLATE" ]; then
  echo "0013: no template at $TEMPLATE — nothing created; the register stays absent until the operator writes it"
  exit 0
fi
mkdir -p "$ID"
cp "$TEMPLATE" "$REGISTER"
echo "0013: clients register seeded at $REGISTER from registry/clients.yaml.example (no client invented)"
