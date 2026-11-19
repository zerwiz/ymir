#!/usr/bin/env bash
# test_release_nested_modules.sh — a release's dependency borrow carries the workspaces' own node_modules.
#
# On 2026-11-19 the pin could not build: `tsc` in apps/hlidskjalf said "Cannot find module '@xterm/xterm'".
# The dependency was declared and locked — npm had nested it at apps/hlidskjalf/node_modules/@xterm/xterm
# because its version differs from the root's — but `release.sh build` borrowed only the root node_modules
# from the running release, so the nested folder never arrived. This proves the lock reader names every
# nested folder, and that the build calls it.
#
#   bin/gates/tests/test_release_nested_modules.sh
#
# Exit: 0 all green · 1 a failure (each printed by name).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
REL="$ROOT/bin/engine/release.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fails=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fails=$((fails+1)); }

# load the one function under test, without running the script's body
eval "$(sed -n '/^lock_nested_dirs()/,/^}/p' "$REL")"
declare -F lock_nested_dirs >/dev/null || { bad "release.sh defines lock_nested_dirs"; exit 1; }

cat > "$TMP/package-lock.json" <<'EOF'
{ "lockfileVersion": 3, "packages": {
  "": { "workspaces": ["apps/a", "apps/b"] },
  "apps/a": { "version": "1.0.0" },
  "apps/a/node_modules/left-pad": { "version": "2.0.0" },
  "apps/a/node_modules/@scope/thing": { "version": "6.0.0" },
  "apps/b/node_modules/x": { "version": "1.0.0" },
  "node_modules/left-pad": { "version": "1.0.0" },
  "node_modules/y/node_modules/z": { "version": "1.0.0" }
} }
EOF
got="$(lock_nested_dirs "$TMP/package-lock.json" | tr '\n' ' ')"
[ "$got" = "apps/a/node_modules apps/b/node_modules " ] && ok "nested workspace folders named, root and package-nested ones not" \
  || bad "lock_nested_dirs printed '$got'"

grep -q 'lock_nested_dirs "\$tmp/\$m/package-lock.json"' "$REL" && ok "build borrows the nested folders" \
  || bad "build does not call lock_nested_dirs"

if [ -f "$ROOT/package-lock.json" ]; then
  lock_nested_dirs "$ROOT/package-lock.json" >/dev/null && ok "the repository's own lock parses" || bad "the repository's lock did not parse"
fi

[ "$fails" = 0 ] && { echo "all green"; exit 0; } || exit 1
