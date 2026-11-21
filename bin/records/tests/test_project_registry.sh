#!/usr/bin/env bash
# test_project_registry.sh — the reader of how every project is handled (plan 345), proven on a fixture registry.
#
# WHY. Workers learned by guessing which repos are public, where plans live, which board, and who merges — and a
# judge once had to stop at APPROVE on a repo whose own rule says only a person merges. One door now answers from
# the registry's `handling:` block. This test proves the door reads a field, walks a dotted path, keeps the older
# top-level keys separate, audits what is missing, rejects a value outside the schema, and renders the page.
# Every name below is invented (RULES/04); nothing reads the operator's home.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DOOR="$ROOT/bin/records/project.sh"
pass=0; fail=0
t() { local n="$1"; shift; if "$@"; then printf '  ok   %s\n' "$n"; pass=$((pass+1)); else printf '  FAIL %s\n' "$n"; fail=$((fail+1)); fi; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cat >"$T/projects.yaml" <<'YAML'
projects:
- id: alpha
  name: Alpha App
  delivery: reviewer-merges        # the older top-level switch the shipper reads — must stay its own
  handling:
    visibility: {value: public, remote: example-org/alpha, source: gh repo view example-org/alpha}
    plans: {where: repo, path: plans/, source: the repo tree}
    board: {engine: plane, place: example/Alpha, write: house, source: list_places}
    people:
      members: [{id: ada, role: owner}, {account: bob-dev, role: developer}]
      source: forge collaborators
    private_to: {status: OWED, owed_by: the operator}
    delivery: {road: judge-merges, merge_account: example-op, ci: "yes", required_checks: [whole-tree], source: RULES/08}
    deploy: {where: host-a, how: scripts/deploy.sh, needs_word: "yes", source: the repo tree}
    secrets: {keys: [ALPHA_TOKEN], source: vault key names}
    licence: {value: MIT, source: forge licence}
    toolchain: {value: {languages: [Python], package_manager: [uv]}, source: manifests}
    lifecycle: {status: OWED, owed_by: the operator}
- id: beta
  name: Beta
  handling:
    visibility: unmeasured
    plans: {where: home, path: realm/beta/plans/, source: the home ledger}
    delivery: {road: person-merges, ci: "no", extra_rules: [RULES/15], source: the repo's RULES/15}
- id: gamma
  name: Gamma
YAML

R=(--registry "$T/projects.yaml")
out="$(bash "$DOOR" "${R[@]}" alpha --field delivery.road)"
t "a dotted field answers one word"                       [ "$out" = "judge-merges" ]
out="$(bash "$DOOR" "${R[@]}" alpha --field delivery)"
t "a whole field prints its road and its source"          bash -c "grep -q 'road: judge-merges' <<<\"\$0\" && grep -q 'source: RULES/08' <<<\"\$0\"" "$out"
out="$(bash "$DOOR" "${R[@]}" 'Alpha App' --field visibility.value)"
t "a project is found by its name too"                    [ "$out" = "public" ]
out="$(bash "$DOOR" "${R[@]}" alpha --field private_to --json)"
t "OWED reads as OWED, never as an answer"                bash -c "grep -q '\"OWED\"' <<<\"\$0\"" "$out"
out="$(bash "$DOOR" "${R[@]}" alpha --field name)"
t "a top-level key answers when handling lacks it"        [ "$out" = "Alpha App" ]
bash "$DOOR" "${R[@]}" alpha --field nothing-here >/dev/null 2>&1; rc=$?
t "a missing field exits 1"                               [ "$rc" -eq 1 ]
bash "$DOOR" "${R[@]}" nobody >/dev/null 2>&1; rc=$?
t "an unknown project exits 2"                            [ "$rc" -eq 2 ]

out="$(bash "$DOOR" "${R[@]}" --audit)"; rc=$?
t "the audit fails while a row lacks the three"           [ "$rc" -eq 1 ]
t "the audit names the row and what it lacks"             bash -c "grep -q 'gamma: no visibility, plans, delivery' <<<\"\$0\"" "$out"
t "the audit counts unmeasured and OWED"                  bash -c "grep -q 'values marked unmeasured: 1' <<<\"\$0\" && grep -q 'private_to OWED by the operator: 1' <<<\"\$0\"" "$out"

# a value outside the schema is a finding, named by row and field
sed 's/road: person-merges/road: whoever/' "$T/projects.yaml" | grep -v '^- id: gamma' | grep -v '^  name: Gamma' >"$T/bad.yaml"
out="$(bash "$DOOR" --registry "$T/bad.yaml" --audit)"; rc=$?
t "a road outside the schema is red, by row and field"    bash -c "[ $rc -eq 1 ] && grep -q 'beta: handling.delivery' <<<\"\$0\"" "$out"

grep -v '^- id: gamma' "$T/projects.yaml" | grep -v '^  name: Gamma' >"$T/good.yaml"
bash "$DOOR" --registry "$T/good.yaml" --audit --quiet >/dev/null; rc=$?
t "a whole registry audits green"                         [ "$rc" -eq 0 ]

page="$(bash "$DOOR" "${R[@]}" --page)"
t "the page is one table with a column per question"      bash -c "grep -q '^| Project | Public? | Plans live | Board | People | Private to | Who merges' <<<\"\$0\"" "$page"
t "the page shows the road and the fourteen"              bash -c "grep -q 'judge-merges as example-op' <<<\"\$0\" && grep -q '## The fourteen' <<<\"\$0\"" "$page"

lst="$(bash "$DOOR" "${R[@]}" --list)"
t "the list has one line per row"                         [ "$(printf '%s\n' "$lst" | wc -l)" -eq 3 ]

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
