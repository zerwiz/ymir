#!/usr/bin/env bash
# desktop-main-guard names a launcher that points into a worktree AND names the fix door.
set -uo pipefail
root="$(dirname "$0")/../../.."
t="$(mktemp -d)"; trap 'rm -rf "$t"' EXIT
mkdir -p "$t/applications"
printf '[Desktop Entry]\nExec=/home/x/ymir/.yggdrasil/foo/bin/run\n' > "$t/applications/ymir-bad.desktop"
out="$(XDG_DATA_HOME="$t" bash "$root/bin/gates/guards/desktop-main-guard.sh" 2>&1)"; rc=$?
[ "$rc" -eq 1 ] || { echo "FAIL: expected exit 1, got $rc"; exit 1; }
case "$out" in *ymir-bad.desktop*omarchy-install.sh*) ;; *) echo "FAIL: message lacks the launcher or the fix door: $out"; exit 1;; esac
printf '[Desktop Entry]\nExec=/home/x/ymir/bin/run\n' > "$t/applications/ymir-bad.desktop"
XDG_DATA_HOME="$t" bash "$root/bin/gates/guards/desktop-main-guard.sh" >/dev/null 2>&1 || { echo "FAIL: clean entry refused"; exit 1; }
echo "PASS desktop-main-guard names the worktree launcher and the fix door"
