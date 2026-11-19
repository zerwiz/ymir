#!/usr/bin/env bash
# test_hall_snapshot_board.sh — where the Live Hall's board is written after the split (2026-11-19).
#
# Óðrerir left the tree; installed in its own home its board is STATE (app.yaml `state_dir`). The snapshot
# job used to default to "$APP_ODRERIR/public/livehall.json", which on a seat without the app became
# "/public/livehall.json": the write failed and the job still exited 0.
#
# Everything is fenced in one temp dir: an apps home, a state home, a hoard state dir. Nothing real is written.
#
#   · the app absent from the seat      → the board lands in the state dir, exit 0
#   · the app in its own home           → the board lands in the state dir, never inside the release
#   · the board cannot be written       → exit 1 with an error, never a silent green
#
# Exit: 0 every case held · 1 a case failed.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SNAP="$ROOT/systems/snotra/services/cron/hall-snapshot.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/ymir-hall-board.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
export YMIR_APPS_HOME="$TMP/apps-home" XDG_STATE_HOME="$TMP/xdg-state" BROKK_STATE_OVERRIDE="$TMP/hoard-state"
export YMIR_ROOT_DIR="$TMP/no-tree"   # no legacy apps/odrerir to fall back to
unset YMIR_APP_STATE_DIR ODRERIR_BOARD YMIR_APP_ODRERIR_DIR
mkdir -p "$YMIR_APPS_HOME" "$BROKK_STATE_OVERRIDE" "$YMIR_ROOT_DIR"
board="$XDG_STATE_HOME/odrerir/livehall.json"

fail=0
ok()  { printf 'ok    %s\n' "$1"; }
bad() { printf 'FAIL  %s\n' "$1"; fail=1; }

bash "$SNAP" >/dev/null 2>&1; rc=$?
[ "$rc" = 0 ] && [ -s "$board" ] && grep -q '"generated_at"' "$board" \
  && ok "app absent: the board is written to its state dir" || bad "app absent: rc=$rc, board $(ls "$board" 2>&1)"

rm -f "$board"
rel="$YMIR_APPS_HOME/odrerir/releases/abc123"
mkdir -p "$rel/public" "$rel/dist"
printf 'name: odrerir\n' >"$rel/app.yaml"
ln -s releases/abc123 "$YMIR_APPS_HOME/odrerir/current"
bash "$SNAP" >/dev/null 2>&1; rc=$?
[ "$rc" = 0 ] && [ -s "$board" ] && [ ! -e "$rel/public/livehall.json" ] && [ ! -e "$rel/dist/livehall.json" ] \
  && ok "app in its home: the board is state, the release is untouched" || bad "home road: rc=$rc"

ODRERIR_BOARD=/proc/no-such-dir/livehall.json bash "$SNAP" >/dev/null 2>&1; rc=$?
[ "$rc" = 1 ] && ok "an unwritable board is a red exit" || bad "an unwritable board exited $rc"

exit "$fail"
