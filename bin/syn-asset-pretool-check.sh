#!/usr/bin/env bash
# syn-asset-pretool-check.sh — PreToolUse seatbelt for governed paths.
#
# Editing a governed file without having loaded its owning asset is how the
# runtime drifts from its documentation. This seatbelt denies an `edit`/`write`
# of a governed path unless the matching asset was read earlier in the session
# (recorded in state/asset-reads). Advisory routes exist (AGENTS.md, the session
# digest); this is the enforced one.
#
# Contract (same as bin/syn-arm-pretool-check.sh):
#   syn-asset-pretool-check.sh --path <file> [--tool edit|write]
#   syn-asset-pretool-check.sh --note <asset-path>   # record an asset as read
#   syn-asset-pretool-check.sh --status
# Exit: 0 = allow, 2 = block (stderr carries the reason).
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
READS="${SYN_ASSET_READS:-$ROOT/state/asset-reads}"
TARGET=""; NOTE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --path) TARGET=${2-}; shift 2 ;;
    --tool) shift 2 ;;
    --note) NOTE=${2-}; shift 2 ;;
    --status) exec "$0" --path __status__ ;;
    *) shift ;;
  esac
done

# Record an asset as read (called after a read of an asset path). Store BOTH the
# path as given and its repo-relative form, so either spelling unlocks the gate.
if [ -n "$NOTE" ]; then
  mkdir -p "$(dirname "$READS")" 2>/dev/null || true
  printf '%s\n' "$NOTE" >>"$READS" 2>/dev/null || true
  case "$NOTE" in
    "$ROOT"/*) printf '%s\n' "${NOTE#"$ROOT"/}" >>"$READS" 2>/dev/null || true ;;
  esac
  exit 0
fi

[ -n "$TARGET" ] || exit 0
[ "$TARGET" = "__status__" ] && { [ -f "$READS" ] && cat "$READS" || true; exit 0; }

# Map a governed path to its owning asset. Order matters — first match wins.
asset_for() {
  case "$1" in
    *bin/ymir-install.sh)                         printf '%s' ".agents/skills/galdr-cli/assets/installation.md" ;;
    *apps/hlidskjalf/*)                           printf '%s' ".agents/skills/galdr-cli/assets/hlidskjalf-ui.md" ;;
    *bin/mimir*)                                  printf '%s' ".agents/skills/galdr-cli/assets/memory-well.md" ;;
    *bin/nornir-*|*config/cron.yaml)              printf '%s' ".agents/skills/galdr-cli/assets/nornir-jobs.md" ;;
    *bin/valknut-load.sh|*/.pi/*|*/.opencode/*)   printf '%s' ".agents/skills/galdr-cli/assets/harness-integration/README.md" ;;
    *bin/smidja*|*.agents/skills/smidja-factory-factory/*)        printf '%s' ".agents/skills/galdr-cli/assets/smidja.md" ;;
    *)                                            printf '' ;;
  esac
}

ASSET="$(asset_for "$TARGET")"
[ -n "$ASSET" ] || exit 0   # not governed — allow

# Already loaded this session? Accept the asset recorded either as a repo-relative
# path or as an absolute path (the harness records what it read, which may be
# either); compare on a normalised suffix.
if [ -f "$READS" ]; then
  while IFS= read -r seen; do
    [ -n "$seen" ] || continue
    case "$seen" in
      "$ASSET"|"$ROOT/$ASSET") exit 0 ;;
    esac
  done <"$READS"
fi

printf 'denied: %s is governed by %s\n' "$TARGET" "$ASSET" >&2
printf 'help: read that asset first (the read is recorded automatically), then edit.\n' >&2
printf 'why: a code change not reflected in its asset is an incomplete change.\n' >&2
exit 2
