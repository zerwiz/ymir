#!/usr/bin/env bash
# test_release_borrow_closure.sh — the release's borrowed dependency closure is the WHOLE closure.
#
# WHY. On 2026-11-20 main's release did not build: `bin/engine/release.sh build --ref origin/main` failed in
# apps/hlidskjalf with `src/components/Terminal.tsx(2,48): error TS2307: Cannot find module '@xterm/xterm'`.
# The dependency was declared and locked; it was simply not THERE. npm hoists most packages to the root
# node_modules but nests one inside the workspace that owns it when it cannot hoist it, and @xterm/xterm 6 lives
# at apps/hlidskjalf/node_modules/@xterm/xterm. The release borrowed only `$prev/node_modules`, so every release
# built after a matching lockfile had no app-local modules at all — and still said it had borrowed a proved one.
#
# WHAT THIS PROVES, each one a command and its printed output:
#   1. a complete borrow carries BOTH the root closure and a workspace's own nested node_modules, as hard links
#   2. a borrow whose source lacks what the destination's lock declares is REFUSED, and copies nothing
#   3. a lock with nothing nested is borrowed from the root closure alone, and is not refused for it
#
# Everything runs in a temporary directory: no release is built, nothing outside it is written.
set -uo pipefail
RELEASE="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)/bin/engine/release.sh"
pass=0 fail=0
t() { local name=$1; shift; if "$@"; then printf '  ok   %s\n' "$name"; pass=$((pass+1)); else printf '  FAIL %s\n' "$name"; fail=$((fail+1)); fi; }
not() { ! "$@"; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
# the function under test, taken whole from the door that owns it — sourcing release.sh would run its CLI
fn="$(awk '/^borrow_closure\(\)/,/^}/' "$RELEASE")"
[ -n "$fn" ] || { printf '  FAIL borrow_closure is not in %s\n' "$RELEASE"; exit 1; }
eval "$fn"

# a fixture: <dir> <lock-json>; a package is a directory holding a marker, so a copy is visible
mk() { mkdir -p "$1/node_modules/@x/pkg" && printf 'root\n' > "$1/node_modules/@x/pkg/index.js"; }

locked_nested() {  # a lock that declares the app-local @xterm/xterm
  printf '{"packages":{"apps/hlidskjalf/node_modules/@xterm/xterm":{"version":"6.0.0"}}}\n' > "$1/package-lock.json"
}
locked_hoisted() { # a lock whose packages all hoist
  printf '{"packages":{"node_modules/@x/pkg":{"version":"1.0.0"}}}\n' > "$1/package-lock.json"
}

# ── 1. the complete borrow ─────────────────────────────────────────────────────────────────────────────────────
APP="$TMP/prev/apps/hlidskjalf/node_modules/@xterm/xterm"
mkdir -p "$APP" && printf 'types\n' > "$APP/xterm.d.ts"
mk "$TMP/prev"; locked_nested "$TMP/prev"
mkdir -p "$TMP/new"; locked_nested "$TMP/new"
t "a complete borrow succeeds" borrow_closure "$TMP/prev" "$TMP/new"
t "  it carries the root closure" test -f "$TMP/new/node_modules/@x/pkg/index.js"
t "  it carries the app-local package" test -f "$TMP/new/apps/hlidskjalf/node_modules/@xterm/xterm/xterm.d.ts"
t "  and both are hard links, not a second copy" test "$(stat -c %i "$APP/xterm.d.ts")" = "$(stat -c %i "$TMP/new/apps/hlidskjalf/node_modules/@xterm/xterm/xterm.d.ts")"

# ── 2. an incomplete source is refused, and nothing is copied ────────────────────────────────────────────────
mk "$TMP/prev2"; locked_nested "$TMP/prev2"          # root closure only — the app-local module is missing
mkdir -p "$TMP/new2"; locked_nested "$TMP/new2"
t "an incomplete borrow is refused" not borrow_closure "$TMP/prev2" "$TMP/new2"
t "  and it copies nothing" test ! -e "$TMP/new2/node_modules"

# ── 3. nothing nested in the lock: the root closure is the whole closure ─────────────────────────────────────
mk "$TMP/prev3"; locked_hoisted "$TMP/prev3"
mkdir -p "$TMP/new3"; locked_hoisted "$TMP/new3"
t "a hoisted-only lock borrows from the root closure" borrow_closure "$TMP/prev3" "$TMP/new3"
t "  and the closure arrived" test -f "$TMP/new3/node_modules/@x/pkg/index.js"

printf '%s\n' "release-borrow-closure test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
