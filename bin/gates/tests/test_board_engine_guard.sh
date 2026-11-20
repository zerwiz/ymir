#!/usr/bin/env bash
# board-engine-guard refuses a NEW file naming Plane's API, the old bin/gimle/ tree or a Gimlé host from the
# home's list (plan 335), names file:line and the list ENTRY (never the host), and spares an edited existing
# file, a waived line and the exempt shelves (fix notes, RULES). Every name here is invented.
set -uo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
g="$root/bin/gates/guards/board-engine-guard.sh"
t="$(mktemp -d)"; trap 'rm -rf "$t"' EXIT
export YMIR_GIMLE_HOSTS_FILE="$t/hosts.txt"
printf '# the operator'"'"'s hosts\nboard.example.invalid\n' >"$YMIR_GIMLE_HOSTS_FILE"
git -C "$t" init -q; git -C "$t" config user.email t@t; git -C "$t" config user.name t
printf 'base="$PLANE_API_BASE"\n' >"$t/old.sh"; git -C "$t" add old.sh; git -C "$t" commit -qm base

# 1 · an EXISTING file that still names Plane is not judged
printf 'base="$PLANE_API_BASE"\nmore\n' >"$t/old.sh"; git -C "$t" add old.sh
bash "$g" --repo "$t" --staged >/dev/null 2>&1 || { echo "FAIL: an edited existing file was refused"; exit 1; }

# 2 · a NEW file naming Plane's API is refused, by file and line
printf 'ok\nurl = base + "/api/v1/workspaces/" + slug\n' >"$t/new.py"; git -C "$t" add new.py
out="$(bash "$g" --repo "$t" --staged 2>&1)"; rc=$?
[ "$rc" -eq 1 ] || { echo "FAIL: expected exit 1 for a new Plane call, got $rc"; exit 1; }
case "$out" in *new.py:2*/api/v1/workspaces/*) ;; *) echo "FAIL: the refusal lacks file:line — $out"; exit 1 ;; esac
git -C "$t" rm -q --cached new.py

# 3 · each engine word is caught
for w in 'PLANE_API_TOKEN' 'import plane_reader' 'sys.path.insert(0, "bin/gimle/")' 'docker exec plane-selfhost-plane-db-1'; do
  printf '%s\n' "$w" >"$t/n2.sh"; git -C "$t" add n2.sh
  bash "$g" --repo "$t" --staged >/dev/null 2>&1 && { echo "FAIL: '$w' not refused"; exit 1; }
  git -C "$t" rm -q --cached n2.sh
done

# 4 · a Gimlé host from the home list is refused, and the host itself is never printed
printf 'MCP=https://board.example.invalid/mcp\n' >"$t/h.sh"; git -C "$t" add h.sh
out="$(bash "$g" --repo "$t" --staged 2>&1)"; rc=$?
[ "$rc" -eq 1 ] || { echo "FAIL: a home-listed host was let through"; exit 1; }
case "$out" in *"entry 1 of the home list"*) ;; *) echo "FAIL: the host refusal does not name the entry — $out"; exit 1 ;; esac
case "$out" in *board.example.invalid*) echo "FAIL: the ward printed the host"; exit 1 ;; esac
git -C "$t" rm -q --cached h.sh

# 5 · a waived line and the exempt shelves pass
printf 'see PLANE_API_BASE (board-engine-ok: quoting the old name in a history note)\n' >"$t/w.md"
mkdir -p "$t/docs/fixes/boards" "$t/RULES"
printf 'bin/gimle/ moved to its own repository\n' >"$t/docs/fixes/boards/note.md"
printf 'the shape bin/gimle/deploy.sh proved\n' >"$t/RULES/99-x.md"
git -C "$t" add w.md docs/fixes/boards/note.md RULES/99-x.md
bash "$g" --repo "$t" --staged >/dev/null 2>&1 || { echo "FAIL: a waived line or an exempt shelf was refused"; exit 1; }

# 6 · the range mode judges what a push adds
git -C "$t" commit -qm clean; base="$(git -C "$t" rev-parse HEAD)"
printf 'tok = env["PLANE_API_TOKEN"]\n' >"$t/r.py"; git -C "$t" add r.py; git -C "$t" commit -qm bad
bash "$g" --repo "$t" --range "$base..HEAD" >/dev/null 2>&1 && { echo "FAIL: --range let a new engine call through"; exit 1; }
echo "PASS board-engine-guard refuses new Plane calls, bin/gimle/ paths and home-listed hosts by file:line, and spares old files, waivers and exempt shelves"
