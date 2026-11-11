#!/usr/bin/env bash
# atlas.sh — one page at the top of the home that says where we have it all (plan 251).
#
#   atlas.sh               write $YMIR_HOME/hodd/ATLAS.md from the registries and the realm folders
#   atlas.sh --stdout      print it instead
#   atlas.sh --check       exit 1 when a registry names a realm with no folder
#   atlas.sh --self-test   the proofs (a fixture home)
#
# A rendered view (RULES/34): the registries (hodd/identity/companies.yaml, projects.yaml) are the truth.
set -eu
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR" && while [ ! -d "$PWD/RULES" ] || [ ! -d "$PWD/bin" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)"
# The home is resolved, never assumed (RULES/07): the one resolver is bin/vault/hoard-lib.sh.
if [ -z "${YMIR_HOME:-}" ] && [ -r "$ROOT/bin/vault/hoard-lib.sh" ]; then
  . "$ROOT/bin/vault/hoard-lib.sh" >/dev/null 2>&1 || true
  if command -v ymir_home_root >/dev/null 2>&1; then H=""; ymir_home_root H; [ -n "$H" ] && export YMIR_HOME="$H"; fi
fi
exec python3 "$DIR/atlas.py" "$@"
