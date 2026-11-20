#!/usr/bin/env bash
# retired-path-guard refuses a NEW file naming hodd/state/, hodd/life/ or hodd/workspaces/ (plan 331.9), names
# file:line, and passes an edited existing file, a waived line and the exempt shelves (migrations, fix notes).
set -uo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
g="$root/bin/gates/guards/retired-path-guard.sh"
t="$(mktemp -d)"; trap 'rm -rf "$t"' EXIT
git -C "$t" init -q; git -C "$t" config user.email t@t; git -C "$t" config user.name t
printf 'old: hodd/state/garmr\n' > "$t/old.sh"; git -C "$t" add old.sh; git -C "$t" commit -qm base

# 1. an EXISTING file that still names the old path is not judged (36k of them; the link carries them)
printf 'old: hodd/state/garmr\nmore\n' > "$t/old.sh"; git -C "$t" add old.sh
bash "$g" --repo "$t" >/dev/null 2>&1 || { echo "FAIL: an edited existing file was refused"; exit 1; }

# 2. a NEW file naming a retired path is refused, by file and line
printf 'ok\nSTATE="$YMIR_HOME/hodd/state/notify"\n' > "$t/new.sh"; git -C "$t" add new.sh
out="$(bash "$g" --repo "$t" 2>&1)"; rc=$?
[ "$rc" -eq 1 ] || { echo "FAIL: expected exit 1 for a new file, got $rc"; exit 1; }
case "$out" in *new.sh:2*hodd/state/*) ;; *) echo "FAIL: the refusal lacks file:line — $out"; exit 1 ;; esac
git -C "$t" rm -q --cached new.sh

# 3. each retired shelf is caught
for p in hodd/life/personal hodd/workspaces/work; do
  printf 'x %s\n' "$p" > "$t/n2.md"; git -C "$t" add n2.md
  bash "$g" --repo "$t" >/dev/null 2>&1 && { echo "FAIL: $p not refused"; exit 1; }
  git -C "$t" rm -q --cached n2.md
done

# 4. a waived line and the exempt shelves pass
printf 'see hodd/state/ (retired-path-ok: quoting the old path in a history note)\n' > "$t/w.md"
mkdir -p "$t/.agents/migrations" "$t/docs/fixes/hoard"
printf 'mv hodd/life life\n' > "$t/.agents/migrations/0099-x.sh"
printf 'hodd/workspaces/ moved\n' > "$t/docs/fixes/hoard/note.md"
git -C "$t" add w.md .agents/migrations/0099-x.sh docs/fixes/hoard/note.md
bash "$g" --repo "$t" >/dev/null 2>&1 || { echo "FAIL: a waived line or an exempt shelf was refused"; exit 1; }

# 5. the range mode judges what a push adds
git -C "$t" commit -qm clean; base="$(git -C "$t" rev-parse HEAD)"
printf 'hodd/life/work\n' > "$t/r.md"; git -C "$t" add r.md; git -C "$t" commit -qm bad
bash "$g" --repo "$t" --range "$base..HEAD" >/dev/null 2>&1 && { echo "FAIL: --range let a new retired path through"; exit 1; }
echo "PASS retired-path-guard refuses new retired paths by file:line and spares old files, waivers and exempt shelves"
