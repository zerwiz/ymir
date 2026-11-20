#!/usr/bin/env bash
# electron-lib.test.sh — the ONE resolver knows every shape npm leaves behind,
# and absence is NEVER success. (P1/P2 — the 2026-09-24 guarantee.)
#
# The install broke because probes looked only at the app's own node_modules:
# a workspace member's electron HOISTS to the root, and the launcher exec'd a
# path npm will never make while the guard treated absence as success. This
# test proves the resolver finds app-local, workspace-hoisted, and sibling
# package runtimes, places fetches where npm actually keeps them, and — the
# law — reports absence as failure.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$ROOT/bin/electron-lib.sh"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

[ -r "$LIB" ] || { bad "electron-lib.sh missing"; echo "FAILURES"; exit 1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# A fake electron binary that answers --version.
fake_electron() {  # <dir>
  local dir="$1"
  mkdir -p "$dir"
  cat >"$dir/electron" <<'EOF'
#!/bin/sh
echo "fake-electron 1.2.3"
EOF
  chmod +x "$dir/electron"
}
fake_pkg() {  # <electron-pkg-dir> — the electron package shape npm leaves
  mkdir -p "$1"
  printf '{"name":"electron","version":"1.2.3"}\n' >"$1/package.json"
  fake_electron "$1/dist"
  printf 'electron' >"$1/path.txt"
}

# ── the clone shape: apps/<surface> in a workspace root, electron HOISTED ──
CLONE="$TMP/clone"
mkdir -p "$CLONE/apps/hlidskjalf"
printf '{"name":"@zerwiz/ymir","workspaces":["apps/*"]}\n' >"$CLONE/package.json"
printf '{"name":"hlidskjalf","version":"0.1.0"}\n' >"$CLONE/apps/hlidskjalf/package.json"
fake_pkg "$CLONE/node_modules/electron"          # the ROOT hoist npm makes
mkdir -p "$CLONE/node_modules/.bin"
fake_electron "$CLONE/node_modules/.bin" >/dev/null 2>&1 || true
# no app-local electron under apps/hlidskjalf — npm never creates it

bin="$(. "$LIB"; electron_bin "$CLONE/apps/hlidskjalf" "$CLONE" hlidskjalf)"
[ "$bin" = "$CLONE/node_modules/electron/dist/electron" ] \
  && ok "workspace-hoisted runtime is resolved (the clone shape)" \
  || bad "workspace-hoisted: got '$bin'"

# ── the package shape: app nested under @zerwiz, electron app-local ────────
PKG="$TMP/pkg"
mkdir -p "$PKG/node_modules/@zerwiz/hlidskjalf"
printf '{"name":"@zerwiz/ymir","workspaces":["apps/*"]}\n' >"$PKG/package.json"
printf '{"name":"hlidskjalf","version":"0.1.0"}\n' >"$PKG/node_modules/@zerwiz/hlidskjalf/package.json"
fake_pkg "$PKG/node_modules/@zerwiz/hlidskjalf/node_modules/electron"

bin="$(. "$LIB"; electron_bin "$PKG/node_modules/@zerwiz/hlidskjalf" "$PKG" hlidskjalf)"
[ "$bin" = "$PKG/node_modules/@zerwiz/hlidskjalf/node_modules/electron/dist/electron" ] \
  && ok "app-local runtime is resolved (a nested package keeps its own)" \
  || bad "app-local: got '$bin'"

# ── the sibling shape: the app hoisted OUT of the ymir package ─────────────
SIB="$TMP/sib"
mkdir -p "$SIB/node_modules/@zerwiz/ymir/node_modules/@zerwiz/hlidskjalf"
printf '{"name":"@zerwiz/ymir"}\n' >"$SIB/node_modules/@zerwiz/ymir/package.json"
mkdir -p "$SIB/node_modules/@zerwiz/hlidskjalf"
printf '{"name":"hlidskjalf"}\n' >"$SIB/node_modules/@zerwiz/hlidskjalf/package.json"
fake_pkg "$SIB/node_modules/@zerwiz/hlidskjalf/node_modules/electron"
# the ymir package itself has no electron — the runtime lives in the sibling

bin="$(. "$LIB"; electron_bin "$SIB/node_modules/@zerwiz/ymir/node_modules/@zerwiz/hlidskjalf" "$SIB/node_modules/@zerwiz/ymir" hlidskjalf)"
[ "$bin" = "$SIB/node_modules/@zerwiz/hlidskjalf/node_modules/electron/dist/electron" ] \
  && ok "sibling-package runtime is resolved (the app hoisted out of ymir)" \
  || bad "sibling: got '$bin'"

# ── absence is NEVER success (P2): no electron anywhere → failure, not green ──
NONE="$TMP/none"
mkdir -p "$NONE/apps/hlidskjalf"
printf '{"name":"@zerwiz/ymir","workspaces":["apps/*"]}\n' >"$NONE/package.json"
printf '{"name":"hlidskjalf"}\n' >"$NONE/apps/hlidskjalf/package.json"

st="$(. "$LIB"; state="$(electron_runtime_state "$NONE/apps/hlidskjalf" "$NONE" hlidskjalf)"; echo "$state")"
[ "$st" = absent ] && ok "a tree with no runtime reports 'absent'" || bad "absent: got '$st'"
if . "$LIB"; electron_bin "$NONE/apps/hlidskjalf" "$NONE" hlidskjalf >/dev/null 2>&1; then
  bad "the resolver SUCCEEDS on an absent runtime — the old silent-green guard"
else
  ok "the resolver FAILS on an absent runtime (absence is never success)"
fi

# ── partial is not ok: the package exists, the binary does not ──────────────
PART="$TMP/part"
mkdir -p "$PART/apps/hlidskjalf"
printf '{"name":"@zerwiz/ymir","workspaces":["apps/*"]}\n' >"$PART/package.json"
printf '{"name":"hlidskjalf"}\n' >"$PART/apps/hlidskjalf/package.json"
mkdir -p "$PART/node_modules/electron"
printf '{"name":"electron","version":"1.2.3"}\n' >"$PART/node_modules/electron/package.json"
# no dist/electron — npm installed the package but the postinstall was gated

st="$(. "$LIB"; state="$(electron_runtime_state "$PART/apps/hlidskjalf" "$PART" hlidskjalf)"; echo "$state")"
[ "$st" = partial ] && ok "a gated postinstall reports 'partial', never ok" || bad "partial: got '$st'"

# ── placement (P3): a fetch must land where npm guarantees the runtime ──────
pl="$(. "$LIB"; electron_place_dir "$CLONE/apps/hlidskjalf" "$CLONE" hlidskjalf)"
[ "$pl" = "$CLONE/node_modules/electron" ] \
  && ok "workspace member fetch lands at the root hoist, not the doomed app dir" \
  || bad "member placement: got '$pl'"

# a standalone app OUTSIDE any workspace keeps its own node_modules
STD="$TMP/std"
mkdir -p "$STD"
printf '{"name":"standalone"}\n' >"$STD/package.json"
pl="$(. "$LIB"; electron_place_dir "$STD" "$CLONE" standalone)"
[ "$pl" = "$STD/node_modules/electron" ] \
  && ok "a standalone (non-member) app places the runtime app-locally" \
  || bad "standalone placement: got '$pl'"

# ── the guard shape (P2): a guard built on the resolver cannot return 0 on absence
# The old bug was `[ -d ... ] || return 0` INSIDE the guard. The resolver-based
# guard fails when nothing resolves — this is the shape every caller must use.
guard_like() {  # <app-dir> <root> <pkg>
  local b
  b="$(electron_bin "$1" "$2" "$3" 2>/dev/null || true)"
  [ -n "$b" ] && [ -x "$b" ] || return 1
  return 0
}
if . "$LIB"; guard_like "$NONE/apps/hlidskjalf" "$NONE" hlidskjalf; then
  bad "the guard returned SUCCESS with no runtime — absence became success"
else
  ok "the guard FAILS when no runtime exists — absence is never success"
fi

[ "$fail" = 0 ] && echo "ALL PASS" || echo "FAILURES"
exit "$fail"