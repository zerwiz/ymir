#!/usr/bin/env bash
# 0015-systems-skirnir — heal a home that still spells `bin/assistant/`.  # allow-superseded-path: this header RECORDS the move, it does not make it
#
# Rule 25: "a move is a migration". Plan 150 moved Skírnir out of the assistant shelf into his own
# domain folder: `bin/assistant/<door>` became `systems/skirnir/services/<door>` on 2026-10-31. A
# checkout follows a `git pull`; a HOME does not — the operator's own `config/cron.yaml` and the
# skills that call a door keep the old spelling, and a schedule naming a script that is not there is
# a job that silently never runs.
#
# WHAT IT TOUCHES — the home's LIVE WIRING, and nothing else:
#   * `config/**`                  the schedule and the config that names doors
#   * `.agents/skills/**`          procedures and the scripts inside them that CALL a door
#   * `hodd/identity/domains.yaml` the register: who keeps what, and where it lives
#
# WHAT IT DELIBERATELY DOES NOT TOUCH, and why (measured on the Snotra move, plan 129 §0014):
#   * `hodd/memory/**`, `hodd/saves/**`, `hodd/reference/**`, `hodd/docs/**`, `hodd/state/**` — RECORDS.
#     A record is corrected by appending a dated entry, never by a migration's sed (Rules 06 and 20).
#     The Snotra migration's first draft swept all of `hodd/`, rewrote 81 files and corrupted two
#     SQLite stores; since then migrations grep with -I and name their shelves explicitly.
#   * any non-text file: .db, .engram*, .jsonl, .log, .age, .patch, archives.
#
# A door is rewritten ONLY when its new home really exists in this tree: a migration that repoints a
# schedule at a file which has not landed is the same silent failure in the other direction.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOME_DIR="${YMIR_HOME:-}"
[ -n "$HOME_DIR" ] || { . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null && ymir_home_root HOME_DIR; }
changed=0
repoint() {  # <file>
  local f="$1"; [ -r "$f" ] || return 0
  grep -q 'bin/assistant/' "$f" 2>/dev/null || return 0  # allow-superseded-path: this line RECORDS the move, it does not make it
  local tmp; tmp="$(mktemp)"
  while IFS= read -r line; do
    case "$line" in
      *bin/assistant/*)  # allow-superseded-path: this line RECORDS the move, it does not make it
        local out="$line"
        # only rewrite a door whose new home exists
        for d in $(printf '%s' "$line" | grep -oE 'bin/assistant/[A-Za-z0-9._-]+' | sort -u); do  # allow-superseded-path: this line RECORDS the move, it does not make it
          local base="${d##*/}"
          [ -e "$ROOT/systems/skirnir/services/$base" ] || continue
          out="${out//$d/systems\/skirnir\/services\/$base}"
        done
        printf '%s\n' "$out" >>"$tmp" ;;
      *) printf '%s\n' "$line" >>"$tmp" ;;
    esac
  done <"$f"
  if ! cmp -s "$f" "$tmp"; then cp "$tmp" "$f"; changed=$((changed+1)); fi
  rm -f "$tmp"
}
if [ -n "$HOME_DIR" ] && [ -d "$HOME_DIR" ]; then
  for f in "$HOME_DIR"/config/*.yaml "$HOME_DIR"/config/*.yml "$HOME_DIR"/hodd/identity/domains.yaml; do
    [ -f "$f" ] && repoint "$f"
  done
  while IFS= read -r f; do repoint "$f"; done < <(find "$HOME_DIR/.agents/skills" -type f -name '*.sh' -o -type f -name '*.md' 2>/dev/null)
fi
printf 'migration[1]{id,files_repointed}:\n  "0015-systems-skirnir",%s\n' "$changed"
