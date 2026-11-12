#!/usr/bin/env bash
# test_people_guard_people.sh — plan 272 fault 11: the people ward reads handles and rosters, not only names.
# Invented people only (Fenwick Ostrander). The ward is run from a copy outside any .yggdrasil path.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; }
mkdir -p "$T/repo/bin/gates/guards" "$T/repo/bin/vault" "$T/repo/docs" "$T/repo/config" "$T/h/hodd/identity" "$T/h/hodd/data/telegram-rosters"
cp "$ROOT/bin/gates/guards/people-guard.sh" "$ROOT/bin/gates/guards/ndalib.py" "$T/repo/bin/gates/guards/"
cp "$ROOT/bin/vault/hoard-lib.sh" "$T/repo/bin/vault/"
printf 'people:\n- name: Fenwick Ostrander\n  emails: [fostrander@example.test]\n  telegram: [fen_ostr_chat]\n' >"$T/h/hodd/identity/collaborators.yaml"
printf 'speakers:\n  - {name: "Tamsin Quillfeather", username: tquill_rost}\n' >"$T/h/hodd/data/telegram-rosters/-1.yaml"
G="$T/repo/bin/gates/guards/people-guard.sh"
echo 'a clean page' >"$T/repo/docs/a.md"
out="$(YMIR_HOME="$T/h" bash "$G" check 2>&1)"; printf '%s' "$out" | grep -q 'owed' && bad "clean tree reports owed" || ok "a clean tree reports nothing owed"
for who in fen_ostr_chat fostrander tquill_rost "Tamsin Quillfeather"; do
  echo "line with $who inside" >"$T/repo/docs/a.md"
  out="$(YMIR_HOME="$T/h" bash "$G" check 2>&1)"
  printf '%s' "$out" | grep -qE 'owed|a person from the registries' && ok "the ward sees $who" || bad "the ward misses $who"
done
printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
