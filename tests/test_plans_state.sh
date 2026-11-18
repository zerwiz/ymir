#!/usr/bin/env bash
# test_plans_state.sh — the plans, as data: done-vs-open is proved, never assumed (plan 298 phase 1-2).
#
# The fault this proves fixed. The Allfather's list had a measured half that was typed by hand and
# stamped `as_of 2026-11-11`, so from the 12th onward it was quietly lying about what was still
# open. The inputs were already on disk — the plans, their headers, the register, the registry of
# shelves — and nothing joined them. `bin/records/plans-state.sh` is that join, and
# `bin/day/day.sh plans` is its read.
#
# Every case runs in a throwaway home built by the door's own `--fixture`, so nothing real is
# touched, and a merged-PR case runs offline against a stub `gh` on PATH.
#
# Exit: 0 every case held · 1 a case failed.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
DOOR="$ROOT/bin/records/plans-state.sh"
DAY="$ROOT/bin/day/day.sh"

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
HOME_FIX="$T/home"
SHELF="$HOME_FIX/svartalfaheim/acme/projects/widget/plans"

fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

# the door writes the fixture home itself, so the test and the self-test cannot drift apart
out="$(bash "$DOOR" --fixture "$HOME_FIX" 2>&1)"
[ -d "$SHELF" ] && ok "the door builds a fixture home" || { bad "no fixture home: $out"; printf '\n%s\n' "$out"; exit 1; }

# a stub `gh` proves the merged-PR road without a network or an account
mkdir -p "$T/bin"
printf '#!/bin/sh\necho %s\n' "'{\"state\":\"MERGED\",\"mergedAt\":\"2026-11-15T00:00:00Z\"}'" > "$T/bin/gh"
chmod +x "$T/bin/gh"

run()  { YMIR_HOME="$HOME_FIX" YMIR_REPO_ROOT="$ROOT" YMIR_OFFLINE=1 bash "$DOOR" "$@" 2>&1; }
rund() { YMIR_HOME="$HOME_FIX" YMIR_REPO_ROOT="$ROOT" YMIR_OFFLINE=1 PATH="$T/bin:$PATH" bash "$DAY" "$@" 2>&1; }

# ── the door's own proof ────────────────────────────────────────────────────────────────────────
out="$(run --self-test)"
[ $? -eq 0 ] && ok "the door's self-test holds" || bad "self-test failed: $out"

# ── done vs open, by every witness ──────────────────────────────────────────────────────────────
json="$(run --json)"
state_of() { printf '%s' "$json" | python3 -c '
import json,sys
d=json.load(sys.stdin)
n=sys.argv[1]
got=[p for p in d["plans"] if p["number"]==n]
print(got[0]["state"] if got else "MISSING")
' "$1"; }

[ "$(state_of 1)" = "open" ] && ok "a plan declaring nothing is open" || bad "001 should be open, is $(state_of 1)"
[ "$(state_of 2)" = "done" ] && ok "a \`state: done\` header closes a plan" || bad "002 should be done, is $(state_of 2)"
[ "$(state_of 3)" = "done" ] && ok "a register row saying done closes a plan" || bad "003 should be done, is $(state_of 3)"
[ "$(state_of 5)" = "blocked" ] && ok "a blocked plan is blocked, not open" || bad "005 should be blocked, is $(state_of 5)"
[ "$(state_of 4)" = "open" ] && ok "a PR nobody asked about leaves its plan open" || bad "004 should stay open, is $(state_of 4)"

# a state it cannot measure is open, NEVER done — the rule the merge gate uses
if printf '%s' "$json" | python3 -c '
import json,sys
d=json.load(sys.stdin)
bad=[p for p in d["plans"] if p["state"]=="done" and not p["evidence"]]
sys.exit(1 if bad else 0)
'; then ok "no plan is called done without a witness"; else bad "a plan is done with no evidence"; fi

# ── the shelf's own word: a folder is a state ───────────────────────────────────────────────────
[ "$(state_of feature-0062)" = "done" ] && ok "a plan filed under done/ is done by the shelf's word" \
  || bad "done/ folder ignored, is $(state_of feature-0062)"
[ "$(state_of bug-0007)" = "open" ] && ok "a plan filed under open/ stays open" || bad "open/ folder misfiled"

# ── what is NOT work: retired references, dated reports, templates ──────────────────────────────
if printf '%s' "$json" | python3 -c '
import json,sys
d=json.load(sys.stdin)
names=" ".join(p["path"] for p in d["plans"])
sys.exit(1 if ("old-plans" in names or "2026-11-15-a-session-report" in names or "0000-short-description" in names) else 0)
'; then ok "a retired plan, a dated report and a template are not listed as open work"
else bad "something that is not work was listed as work"; fi

# ── a shelf the registry names and that is not there says so ────────────────────────────────────
absent="$(printf '%s' "$json" | python3 -c '
import json,sys
d=json.load(sys.stdin)
print(" ".join(s["project"] for s in d["shelves"] if s["state"]=="absent"))
')"
case "$absent" in
  *gadget*) ok "a named shelf that is missing is reported absent, never counted as empty";;
  *) bad "the missing shelf was silent: '$absent'";;
esac
case "$absent" in
  *elsewhere*) ok "a named shelf in a repository that is not on this machine says why";;
  *) bad "an unreachable repository shelf was silent: '$absent'";;
esac

# ── the merged PR is the fourth witness, and only when asked ────────────────────────────────────
out="$(rund plans --done all)"
case "$out" in *"plan(s) done"*feature-0062*) ok "the day door reads what closed";; *) bad "day plans --done printed nothing: $out";; esac
case "$out" in *"the shelf files it under done/"*) ok "the closure carries its witness";; *) bad "the closure carries no witness: $out";; esac

json_pr="$(YMIR_HOME="$HOME_FIX" YMIR_REPO_ROOT="$ROOT" PATH="$T/bin:$PATH" bash "$DOOR" --json --with-prs 2>&1)"
printf '%s' "$json_pr" | python3 -c '
import json,sys
d=json.load(sys.stdin)
four=[p for p in d["plans"] if p["number"]=="4"]
sys.exit(0 if four and four[0]["state"]=="done" and any("PR #77 merged" in e for e in four[0]["evidence"]) else 1)
' && ok "--with-prs closes the plan whose PR merged, carrying the PR as proof" \
  || bad "--with-prs did not close plan 004"

# ── the read: --json names them all, --carry withholds the titles ───────────────────────────────
out="$(rund plans --json)"
printf '%s' "$out" | python3 -c '
import json,sys
d=json.load(sys.stdin)
open_n=sorted(p["number"] for p in d["plans"] if p["state"]=="open")
sys.exit(0 if open_n==["1","4","bug-0007"] else 1)
' && ok "day plans --json names exactly the open plans" || bad "day plans --json named the wrong set"

out="$(rund plans --carry)"
case "$out" in
  *"Client → Project"*|*"A thing nobody finished"*) bad "--carry leaked a plan title";;
  *) ok "--carry withholds plan titles (the private-data rule)";;
esac

# ── --check refuses a collision, and refuses an absent shelf ────────────────────────────────────
out="$(run --check)"; rc=$?
[ "$rc" -eq 1 ] && ok "--check exits 1 on a finding" || bad "--check exited $rc"
case "$out" in *gadget*) ok "--check names the absent shelf";; *) bad "--check missed the absent shelf: $out";; esac

printf '# 002 — a second two\n' > "$SHELF/002-another-two.md"
out="$(run --check)"
case "$out" in *"number 2 is used by 2 files"*) ok "--check names a colliding plan number";; *) bad "--check missed the collision: $out";; esac
rm -f "$SHELF/002-another-two.md"

# ── the generated registry ──────────────────────────────────────────────────────────────────────
out="$(run)"
[ -f "$HOME_FIX/hodd/registry/plans-state.yaml" ] && ok "the door writes hodd/registry/plans-state.yaml" || bad "no registry written: $out"
grep -q "^# GENERATED" "$HOME_FIX/hodd/registry/plans-state.yaml" && ok "the registry says it is generated" || bad "the registry does not say it is generated"
[ -f "$HOME_FIX/hodd/registry/.gitignore" ] && ok "the generated shelf is git-ignored" || bad "the generated shelf is not ignored"
python3 - "$HOME_FIX/hodd/registry/plans-state.yaml" <<'PY' && ok "the registry parses as YAML and carries the counts" || bad "the registry is not valid YAML"
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
assert d["counts"]["total"] == len(d["plans"]), "counts disagree with the plans"
assert d["plans"] and "state" in d["plans"][0]
PY

# ── the door refuses a home with no registry, loudly ────────────────────────────────────────────
empty="$T/empty"
mkdir -p "$empty/hodd/identity"
out="$(YMIR_HOME="$empty" YMIR_REPO_ROOT="$ROOT" bash "$DOOR" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && ok "a home with no projects.yaml is refused, not answered with zero" || bad "a missing registry returned success: $out"

printf '\n%s\n' "$([ "$fail" -eq 0 ] && echo 'plans-state: every case held' || echo 'plans-state: a case failed')"
exit "$fail"
