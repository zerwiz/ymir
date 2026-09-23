#!/usr/bin/env bash
# npm-install-local-test.sh — the REAL local installation test.
#
# npm-pretest.sh proves the tarball installs into a throwaway sandbox and that
# the hull is intact. This is the other half: install the exact tarball the way
# a user does — `npm install -g` into the real global prefix — then smoke the
# installed `ymir` itself, not a copy in /tmp.
#
# It records the version already installed, installs the new one, runs the
# smoke, and restores the previous version unless --keep is given. It also
# reports VERSION DRIFT: the tree's package.json version against what npm has
# installed (the npm line has run ahead of the tree before).
#
# Usage:
#   bin/npm-install-local-test.sh            # install for real, smoke, restore
#   bin/npm-install-local-test.sh --keep     # leave the new version installed
#   bin/npm-install-local-test.sh --prefix <dir>
# Env:
#   NPM_INSTALL_PREFIX   override the global prefix (default: `npm prefix -g`)
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
WORK="$(mktemp -d /tmp/npm-install-local-XXXXXX)"
KEEP=0
PREFIX="${NPM_INSTALL_PREFIX:-$(npm prefix -g 2>/dev/null)}"
PASS=1

say() { printf '%s\n' "$*"; }
ok()  { say "  ok: $*"; }
fail() { say "FAIL: $*"; PASS=0; }

while [ $# -gt 0 ]; do
  case "$1" in
    --keep) KEEP=1; shift ;;
    --prefix) PREFIX="${2-}"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'error: unknown flag %s\n' "$1" >&2; exit 2 ;;
  esac
done

[ -n "$PREFIX" ] || { fail "no global prefix (npm prefix -g gave nothing)"; exit 1; }
GLOBAL_MODULES="$PREFIX/lib/node_modules"
PKG="$GLOBAL_MODULES/@zerwiz/ymir"
trap 'rm -rf "$WORK"' EXIT

say "== the real global prefix =="
say "  prefix: $PREFIX"

# — what is installed now, so we can restore it —
BEFORE_VERSION="$(node -p "try{require('$PKG/package.json').version}catch(e){''}" 2>/dev/null)"
if [ -n "$BEFORE_VERSION" ]; then
  ok "currently installed: @zerwiz/ymir@$BEFORE_VERSION"
  cp -a "$PKG" "$WORK/backup" 2>/dev/null || true
else
  say "  nothing installed yet"
fi

# — the tree's declared version, for the drift report —
TREE_VERSION="$(node -p "require('$ROOT/package.json').version" 2>/dev/null)"
say "== version drift =="
say "  tree package.json: $TREE_VERSION"
say "  npm installed:     ${BEFORE_VERSION:-none}"
if [ -n "$BEFORE_VERSION" ] && [ -n "$TREE_VERSION" ] && [ "$BEFORE_VERSION" != "$TREE_VERSION" ]; then
  say "  NOTE: the npm line and the tree disagree — reconcile before any publish."
fi

# — pack the exact artifact —
say "== packing the publish artifact =="
( cd "$ROOT" && npm pack --ignore-scripts --pack-destination "$WORK" >/dev/null 2>&1 )
TGZ="$(ls "$WORK"/*.tgz 2>/dev/null | head -1)"
[ -n "$TGZ" ] || { fail "npm pack produced no tarball"; exit 1; }
say "  tarball: $(basename "$TGZ") ($(du -h "$TGZ" | cut -f1))"

# — install it FOR REAL —
say "== npm install -g (real global install) =="
if ! npm install -g "$TGZ" >"$WORK/install.log" 2>&1; then
  fail "npm install -g failed — $(tail -3 "$WORK/install.log" | tr '\n' ' ')"
  exit 1
fi
AFTER_VERSION="$(node -p "try{require('$PKG/package.json').version}catch(e){''}" 2>/dev/null)"
ok "installed @zerwiz/ymir@${AFTER_VERSION:-unknown} into the real prefix"

# — smoke the INSTALLED ymir, not the tree —
say "== the installed ymir smokes =="
BIN="$PREFIX/bin/ymir"
[ -x "$BIN" ] && ok "ymir binary at $BIN" || fail "ymir binary not on the prefix"
out="$("$BIN" --version 2>/dev/null)"; [ -n "$out" ] && ok "ymir --version: $out" || fail "ymir --version silent"
[ -x "$PREFIX/bin/ymir-install" ] && ok "ymir-install present" || fail "ymir-install missing"

# The lock library must resolve the operator's HOARD state, not the code tree:
# that is the fix this test guards (2026-09-23).
installed_lock="$PKG/bin/gleipnir-lock-lib.sh"
if [ -r "$installed_lock" ]; then
  resolved="$(bash -c '. "$0"; gleipnir_state_dir s; printf "%s" "$s"' "$installed_lock" 2>/dev/null)"
  case "$resolved" in
    */ymirhome/state|*/Documents/ymirhome/state) ok "gleipnir_state_dir -> hoard state ($resolved)" ;;
    *) fail "gleipnir_state_dir -> $resolved (expected the hoard state, not the code tree)" ;;
  esac
else
  fail "installed package lacks bin/gleipnir-lock-lib.sh"
fi

# — restore the previous version unless asked to keep —
if [ "$KEEP" = 1 ]; then
  say "== kept @zerwiz/ymir@${AFTER_VERSION:-unknown} (--keep) =="
elif [ -n "$BEFORE_VERSION" ] && [ -d "$WORK/backup" ]; then
  say "== restoring @zerwiz/ymir@$BEFORE_VERSION =="
  rm -rf "$PKG" 2>/dev/null || true
  cp -a "$WORK/backup" "$PKG" 2>/dev/null && ok "restored @zerwiz/ymir@$BEFORE_VERSION" || fail "restore failed"
fi

say ""
[ "$PASS" = 1 ] && say "REAL INSTALL: PASS" || say "REAL INSTALL: FAIL"
exit $((PASS == 1 ? 0 : 1))
