#!/usr/bin/env bash
# test_plan_finds_the_shelf.sh — a plan is filed on the shelf of the project named, in any home (2026-11-12).
#
# Found on 2026-11-12: `plan.sh new … --realm R --project P` filed three plans for three other projects into the
# DEFAULT project's ledger, because the shelf was resolved before the arguments were read. It also failed in any
# home without a project of the default name. Every case runs in a throwaway home; nothing real is touched.
# Exit: 0 every case held · 1 a case failed.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
P="$ROOT/bin/records/plan.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
S="$T/svartalfaheim"
mkdir -p "$T/hodd" "$S/acme/projects/widget/plans" "$S/acme/projects/gadget" "$S/acme/projects/shared/plans" \
         "$S/beta/projects/shared/plans" "$S/beta/workspace/tool/plans"
printf '| # | Plan | State |\n|---|---|---|\n' | tee "$S/acme/projects/widget/plans/README.md" \
  "$S/acme/projects/shared/plans/README.md" "$S/beta/projects/shared/plans/README.md" "$S/beta/workspace/tool/plans/README.md" >/dev/null
run() { YMIR_HOME="$T" YMIR_HOARD="$T/hodd" YMIR_OFFLINE=1 YMIR_REALM=elsewhere YMIR_PROJECT=nothing bash "$P" "$@" 2>&1; }
fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

out="$(run new first --title "First" --project widget)"
[ -f "$S/acme/projects/widget/plans/001-first.md" ] && ok "a project is found in its realm without --realm" || bad "widget plan not filed: $out"
grep -q '001-first.md' "$S/acme/projects/widget/plans/README.md" && ok "the index row lands on the same shelf" || bad "no index row"
grep -q '^owner_name: widget' "$S/acme/projects/widget/plans/001-first.md" && ok "the header names the project" || bad "owner_name wrong"

out="$(run new x --title "X" --project shared)"
case "$out" in *"more than one realm"*) ok "a name in two realms is refused";; *) bad "ambiguous name not refused: $out";; esac
out="$(run new x --title "X" --realm beta --project shared)"
[ -f "$S/beta/projects/shared/plans/001-x.md" ] && ok "--realm settles the ambiguity" || bad "--realm ignored: $out"

out="$(run new y --title "Y" --project tool)"
[ -f "$S/beta/workspace/tool/plans/001-y.md" ] && ok "a workspace project is found too" || bad "workspace shelf missed: $out"

out="$(run new z --title "Z" --project nosuch)"
case "$out" in *"no project folder called nosuch"*) ok "an unknown project is refused";; *) bad "unknown project not refused: $out";; esac
out="$(run new z --title "Z" --realm beta --project widget)"
case "$out" in *"in the realm beta"*) ok "an explicit wrong realm is refused, never searched past";; *) bad "wrong realm not refused: $out";; esac

out="$(run new z --title "Z" --project gadget)"
case "$out" in *"--new-shelf"*) ok "a project without a shelf is refused, with the way to open one";; *) bad "shelf created silently: $out";; esac
[ -d "$S/acme/projects/gadget/plans" ] && bad "a shelf was created without --new-shelf" || ok "no shelf was created without asking"
out="$(run new z --title "Z" --project gadget --new-shelf)"
[ -f "$S/acme/projects/gadget/plans/001-z.md" ] && grep -q '001-z.md' "$S/acme/projects/gadget/plans/README.md" \
  && ok "--new-shelf opens the shelf, its index and the first plan" || bad "--new-shelf failed: $out"

out="$(run new co --title "Company" --scope realm --owner acme)"
[ -f "$S/acme/plans/001-co.md" ] && ok "a company plan lands on the realm's shelf, with no project resolved" || bad "realm scope failed: $out"

out="$(run shelves)"
printf '%s\n' "$out" | grep -q '"acme","widget","svartalfaheim/acme/projects/widget/plans","1"' && ok "shelves names each project and its count" || bad "shelves: $out"

out="$(run list --project widget)"
case "$out" in *"#1 First"*) ok "list reads the named project's shelf";; *) bad "list: $out";; esac

exit "$fail"
