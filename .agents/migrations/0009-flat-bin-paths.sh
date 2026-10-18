#!/usr/bin/env bash
# 0009-flat-bin-paths — heal a home that still spells the FLAT bin/ paths.
#
# Rule 25: "a move is a migration". The bin/ reorganisation moved the scheduled jobs and a
# dozen companions into their shelves — `bin/nornir-job-*.sh` became   # allow-superseded-path: this header RECORDS the move; the ledger is what acts on it
# `bin/time/nornir-job-*.sh`, `bin/ymir-install.sh` became `bin/engine/ymir-install.sh`.  # allow-superseded-path: this header RECORDS the move; the ledger is what acts on it
# A
# checkout follows a `git pull`; a HOME does not. So on 2026-10-18 the operator's own cron
# was found carrying the old spellings (and literal merge-conflict markers), and the
# scheduler read a schedule whose commands did not exist — on this seat, and on every seat
# that had not hand-fixed it. This is the file that should have shipped with the move.
#
# What it rewrites, and only this:
#   * the home's `config/*.yaml` — cron.yaml first (a schedule naming a script that is not
#     there is a job that silently never runs)
#   * any `hodd/docs/**` file that names an old path (the assets an agent follows)
#
# Nothing is deleted; nothing is guessed. A conflict marker found on the way is NAMED, not
# resolved — the migration cannot know which side is right.
#
# Idempotent: a second run rewrites nothing.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
HOME_DIR=""
if [ -n "${YMIR_HOME:-}" ]; then HOME_DIR="$YMIR_HOME"
elif command -v ymir_home_root >/dev/null 2>&1; then ymir_home_root HOME_DIR
fi
[ -n "$HOME_DIR" ] && [ -d "$HOME_DIR" ] || { printf 'migration[1]{id,result}:\n  "0009-flat-bin-paths","SKIP — no home reachable"\n'; exit 0; }

LEDGER="$ROOT/.agents/paths-ledger.yaml"
[ -r "$LEDGER" ] || { printf 'migration[1]{id,result}:\n  "0009-flat-bin-paths","SKIP — no paths ledger"\n'; exit 0; }

pairs() {
  python3 - "$LEDGER" <<'PY'
import re, sys
old = None
for line in open(sys.argv[1], encoding="utf-8"):
    m = re.match(r'\s*-?\s*old:\s*"?([^"\n]+)"?\s*$', line)
    if m: old = m.group(1).strip()
    m = re.match(r'\s*new:\s*"?([^"\n]+)"?\s*$', line)
    if m and old:
        print(f"{old}\t{m.group(1).strip()}"); old = None
PY
}

changed=0
while IFS=$'\t' read -r old new; do
  [ -n "$old" ] || continue
  # skip the old spelling when it is a SUFFIX of the new one (bin/time/x contains bin/x)
  case "$new" in *"$old"*) continue ;; esac
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    grep -qF -- "$old" "$f" 2>/dev/null || continue
    if grep -q '^<<<<<<< \|^>>>>>>> ' "$f" 2>/dev/null; then
      printf 'migration[1]{id,file,result}:\n  "0009-flat-bin-paths","%s","a conflict marker survives — resolve it by hand (the migration will not guess which side is right)"\n' "${f#"$HOME_DIR"/}"
    fi
    if sed -i "s|${old//|/\\|}|${new//|/\\|}|g" "$f" 2>/dev/null; then
      printf 'migration[1]{id,file,rewrote}:\n  "0009-flat-bin-paths","%s","%s -> %s"\n' "${f#"$HOME_DIR"/}" "$old" "$new"
      changed=$((changed+1))
    fi
  done < <( { grep -rlF --exclude-dir=.git --exclude-dir=node_modules -- "$old" "$HOME_DIR/config" 2>/dev/null
              grep -rlF --exclude-dir=.git --exclude-dir=node_modules -- "$old" "$HOME_DIR/hodd/docs" 2>/dev/null; } | head -200 )
done < <(pairs)

printf 'migration[2]{id,home,rewrites}:\n  "0009-flat-bin-paths","%s",%s\n' "${HOME_DIR/#$HOME/~}" "$changed"
exit 0
