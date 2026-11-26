#!/usr/bin/env bash
# well-vault-sync commits only the well's log: files another job left staged — even ones the home's
# pre-commit refuses — neither block it nor ride along.
set -uo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
t="$(mktemp -d)"; trap 'rm -rf "$t"' EXIT
die() { echo "FAIL: $1"; printf '%s\n' "${out:-}"; exit 1; }
# a copy of the door beside a stand-in log tool: no engram engine is needed
mkdir -p "$t/tree/bin/time" "$t/tree/bin/records" "$t/tree/bin/vault"
cp "$root/bin/time/well-vault-sync.sh" "$t/tree/bin/time/"
cp "$root/bin/vault/hoard-lib.sh" "$t/tree/bin/vault/"
printf '#!/bin/sh\nexit 0\n' > "$t/tree/bin/records/mimir-log.sh"; chmod +x "$t/tree/bin/records/mimir-log.sh"

h="$t/home"; log=hodd/memory/well/episodes.jsonl
export YMIR_HOME="$h"; unset YMIR_HOARD YMIR_STATE_DIR BROKK_WELL_BRANCH BROKK_WELL_SYNC_MODE
git init -q --bare "$t/origin.git"
git init -q "$h"; git -C "$h" symbolic-ref HEAD refs/heads/main
git -C "$h" config user.email t@t; git -C "$h" config user.name t
git -C "$h" config core.hooksPath .git/hooks
mkdir -p "$h/$(dirname "$log")"; printf '{"n":1}\n' > "$h/$log"
git -C "$h" add "$log"; git -C "$h" commit -qm base
git -C "$h" remote add origin "$t/origin.git"; git -C "$h" push -q origin main
# the home refuses any commit that carries `blocked`
printf '#!/bin/sh\n! git diff --cached --name-only | grep -qx blocked\n' > "$h/.git/hooks/pre-commit"
chmod +x "$h/.git/hooks/pre-commit"
printf 'x\n' > "$h/blocked"; git -C "$h" add blocked

for mode in push pull; do
  printf '{"n":"%s"}\n' "$mode" >> "$h/$log"
  out="$(bash "$t/tree/bin/time/well-vault-sync.sh" --mode "$mode" 2>&1)" || die "$mode failed"
  [ "$(git -C "$h" show --name-only --format= HEAD)" = "$log" ] || die "$mode: the commit is not the log alone"
  [ "$(git -C "$h" diff --cached --name-only)" = blocked ] || die "$mode: the unrelated staging moved"
done
head="$(git -C "$h" rev-parse HEAD)"
out="$(bash "$t/tree/bin/time/well-vault-sync.sh" --mode push 2>&1)" || die "an unchanged log failed"
[ "$(git -C "$h" rev-parse HEAD)" = "$head" ] || die "a commit was made with nothing new in the well"
echo "PASS well-vault-sync commits only the well's log with unrelated files staged"
