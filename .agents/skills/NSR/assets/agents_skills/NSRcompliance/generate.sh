#!/usr/bin/env bash
# generate.sh — stamp a .compliance/ deterministic harness into a repo, from this skill alone.
#
# The compliance skill is fully self-contained: it needs no rest of the NSR repo.
# Everything it generates lives under .compliance/ at the target repo root.
#
# Usage:
#   generate.sh [TARGET_REPO] [--force] [--dry-run]
#     TARGET_REPO  default = repo root found upward from this skill (.agents/ ancestor)
#     --force      overwrite existing generated files (idempotency check by default)
#     --dry-run    show what would be written without writing
#
# Post-condition: the generated harness loads and the wiring/danger gates are present.
set -e

SKILL="$(cd "$(dirname "$0")" && pwd)"
TARGET=""
FORCE=0
DRY=0

usage() {
  echo "Usage: generate.sh [TARGET_REPO] [--force] [--dry-run]"
  exit 1
}

find_repo_root() {
  local d; d="$SKILL"
  while [ "$d" != "/" ]; do
    if [ -d "$d/.agents" ]; then echo "$d"; return 0; fi
    d="$(dirname "$d")"
  done
  return 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) usage ;;
    -*) echo "unknown option: $1"; usage ;;
    *) TARGET="$1"; shift ;;
  esac
done

[ -n "$TARGET" ] || TARGET="$(find_repo_root)" || { echo "error: run from a repo (no .agents/ ancestor found)"; exit 1; }
mkdir -p "$TARGET"
TARGET="$(cd "$TARGET" && pwd)"

put_file() {
  local src="$1" dst="$2"
  if [ "$src" -ef "$dst" ]; then
    echo "[generate] SKIP (same file): ${dst#$TARGET/}"
    return 0
  fi
  if [ -e "$dst" ] && [ "$FORCE" -eq 0 ]; then
    [ "$DRY" -eq 0 ] && echo "[generate] SKIP (exists): ${dst#$TARGET/}"
    return 0
  fi
  if [ "$DRY" -eq 1 ]; then
    echo "[generate] would write: ${dst#$TARGET/}"
  else
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    echo "[generate] wrote: ${dst#$TARGET/}"
  fi
}

copy_tree() {
  local src="$1" dst="$2"
  mkdir -p "$dst"
  for item in "$src"/*; do
    [ -e "$item" ] || continue
    local base; base="$(basename "$item")"
    if [ -d "$item" ]; then
      copy_tree "$item" "$dst/$base"
    else
      put_file "$item" "$dst/$base"
    fi
  done
}

echo "[generate] self-contained compliance skill -> $TARGET"
echo "[generate] phase 1: static .compliance/ tree from templates"
copy_tree "$SKILL/templates/compliance" "$TARGET/.compliance"

echo "[generate] phase 2: runtime files (runner, logger, config, gates, envelopes)"
put_file "$SKILL/harness/runner.py"                 "$TARGET/.compliance/harness/runner.py"
put_file "$SKILL/telemetry/logger.py"               "$TARGET/.compliance/telemetry/logger.py"
put_file "$SKILL/telemetry/logger.py"               "$TARGET/.agents/skills/NSRcompliance/telemetry/logger.py"
put_file "$SKILL/harness/runner.py"                 "$TARGET/.agents/skills/NSRcompliance/harness/runner.py"
put_file "$SKILL/config/core_four.yaml"             "$TARGET/.compliance/config/core_four.yaml"
put_file "$SKILL/gates/check_danger.sh"             "$TARGET/.compliance/gates/check_danger.sh"
put_file "$SKILL/gates/check_wiring.sh"             "$TARGET/.compliance/gates/check_wiring.sh"
put_file "$SKILL/harness/envelopes/task_envelope.json"  "$TARGET/.compliance/harness/envelopes/task_envelope.json"
put_file "$SKILL/harness/envelopes/result_envelope.json" "$TARGET/.compliance/harness/envelopes/result_envelope.json"

chmod -R u+x "$TARGET/.compliance" 2>/dev/null || true

if [ "$DRY" -eq 1 ]; then
  echo "[generate] dry-run complete (nothing written)"
  exit 0
fi

echo "[generate] sanity: runner loads"
python3 "$TARGET/.compliance/harness/runner.py" --help >/dev/null 2>&1 \
  || { echo "[generate] FAIL: generated runner did not load"; exit 1; }

echo "[generate] DONE: .compliance/ ready at $TARGET/.compliance"
exit 0