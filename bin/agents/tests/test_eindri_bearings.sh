#!/usr/bin/env bash
# test_eindri_bearings.sh — the four things a brief's bearings must carry (plan 291 part 2).
#
# The rule: every errand's brief opens with the fixed core (shipped template + the home's overlay),
# its project's records, and the home's document map — and a project with no `records:` block says
# so plainly instead of inventing a path.
#
# FENCED FROM THE REAL MACHINE: this test builds a PLANTED home in a temp directory and points
# YMIR_HOME at it, so no real registry, no real plan and no real secret is read or written.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
door="$root/bin/agents/eindri-bearings.sh"
core="$root/.agents/assets/agents/eindri-core.md"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0
ok()  { printf '  ok   %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }
out=""; rc=0
run() { out="$(env YMIR_HOME="$home" "$@" 2>&1)"; rc=$?; }

echo "test_eindri_bearings"
[ -x "$door" ] || { bad "the door is not executable: $door"; exit 1; }

# ---- the planted home: one project WITH records, one WITHOUT -------------------------------
home="$tmp/home"
proj="$tmp/projects/planted"
mkdir -p "$home/hodd/identity" "$home/hodd/docs" "$home/state/eindri-reports" "$home/config" "$proj"
cat >"$home/hodd/identity/projects.yaml" <<YAML
projects:
  - id: planted
    name: Planted
    realm: work
    local_clone: $proj
    records:
      in_repo:
        decisions: docs/DECISIONS.md
        plans: plans/
      in_home:
        meetings: svartalfaheim/work/meetings/
      boards:
        development: https://example.invalid/board
      merges: the planted reviewer
  - id: bare
    name: Bare
    realm: work
    local_clone: $proj
YAML
cat >"$home/.ymir-layout.yaml" <<YAML
version: 1
layout:
  config: "\$YMIR_HOME/config"
  memory: "\$YMIR_HOME/hodd/memory"
YAML
printf '# the knowledge shelf\n' >"$home/hodd/docs/INDEX.md"
# the home's own overlay — a sentinel no shipped file may carry
printf '# this fleet\n\n- the sentinel: OVERLAY-SENTINEL-4242\n' >"$home/config/eindri-core.md"

# 1 · the shipped core is in the section
run "$door" planted
[ "$rc" = 0 ] && ok "the door prints a section for a registered project" || bad "the door failed: $out"
case "$out" in *"Two repositories, two laws"*) ok "the SHIPPED core is carried" ;;
  *) bad "the shipped core is missing from the section" ;; esac

# 2 · the home's overlay is carried, after it
case "$out" in *"OVERLAY-SENTINEL-4242"*) ok "the home's overlay is carried" ;;
  *) bad "the home's overlay is missing from the section" ;; esac
case "$out" in *"This fleet's overlay"*) ok "the overlay is named as the fleet's own word" ;;
  *) bad "the overlay is not introduced" ;; esac

# 3 · the project's records, each with the duty
case "$out" in *"docs/DECISIONS.md"*) ok "the project's decisions path is carried" ;;
  *) bad "the project's decisions path is missing" ;; esac
case "$out" in *"https://example.invalid/board"*) ok "the project's board is carried" ;;
  *) bad "the project's board is missing" ;; esac
case "$out" in *"read before you write, update before your report"*) ok "the records carry the duty" ;;
  *) bad "the duty line is missing" ;; esac

# 4 · a project with no records block: said plainly, and the registry row named — never a guess
run "$door" bare
[ "$rc" = 0 ] && ok "a project with no records still gets a section" || bad "the bare project failed: $out"
case "$out" in *'no `records:` block'*) ok "the section says the project has no records block" ;;
  *) bad "the missing records block was not said" ;; esac
case "$out" in *"id: bare"*) ok "the section names the registry row to add it to" ;;
  *) bad "the section did not name the row" ;; esac
case "$out" in *"DECISIONS.md"*) bad "the door INVENTED a path for a project with no records" ;;
  *) ok "no path is invented for a project with no records" ;; esac

# 5 · the home's document map: the layout shelves, the index, the report shelf
case "$out" in *"\$YMIR_HOME/hodd/memory"*|*"$home/hodd/memory"*) ok "the layout shelves are carried" ;;
  *) bad "the layout shelves are missing" ;; esac
case "$out" in *"hodd/docs/INDEX.md"*) ok "the knowledge index is carried" ;;
  *) bad "the knowledge index is missing" ;; esac
case "$out" in *"state/eindri-reports/"*) ok "the report shelf is carried" ;;
  *) bad "the report shelf is missing" ;; esac

# 6 · the marker, so a brief is never doubled by two roads adding the section
run "$door" --marker
[ "$rc" = 0 ] && [ -n "$out" ] && ok "the door names the marker a brief is tested against" || bad "no marker"
case "$(cat "$door")" in *"eindri-bearings:v1"*) ok "the marker is the same one the brief is built with" ;;
  *) bad "the marker is not the one the door writes" ;; esac

# 7 · the shipped core is AGNOSTIC: no home path, no machine, no operator
if grep -qE '/home/|/Users/|heimdall|nidavellir|w[0-9]+:p' "$core"; then
  bad "the shipped core carries a machine, a pane or a private path"
else
  ok "the shipped core carries no machine, pane or private path"
fi

printf 'test_eindri_bearings: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ] || exit 1
