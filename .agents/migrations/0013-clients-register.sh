#!/usr/bin/env bash
# 0013-clients-register — give an existing home the clients register, so a company we serve
# is never filed as one we are.
#
# Before this migration a client-shaped company had nowhere to live: companies.yaml held the
# houses we ARE, collaborators.yaml held people, projects.yaml held repos. A company we SERVE
# was written as if it were a house — which is how Inmost Invest ended up with `status: forming`
# and its owner listed as a member.
#
# This migration copies the clients register from the template when absent. It never invents
# a client, never edits a register it finds, and never touches companies.yaml.
#
# Idempotent: it skips if the register exists, and it never edits content it finds.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
ymir_home_root HOME_R 2>/dev/null || true
[ -n "${HOME_R:-}" ] || { echo "0013: the hoard is unresolved — nothing touched"; exit 0; }

CLIENTS_FILE="$HOME_R/hodd/identity/clients.yaml"
TEMPLATE="$ROOT/registry/clients.yaml.example"

if [ ! -f "$CLIENTS_FILE" ]; then
  if [ ! -f "$TEMPLATE" ]; then
    echo "0013: template not found at $TEMPLATE — nothing seeded"
    exit 0
  fi
  mkdir -p "$HOME_R/hodd/identity"
  cp "$TEMPLATE" "$CLIENTS_FILE"
  echo "0013: clients register seeded at $CLIENTS_FILE"
else
  echo "0013: clients register already exists at $CLIENTS_FILE — nothing to do"
fi
