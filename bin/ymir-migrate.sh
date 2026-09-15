#!/usr/bin/env bash
# ymir-migrate.sh — versioned STRUCTURE migrations for existing Ymir homes.
#
#   bin/ymir-migrate.sh status           # which migrations exist / are applied
#   bin/ymir-migrate.sh apply            # apply everything pending, in order
#   bin/ymir-migrate.sh apply --dry-run  # show what would run, touch nothing
#   bin/ymir-migrate.sh --version
#
# Each migration is `.agents/migrations/<NNNN>-<name>.sh`, MUST be idempotent,
# and runs with `bash`. Applied ids are recorded in `state/migrations` (private).
# `bin/ymir-install.sh` and `bin/brokk-update.sh` call `apply` after an update.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
YMIR_HOME="${YMIR_HOME:-$HOME/Documents/Ymir}"
MIG_DIR="$ROOT/.agents/migrations"
STATE_DIR="${YMIR_STATE_DIR:-$YMIR_HOME/state}"
APPLIED="$STATE_DIR/migrations"

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

ACTION="${1:-status}"; shift || true
DRY=0
for a in "$@"; do case "$a" in --dry-run|-n) DRY=1 ;; esac; done

[ -d "$MIG_DIR" ] || { printf 'ymir-migrate[1]{state}:\n  "none","no migrations directory"\n'; exit 0; }
mkdir -p "$STATE_DIR"; [ -f "$APPLIED" ] || : >"$APPLIED"

is_applied() { grep -qxF "$1" "$APPLIED" 2>/dev/null; }
desc_of() { sed -n 's/^# *[0-9]\{4\}-[a-z0-9-]* *—* *//p' "$1" | head -1; }

mapfile -t MIGS < <(ls "$MIG_DIR"/[0-9][0-9][0-9][0-9]-*.sh 2>/dev/null | sort)

if [ "$ACTION" = status ]; then
  printf 'ymir-migrate[%d]{migration,state,description}:\n' "${#MIGS[@]}"
  for m in "${MIGS[@]}"; do
    id="$(basename "$m" .sh)"
    if is_applied "$id"; then st=applied; else st=pending; fi
    printf '  "%s","%s","%s"\n' "$id" "$st" "$(desc_of "$m")"
  done
  exit 0
fi

[ "$ACTION" = apply ] || { printf 'error: unknown action %s\nhelp: bin/ymir-migrate.sh [status|apply [--dry-run]]\n' "$ACTION" >&2; exit 2; }

ran=0; skipped=0
for m in "${MIGS[@]}"; do
  id="$(basename "$m" .sh)"
  if is_applied "$id"; then skipped=$((skipped+1)); continue; fi
  printf 'ymir-migrate[1]{apply,migration}:\n  "%s","%s"\n' "$([ "$DRY" = 1 ] && echo dry-run || echo run)" "$id"
  if [ "$DRY" = 1 ]; then continue; fi
  if bash "$m"; then
    printf '%s\n' "$id" >>"$APPLIED"; ran=$((ran+1))
  else
    printf 'error: migration %s failed — stopping; fix and re-run\n' "$id" >&2; exit 1
  fi
done
printf 'ymir-migrate[1]{action,applied,pending}:\n  "%s",%s,%s\n' "$([ "$DRY" = 1 ] && echo dry-run || echo apply)" "$ran" "$skipped"
