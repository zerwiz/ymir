#!/usr/bin/env bash
# test_project_registry_reads.sh — project.sh answers from handling: only, and a schema-valid list of strings never crashes a cell (plan 345.1 rework).
# Runs against a fixture registry in a temporary directory; the live registry is never read.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PS="$HERE/../bin/records/project.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0
ok(){ printf 'ok   %s\n' "$1"; }; bad(){ printf 'FAIL %s\n' "$1"; fail=1; }
cat > "$T/p.yaml" <<'Y'
projects:
  - id: demo
    name: Demo
    delivery: reviewer-merges
    board: legacy-board
    handling:
      visibility: {value: public}
      keepers: {value: ["alpha", "beta"]}
      delivery: {road: pr}
Y
out="$("$PS" demo --field delivery --registry "$T/p.yaml" 2>&1)"; rc=$?
[ $rc -eq 0 ] && ok "handling delivery answers" || bad "handling delivery rc=$rc"
case "$out" in *reviewer-merges*) bad "top-level delivery leaked: $out";; *) ok "top-level delivery never answers";; esac
out="$("$PS" demo --field board --registry "$T/p.yaml" 2>&1)"; rc=$?
[ $rc -eq 1 ] && ok "absent handling field exits 1" || bad "absent field rc=$rc"
case "$out" in *"no field 'board'"*) ok "the message names the field";; *) bad "message: $out";; esac
case "$out" in *legacy-board*) bad "top-level board leaked";; esac
out="$("$PS" --page --registry "$T/p.yaml" 2>&1)"; rc=$?
[ $rc -eq 0 ] && ok "string-list keepers do not crash --page" || bad "page rc=$rc: $out"
exit $fail
