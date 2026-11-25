#!/usr/bin/env bash
# test_gate_pack.sh — Ymir's gate pack seats, judges and reports (plan 372).
#
#   1. `pack.sh seat` copies every ward and every pack file into a fresh clone and writes VENDORED with both lists
#   2. the seated repository's own planted-fault test passes (every gate refuses its fault)
#   3. `vendor-sync.sh --check` in the seated repository agrees with Ymir at the recorded commit
#   4. `pack.sh check` calls the clone current; an older ledger is called behind
#   5. `seat` refuses to take a file the repository wrote for itself
#   6. the repository's own .gitleaks.toml survives a re-seat
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
pass=0; fail=0
ok()  { pass=$((pass + 1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf 'FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/     /'; }

# the pack is seated from a COMMITTED revision; a working tree under test may carry it uncommitted
if ! git -C "$ROOT" diff --quiet HEAD -- bin/gates/pack bin/gates/pack.sh 2>/dev/null; then
  printf 'skip: bin/gates/pack has uncommitted changes — the pack seats from a commit\n'; exit 0
fi

app() {
  local d="$WORK/$1"; mkdir -p "$d"
  git -C "$d" init -q -b main
  git -C "$d" config user.name tester; git -C "$d" config user.email "1+tester@users.noreply.github.com"
  printf '# an app\n' > "$d/README.md"; git -C "$d" add README.md; git -C "$d" commit -q -m init --no-verify
  printf '%s' "$d"
}

d="$(app one)"
out="$(bash "$ROOT/bin/gates/pack.sh" seat "$d" --no-hooks 2>&1)"; rc=$?
wards="$(grep -cvE '^\s*(#|$)' "$ROOT/bin/gates/pack/files.txt")"
packs="$(git -C "$ROOT" ls-tree -r --name-only HEAD -- bin/gates/pack/tree/ | wc -l | tr -d ' ')"
listed="$(awk '/^(files|pack):/ {on=1; next} /^[^ #]/ {on=0} on && /^  [^ ]/' "$d/VENDORED" | wc -l | tr -d ' ')"
missing=0; while IFS= read -r f; do [ -f "$d/$f" ] || missing=$((missing + 1)); done < <(awk '/^(files|pack):/ {on=1; next} /^[^ #]/ {on=0} on && /^  [^ ]/ {print $1}' "$d/VENDORED")
[ "$rc" -eq 0 ] && [ "$listed" -eq $((wards + packs)) ] && [ "$missing" -eq 0 ] && [ -f "$d/.gitleaks.toml" ] \
  && ok "seat — $wards wards and $packs pack files copied, all listed in VENDORED" \
  || bad "seat did not copy and list every file (exit $rc, listed $listed, missing $missing)" "$out"

# (CI unset: the seated test demands gitleaks under CI, and Ymir's own runner may not carry it — the app
# repositories' workflow installs it pinned, and runs this same test there)
out="$(env -u CI bash "$d/tests/gates.test.sh" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && ok "the seated repository's planted-fault test passes ($(printf '%s' "$out" | tail -1))" \
  || bad "the seated repository's planted-fault test failed" "$(printf '%s' "$out" | grep -E 'FAIL|gates_test')"

out="$(YMIR_SRC="$ROOT" bash "$d/bin/gates/vendor-sync.sh" --check 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && ok "vendor-sync --check agrees with Ymir at the recorded commit" || bad "vendor-sync --check disagreed (exit $rc)" "$out"

out="$(bash "$ROOT/bin/gates/pack.sh" check "$d" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q " is current " && ok "pack.sh check calls a fresh seat current" || bad "pack.sh check did not call a fresh seat current (exit $rc)" "$out"

# an older ledger: drop one ward from the list, as a repository seated before that ward joined the pack would carry
first="$(grep -vE '^\s*(#|$)' "$ROOT/bin/gates/pack/files.txt" | head -1)"
grep -vxF "  $first" "$d/VENDORED" > "$d/VENDORED.old" && mv "$d/VENDORED.old" "$d/VENDORED"
out="$(bash "$ROOT/bin/gates/pack.sh" check "$d" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q " is behind " && ok "pack.sh check calls an older ledger behind" || bad "an older ledger was not called behind (exit $rc)" "$out"

d2="$(app two)"
mkdir -p "$d2/bin/gates"; printf '#!/bin/sh\necho mine\n' > "$d2/bin/gates/run-gates.sh"
out="$(bash "$ROOT/bin/gates/pack.sh" seat "$d2" --no-hooks 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && grep -q 'echo mine' "$d2/bin/gates/run-gates.sh" && ok "seat refuses to take a file the repository wrote for itself" \
  || bad "seat overwrote a repository's own file (exit $rc)" "$out"

printf '\n# mine\n' >> "$d/.gitleaks.toml"
bash "$ROOT/bin/gates/pack.sh" seat "$d" --no-hooks >/dev/null 2>&1
grep -q '^# mine$' "$d/.gitleaks.toml" && ok "a re-seat leaves the repository's own .gitleaks.toml alone" || bad "a re-seat overwrote .gitleaks.toml"

printf 'test_gate_pack: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
