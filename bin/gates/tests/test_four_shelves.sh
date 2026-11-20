#!/usr/bin/env bash
# test_four_shelves.sh — the readers work with the ONE-CYCLE LINKS REMOVED (plan 331.6, 331.8).
#
# Plan 331 split the home into four shelves — `hodd/` the record, `life/` the operator's own material,
# `state/` runtime state, `config/` settings — and retired the three old sub-shelves of the record.
# Migration 0026 left a compatibility link from each old path to its new shelf for one release cycle,
# and a reader that still spelled an old path kept working only because of them.
# (retired-path-ok: the two lines that must name the old paths are below, each with its own reason.)
#
# This test builds a home with the links ABSENT — the state of every home after the links are retired — and
# asks the three doors the Allfather named to read it:
#
#   1. bin/voice/todos.sh --digest    reads HIS list, and counts the voice's ledger
#   2. bin/day/day.py acts            reads HIS list
#   3. bin/agents/eir-doctor.sh check the `hoard` surface is clean on a four-shelf home …
#      … and still REFUSES a home that kept the operator's material inside the record
#
# A reader that names a retired path fails here, which is the whole point: the link is the compatibility
# shim, never the reason a door works.
#
#   bash bin/gates/tests/test_four_shelves.sh        # exits 0 when every reader answers from the shelves
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
H="$T/home"
PASS=0 FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$*"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$*"; }

printf 'test_four_shelves\n'

# ── a home in the four-shelf shape, with NO compatibility links ────────────────────────────────────
mkdir -p "$H/hodd/identity/companies" "$H/hodd/data" "$H/hodd/memory/daily" "$H/hodd/docs" \
         "$H/hodd/secrets" "$H/life/personal/me" "$H/state/voice" "$H/config" "$H/svartalfaheim"
: > "$H/hodd/memory/runes_audit.md"
printf '# His acts\n\n# His half — what only he can do\n\n## Today\n\n- [ ] **call the broker** — unblocks it\n- [ ] **sign the lease** — unblocks the move\n' \
  > "$H/life/personal/me/todo.md"
printf '{"id":"v1","action":"add","item":"a voiced item","ts":"2026-11-20T09:00:00Z"}\n' > "$H/state/voice/todos.jsonl"
cat > "$H/.ymir-layout.yaml" <<YAML
layout:
  config: "$H/config"
  secrets: "$H/hodd/secrets"
  identity: "$H/hodd/identity"
  memory: "$H/hodd/memory"
  state: "$H/state"
  data: "$H/hodd/data"
  svartalfaheim: "$H/svartalfaheim"
git_repo: "$H"
YAML

[ -e "$H/hodd/life" ] && bad "the fixture still holds a hodd/life (retired-path-ok: the fixture ASSERTS its absence)" \
  || ok "the fixture holds no compatibility link: no retired old shelf, no state link"

# ── the doors ──────────────────────────────────────────────────────────────────────────────────────
digest="$(YMIR_HOME="$H" bash "$ROOT/bin/voice/todos.sh" --digest 2>&1)"
case "$digest" in
  *"his half 2"*) ok "todos.sh reads HIS list off the life/ shelf" ;;
  *) bad "todos.sh did not read the life/ shelf — $digest" ;;
esac
case "$digest" in
  *"voice ledger 1"*) ok "todos.sh reads the ledger off the state/ shelf" ;;
  *) bad "todos.sh did not read state/voice — $digest" ;;
esac

acts="$(YMIR_HOME="$H" python3 "$ROOT/bin/day/day.py" acts 2>&1)"
case "$acts" in
  *"call the broker"*) ok "day.py reads HIS list off the life/ shelf" ;;
  *) bad "day.py did not read the life/ shelf — $acts" ;;
esac

# Eir, asked ONE surface: the `hoard` register is the seam that lets a check name a single surface.
printf 'version: 1\nsurfaces:\n  - { name: hoard, risk: ask, roles: all, why: "test" }\n' > "$T/one.yaml"
eir="$(YMIR_HOME="$H" YMIR_EIR_REGISTER="$T/one.yaml" bash "$ROOT/bin/agents/eir-doctor.sh" check 2>&1)"
case "$eir" in
  *'"hoard","ok"'*) ok "eir-doctor finds a four-shelf home clean" ;;
  *) bad "eir-doctor refused a four-shelf home — $eir" ;;
esac

mkdir -p "$H/hodd/life/personal"     # retired-path-ok: the test must create the old shelf to be refused
eir2="$(YMIR_HOME="$H" YMIR_EIR_REGISTER="$T/one.yaml" bash "$ROOT/bin/agents/eir-doctor.sh" check 2>&1)"
case "$eir2" in
  *"the operator's own material inside the record"*)
    ok "eir-doctor still refuses the operator's material left inside the record" ;;
  *) bad "eir-doctor no longer refuses a home that kept the old shelf — $eir2" ;;
esac
rmdir "$H/hodd/life/personal" "$H/hodd/life"    # retired-path-ok: the fixture ASSERTED its absence

printf 'test_four_shelves: %s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
