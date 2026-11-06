#!/usr/bin/env bash
# test_handoff_packet.sh — proves the packet door reads a true packet and refuses a false one.
#
# The two refusals that carry plan 203 are tested here, because they are the design (§15.3):
#   · a head that MOVED is refused, and the refusal quotes §14.1
#   · a changed list that understates the diff is refused
# and the two lesser ones: a gate that is a claim rather than evidence, and a packet with no
# base sha (nobody could verify it).
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tool="$here/../../forge/handoff-packet.py"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0
ok()  { printf '  ok   %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }

echo "test_handoff_packet"
[ -x "$tool" ] || { bad "the tool is not executable: $tool"; exit 1; }

# a throwaway repository with a real base and a real head
repo="$tmp/repo"; mkdir -p "$repo"; cd "$repo" || exit 1
git init -q .; git config user.email t@ymir; git config user.name t
printf 'one\n' > a.txt; git add a.txt; git commit -qm base
base="$(git rev-parse HEAD)"
git checkout -q -b work; printf 'two\n' > b.txt; git add b.txt; git commit -qm head
head="$(git rev-parse HEAD)"

out=""; rc=0
run() { out="$("$@" 2>&1)"; rc=$?; }

# 1 · a true packet is written and reads as sound
printf 'guards.sh -> 27 wards, every one PASS\n' > "$tmp/gates.txt"
printf 'test_x.sh -> 7 passed, 0 failed\n' > "$tmp/tests.txt"
run python3 "$tool" write ok --task t --plan p --branch work --base "$base" --head "$head" \
  --gates "$tmp/gates.txt" --tests "$tmp/tests.txt" --repo "$repo" --packet "$tmp/ok.packet"
[ "$rc" = 0 ] && ok "a packet with evidence is written" || bad "write failed: $out"
run python3 "$tool" check ok --repo "$repo" --packet "$tmp/ok.packet"
[ "$rc" = 0 ] && ok "a true packet reads as sound" || bad "a true packet was refused: $out"

# 2 · the sha check (§14.1) — a moved head is refused, and says so
run python3 "$tool" check ok --repo "$repo" --packet "$tmp/ok.packet" --fetched "$head$head"
[ "$rc" = 1 ] && ok "a moved head is refused" || bad "a moved head was accepted (rc=$rc)"
case "$out" in *"may not vouch for code that moved"*) ok "the refusal quotes §14.1's rule" ;;
  *) bad "the refusal did not name the moved-head rule" ;; esac

# 3 · the changed list is checked, not believed
grep -v '"b.txt"' "$tmp/ok.packet" > "$tmp/lying.packet"
run python3 "$tool" check ok --repo "$repo" --packet "$tmp/lying.packet"
[ "$rc" = 1 ] && ok "an understated changed list is refused" || bad "a lying changed list passed"
case "$out" in *understated*) ok "the refusal says understated, and names the path" ;;
  *) bad "the refusal did not name the omission" ;; esac

# 4 · a gate that is a claim, not evidence
printf 'all pass\n' > "$tmp/claim.txt"
run python3 "$tool" write claim --task t --plan p --base "$base" --head "$head" \
  --gates "$tmp/claim.txt" --tests "$tmp/tests.txt" --repo "$repo" --packet "$tmp/claim.packet"
[ "$rc" = 1 ] && ok '"all pass" is refused as evidence' || bad '"all pass" was accepted as evidence'

# 5 · no base sha — nobody could verify the diff
sed 's|^  "base",.*|  "base","origin/main",|' "$tmp/ok.packet" > "$tmp/nobase.packet"
run python3 "$tool" check ok --repo "$repo" --packet "$tmp/nobase.packet"
[ "$rc" = 1 ] && ok "a base with no sha is refused" || bad "a base with no sha was accepted"

# 6 · a missing packet is a refusal, never an empty pass
run python3 "$tool" check ghost --repo "$repo" --packet "$tmp/nope.packet"
[ "$rc" = 1 ] && ok "a missing packet is refused" || bad "a missing packet was accepted"

printf 'test_handoff_packet: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ] || exit 1
