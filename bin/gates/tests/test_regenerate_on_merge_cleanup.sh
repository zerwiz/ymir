#!/usr/bin/env bash
# test_regenerate_on_merge_cleanup.sh — the merge driver leaves no `.merge_file_*` behind (2026-11-12).
ROOT="$(git rev-parse --show-toplevel)"
DRV="$ROOT/bin/records/regenerate-on-merge.sh"
fail=0
t() { if [ "$1" = "$2" ]; then echo "PASS: $3"; else echo "FAIL: $3 (want=$1 got=$2)"; fail=1; fi; }
d="$(mktemp -d)"; trap 'rm -rf "$d"' EXIT
# the driver sweeps the working directory it is run in, as git runs it in the worktree root
run() { ( cd "$d" && bash "$DRV" "$@" >/dev/null 2>&1 ); }
echo a >"$d/.merge_file_aaaaaa"; echo b >"$d/.merge_file_bbbbbb"; echo c >"$d/out"
echo o >"$d/.merge_file_oldold"; touch -d '3 hours ago' "$d/.merge_file_oldold"
run .merge_file_aaaaaa out .merge_file_bbbbbb 7 notwoven.txt
t 1 "$?" "a non-woven path keeps git's conflict (rc=1)"
t no "$([ -e "$d/.merge_file_aaaaaa" ] && echo yes || echo no)" "the base input is removed"
t no "$([ -e "$d/.merge_file_bbbbbb" ] && echo yes || echo no)" "the theirs input is removed"
t no "$([ -e "$d/.merge_file_oldold" ] && echo yes || echo no)" "an hour-old orphan is swept"
t yes "$([ -e "$d/out" ] && echo yes || echo no)" "the output is git's to read, so it stays"
grep -qx '.merge_file_\*' "$ROOT/.gitignore" && g=yes || g=no
t yes "$g" ".gitignore names .merge_file_*"
exit $fail
