#!/usr/bin/env bash
# test_lore_audit.sh — plan 350 A: the lore audit's verdicts, and the weekly watch that names a claim turned false.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
pass=0; fail=0
ok()  { printf '  PASS %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
L="$root/bin/records/lore-audit.sh"
printf 'Alpha\tit answers\tbin/records/lore-audit.sh\techo up\t^up\t\nBeta\tit answers\tbin/records/lore-audit.sh\techo down\t^up\t\nGamma\tno door\t-\ttrue\trc0\t\nDelta\tnot built\t-\ttrue\trc0\tplanned\n# a comment\n' >"$T/c.tsv"
export YMIR_STATE_DIR="$T/state" YMIR_HOME="$T/home"
echo "test_lore_audit"
out="$("$L" run --claims "$T/c.tsv")"
printf '%s' "$out" | grep -q '^| Alpha .*\*\*true\*\*' && ok "a door whose probe bears the claim out is true" || bad "alpha: $out"
printf '%s' "$out" | grep -q '^| Beta .*\*\*partial\*\*' && ok "a door whose probe does not is partial" || bad "beta"
printf '%s' "$out" | grep -q '^| Gamma .*\*\*false\*\*' && ok "no door is false" || bad "gamma"
printf '%s' "$out" | grep -q '^| Delta .*\*\*planned\*\*' && ok "a system the house records as planned is planned" || bad "delta"
printf '%s' "$out" | grep -q 'Totals: false 1 · partial 1 · planned 1 · true 1' && ok "the totals are counted" || bad "totals: $(printf '%s' "$out" | tail -1)"
"$L" watch --claims "$T/c.tsv" >/dev/null; [ $? = 0 ] && ok "the first watch has nothing to compare and is quiet" || bad "first watch"
sed -i 's/echo up/echo gone/' "$T/c.tsv"
out="$("$L" watch --claims "$T/c.tsv")"; rc=$?
[ "$rc" = 1 ] && printf '%s' "$out" | grep -q 'Alpha: was true, now partial' && ok "a claim that turned false is named, and the watch is red" || bad "turned: rc=$rc $out"
"$L" watch --claims "$T/c.tsv" >/dev/null; [ $? = 0 ] && ok "a claim already false is not said again" || bad "repeat"
[ "$(wc -l <"$T/state/lore-audit/history.jsonl")" -ge 12 ] && ok "every measurement is kept" || bad "history"
n="$(grep -c $'\t' "$root/docs/lore-claims.tsv")"
[ "$n" -ge 40 ] && ok "the shipped claims carry every system the saga names ($n rows)" || bad "claims rows: $n"
for s in Bifrost Brimir Eindri Forseti Gungnir Heimdall Níðhöggr Ratatoskr Utgard Yggdrasil "the Veil" Eir Gróa; do
  grep -q "^$s"$'\t' "$root/docs/lore-claims.tsv" || bad "no row for $s"
done
ok "the named systems each have a row"
echo "test_lore_audit: $pass passed, $fail failed"
[ "$fail" = 0 ]
