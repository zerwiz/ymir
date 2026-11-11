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
exec python3 "$DIR/atlas.py" "$@"
