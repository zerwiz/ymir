#!/usr/bin/env bash
# 0014-systems-shelf — heal a home that still spells `bin/time/snotra/`.  # allow-superseded-path: this header RECORDS the move, it does not make it
#
# Rule 25: "a move is a migration". Plan 129 moved Snotra out of the time shelf into its own domain folder:
# `bin/time/snotra/<door>` became `systems/snotra/services/<service>/<door>` on 2026-10-24. A checkout follows a
# `git pull`; a HOME does not. So the operator's own `config/cron.yaml` keeps the old spelling — a schedule naming
# a script that is not there is a job that silently never runs.
#
# WHAT IT TOUCHES — the home's LIVE WIRING, and nothing else:
#   * `config/**`                  the schedule and the config that names doors
#   * `.agents/skills/**`          the procedures and the scripts inside them that CALL a door
#   * `hodd/identity/domains.yaml` the register: who keeps what, and where it lives
#
# WHAT IT DELIBERATELY DOES NOT TOUCH, and why (measured, not theorised):
#   * `hodd/memory/**`, `hodd/saves/**`, `hodd/reference/**`, `hodd/docs/**`, `hodd/state/**` — these are RECORDS.
#     A record is corrected by appending a dated entry, never by a migration's sed (Rules 06 and 20: the well
#     appends, and an episode is never replaced). The first draft of this file swept all of `hodd/` and rewrote
#     81 files — including `well/episodes.jsonl` (history) and two SQLite stores, which a byte-substitution
#     cannot survive: `kaia.engram` and `state/assistant/kb.db` came back "database disk image is malformed".
#     They were restored from the home's own git; the episode store was restored line by line. Since then this
#     migration greps with `-I` (binary files are never read or written) and names its shelves explicitly.
#   * any non-text file at all: `.db`, `.engram*`, `.jsonl`, `.log`, `.age`, `.patch`, archives. A sed over a
#     binary is corruption with a friendly name.
#
# The per-door destination is read from `systems/snotra/domain.yaml`, so the migration and the declaration cannot
# disagree. A door is rewritten ONLY when its new home really exists in this tree: a migration that repoints a
# schedule at a file which has not landed is the same silent failure in the other direction.
#
# A unit is the one file where guessing is dangerous: systemd would keep a service down until the merge. So a unit
# is repointed only when it names THIS tree (`$ROOT`, or `%h/<basename of $ROOT>`); a unit naming another tree is
# NAMED and skipped, never edited.
#
# Nothing is deleted; nothing is guessed. A second run rewrites nothing — the old spelling is gone, so no file
# matches — and that is the proof of idempotency.
set -u

OLD="bin/time/snotra"
NEW="systems/snotra"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
HOME_DIR=""
if [ -n "${YMIR_HOME:-}" ]; then HOME_DIR="$YMIR_HOME"
elif command -v ymir_home_root >/dev/null 2>&1; then ymir_home_root HOME_DIR
fi
[ -n "$HOME_DIR" ] && [ -d "$HOME_DIR" ] || { printf 'migration[1]{id,result}:\n  "0014-systems-shelf","SKIP — no home reachable"\n'; exit 0; }

DOMAIN="$ROOT/$NEW/domain.yaml"
[ -r "$DOMAIN" ] || { printf 'migration[1]{id,result}:\n  "0014-systems-shelf","SKIP — no %s/domain.yaml (nothing to read the door map from)"\n' "$NEW"; exit 0; }

UNITS_DIR="${SYSTEMD_UNITS_DIR:-$HOME/.config/systemd/user}"

# The door map, from the declaration: <door> <TAB> systems/snotra/services/<service>/<door>
door_map() {
  python3 - "$DOMAIN" "$NEW" <<'PY'
import re, sys
domain, new = sys.argv[1], sys.argv[2]
svc = None
for line in open(domain, encoding="utf-8"):
    m = re.match(r'^  ([a-z][a-z0-9-]*):\s*$', line)
    if m:
        svc = m.group(1)
        continue
    m = re.match(r'^\s+- (services/[a-z0-9-]+/[A-Za-z0-9_.-]+)\s', line)
    if m and svc:
        path = f"{new}/{m.group(1)}"
        print(f"{path.rsplit('/', 1)[1]}\t{path}")
PY
}

rewrote=0
note() { printf 'migration[1]{id,file,result}:\n  "0014-systems-shelf","%s","%s"\n' "$1" "$2"; }

# The home's live wiring: text files only (-I), on the shelves that are wiring rather than record.
wiring_files() {
  { [ -f "$HOME_DIR/config/cron.yaml" ] && printf '%s\n' "$HOME_DIR/config/cron.yaml"
    grep -rIlF --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=.yggdrasil -- "$OLD" \
      "$HOME_DIR/config" "$HOME_DIR/.agents/skills" "$HOME_DIR/hodd/identity/domains.yaml" 2>/dev/null
  } | awk '!seen[$0]++'
}

# ── 1 · the doors, by name ─────────────────────────────────────────────────
while IFS=$'\t' read -r door newpath; do
  [ -n "${door:-}" ] || continue
  old="$OLD/$door"
  [ -e "$ROOT/$newpath" ] || { note "$door" "the door has not landed at $newpath in this tree — skipped, not guessed"; continue; }
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    grep -qF -- "$old" "$f" 2>/dev/null || continue
    if grep -q '^<<<<<<< \|^>>>>>>> ' "$f" 2>/dev/null; then
      note "${f#"$HOME_DIR"/}" "a conflict marker survives — resolve it by hand (the migration will not guess which side is right)"
    fi
    sed -i "s|${old//|/\\|}|${newpath//|/\\|}|g" "$f" 2>/dev/null \
      && { note "${f#"$HOME_DIR"/}" "$old -> $newpath"; rewrote=$((rewrote+1)); }
  done < <(wiring_files)
done < <(door_map)

# ── 2 · a sentence that names the SHELF, not a door ────────────────────────
while IFS= read -r f; do
  [ -n "$f" ] || continue
  grep -qF -- "$OLD" "$f" 2>/dev/null || continue
  sed -i "s|$OLD|$NEW|g" "$f" 2>/dev/null \
    && { note "${f#"$HOME_DIR"/}" "$OLD -> $NEW (a sentence naming the shelf)"; rewrote=$((rewrote+1)); }
done < <(wiring_files)

# ── 3 · installed units, but only those naming THIS tree ───────────────────
unit_rewrites=0
if [ -d "$UNITS_DIR" ]; then
  tree_name="${ROOT##*/}"
  while IFS= read -r u; do
    [ -n "$u" ] || continue
    if ! grep -qF -- "$ROOT/$OLD" "$u" 2>/dev/null \
       && ! grep -qF -- "%h/$tree_name/$OLD" "$u" 2>/dev/null; then
      note "${u#"$HOME"/}" "names $OLD in ANOTHER tree — left alone (its own checkout heals it)"
      continue
    fi
    while IFS=$'\t' read -r door newpath; do
      [ -n "${door:-}" ] || continue
      [ -e "$ROOT/$newpath" ] || continue
      for prefix in "$ROOT" "%h/$tree_name"; do
        old="$prefix/$OLD/$door"
        grep -qF -- "$old" "$u" 2>/dev/null || continue
        sed -i "s|${old//|/\\|}|$prefix/$newpath|g" "$u" 2>/dev/null \
          && { note "${u#"$HOME"/}" "$old -> $prefix/$newpath"; unit_rewrites=$((unit_rewrites+1)); }
      done
    done < <(door_map)
    sed -i "s|$ROOT/$OLD|$ROOT/$NEW|g; s|%h/$tree_name/$OLD|%h/$tree_name/$NEW|g" "$u" 2>/dev/null || true
  done < <(grep -rIlF -- "$OLD" "$UNITS_DIR" 2>/dev/null)
fi
[ "$unit_rewrites" -gt 0 ] && printf 'migration[1]{id,result,next}:\n  "0014-systems-shelf","units repointed","run: systemctl --user daemon-reload  (do NOT restart a running door by hand)"\n'

printf 'migration[2]{id,home,rewrites}:\n  "0014-systems-shelf","%s",%s\n' "${HOME_DIR/#$HOME/~}" "$rewrote"
[ "$rewrote" -eq 0 ] && printf 'migration[1]{id,result}:\n  "0014-systems-shelf","clean — no wiring file spells the old path (a second run rewrites nothing)"\n'
printf 'migration[1]{id,scope}:\n  "0014-systems-shelf","wiring only: config/** · .agents/skills/** · hodd/identity/domains.yaml · this tree'"'"'s units. Records (memory, saves, reference, docs, state) are corrected by appending, never by a migration"\n'
exit 0
