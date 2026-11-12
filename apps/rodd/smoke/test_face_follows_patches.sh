#!/usr/bin/env bash
# test_face_follows_patches.sh — Rödd's face is stale when the house's patches changed (plan 275, 2026-11-12):
# plan 271's why.js merged, yet the served face kept printing "[object Event]", because `setup.sh --check` only
# compared the engine's tag and nothing re-ran the patcher. Runs on a copy; the real face is never touched.
set -u
APP_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; }
A="$T/rodd"; mkdir -p "$A/ui" "$A/patch"
cp "$APP_SRC/setup.sh" "$A/setup.sh"
cp "$APP_SRC/patch/"* "$A/patch/"
tag=$(sed -n 's/^TAG="\${RODD_UI_TAG:-\(.*\)}"$/\1/p' "$A/setup.sh")
printf '<html></html>\n' > "$A/ui/index.html"
printf '%s\n' "$tag" > "$A/ui/.rodd-face"

out=$(bash "$A/setup.sh" --check); rc=$?
[ "$rc" = 1 ] && [ "$out" = "stale:patch" ] && ok "a face dressed before the patch stamp existed is stale:patch" || bad "no stamp: rc=$rc out=$out"

cat "$A/patch/"* | sha256sum | cut -c1-16 > "$A/ui/.rodd-patch"
out=$(bash "$A/setup.sh" --check); rc=$?
[ "$rc" = 0 ] && [ "$out" = "present" ] && ok "a face dressed by the current patches is present" || bad "current: rc=$rc out=$out"

printf '\n// a merged change\n' >> "$A/patch/why.js"
out=$(bash "$A/setup.sh" --check); rc=$?
[ "$rc" = 1 ] && [ "$out" = "stale:patch" ] && ok "a changed patch makes the face stale again" || bad "changed: rc=$rc out=$out"

printf '%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
