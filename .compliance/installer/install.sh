#!/usr/bin/env bash
# deterministic harness installer: stamp .compliance/ + the compliance skill into a target repo.
#
# Usage:
#   install.sh [TARGET] [--source DIR] [--force] [--dry-run]
#
# - TARGET defaults to the current directory.
# - SOURCE defaults to the compliance templates inside the NSR skill found upward from this
#   script (any directory containing assets/compliance + assets/agents_skills).
# - Never overwrites existing files unless --force.
# - Post-condition: the installed harness is sanity-checked (runner loads, gates skipped
#   existing). Single repeatable command; re-run doubles as a drift check.
set -e

TARGET="${1:-.}"
SOURCE=""
FORCE=0
DRY=0

usage() {
  echo "Usage: install.sh [TARGET] [--source DIR] [--force] [--dry-run]"
  exit 1
}

find_repo_root() {
  local d; d="$(cd "$(dirname "$0")" && pwd)"
  while [ "$d" != "/" ]; do
    if [ -d "$d/.compliance" ]; then echo "$d"; return 0; fi
    d="$(dirname "$d")"
  done
  return 1
}

find_source() {
  local d repo
  # 1. an ancestor that is itself a skill (assets/compliance + assets/agents_skills)
  d="$(cd "$(dirname "$0")" && pwd)"
  while [ "$d" != "/" ]; do
    if [ -d "$d/assets/compliance" ] && [ -d "$d/assets/agents_skills" ]; then
      echo "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  # 2. a skill dir inside the repo under .agents/skills/
  repo="$(find_repo_root)" || return 1
  for d in "$repo"/.agents/skills/*/; do
    [ -d "$d" ] || continue
    if [ -d "$d/assets/compliance" ] && [ -d "$d/assets/agents_skills" ]; then
      echo "$d"; return 0
    fi
  done
  return 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --source) SOURCE="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) usage ;;
    -*) echo "unknown option: $1"; usage ;;
    *) TARGET="$1"; shift ;;
  esac
done

if [ -z "$SOURCE" ]; then
  SKILL_ROOT="$(find_source)" \
    || { echo "error: cannot auto-discover source; pass --source DIR with assets/compliance + assets/agents_skills"; exit 1; }
  SOURCE="$SKILL_ROOT/assets"
fi

[ -d "$SOURCE/compliance" ] || { echo "error: $SOURCE/compliance not found"; exit 1; }
[ -d "$SOURCE/agents_skills/NSRcompliance" ] || { echo "error: $SOURCE/agents_skills/NSRcompliance not found"; exit 1; }

mkdir -p "$TARGET"
TARGET="$(cd "$TARGET" && pwd)"

copy_tree() {
  local src="$1" dst="$2"
  mkdir -p "$dst"
  for item in "$src"/*; do
    [ -e "$item" ] || continue
    local base; base="$(basename "$item")"
    if [ -d "$item" ]; then
      copy_tree "$item" "$dst/$base"
    else
      if [ -e "$dst/$base" ] && [ "$FORCE" -eq 0 ]; then
        echo "[installer] SKIP (exists): ${dst#$TARGET/}/$base"
        continue
      fi
      if [ "$DRY" -eq 1 ]; then
        echo "[installer] would write: ${dst#$TARGET/}/$base"
      else
        cp "$item" "$dst/$base"
        echo "[installer] wrote: ${dst#$TARGET/}/$base"
      fi
    fi
  done
}

echo "[installer] installing harness -> $TARGET"
copy_tree "$SOURCE/compliance" "$TARGET/.compliance"
copy_tree "$SOURCE/agents_skills/NSRcompliance" "$TARGET/.agents/skills/NSRcompliance"
chmod -R u+x "$TARGET/.compliance" "$TARGET/.agents/skills/NSRcompliance" 2>/dev/null || true

if [ "$DRY" -eq 1 ]; then
  echo "[installer] dry-run complete (nothing written)"
  exit 0
fi

if [ ! -f "$TARGET/.compliance/harness/runner.py" ]; then
  echo "[installer] FAIL: runner.py missing after install"
  exit 1
fi
if [ ! -f "$TARGET/.compliance/harness/envelopes/task_envelope.json" ]; then
  echo "[installer] FAIL: task envelope schema missing after install"
  exit 1
fi

echo "[installer] sanity: runner loads"
python3 "$TARGET/.compliance/harness/runner.py" --help >/dev/null 2>&1 \
  || { echo "[installer] FAIL: runner.py did not load"; exit 1; }

echo "[installer] DONE: harness at $TARGET/.compliance + compliance skill at $TARGET/.agents/skills/NSRcompliance"
exit 0