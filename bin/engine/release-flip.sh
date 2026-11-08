#!/usr/bin/env bash
# release-flip.sh — make one release live, in ONE rename, health first (plan 221, P1)
#
#   bin/engine/release-flip.sh <sha|dir>          health-check, then flip the symlink
#   bin/engine/release-flip.sh <sha> --no-live    skip raising the release's services
#   bin/engine/release-flip.sh <sha> --window 30  how long to watch for degradation
#   bin/engine/release-flip.sh --status           where the world points, and the shelf
#   bin/engine/release-flip.sh --help | --version
#
# THE SWAP, and the form it may never take. The flip prepares a symlink under a
# temporary name and renames it over ~/ymir-current:
#
#     ln -s <release> ~/ymir-current.tmp && mv -T ~/ymir-current.tmp ~/ymir-current
#
# `rm ~/ymir-current && ln -s <release> ~/ymir-current` is NOT atomic — it leaves a
# window where nothing is current, and plan 221 §10 names that a phase failure, not
# a style note. No `rm` of the live link exists anywhere in this door; a stale temp
# from a crashed flip is the only thing it ever clears.
#
# HEALTH FIRST, THEN THE LINK, THEN A WINDOW. A release that fails its health check
# never becomes current. A release that passes and then DEGRADES inside the window is
# flipped BACK on its own, and the log says `rolled back to <old> · <reason>` — the
# 3am path needs no thinking (plan 221 §10, "automatic rollback, not only a refusal").
#
# It never force-merges, resets, stashes or cleans; it never touches the desktop
# entries, the systemd units, the running apps or the hoard. Processes keep the
# release they started in until they are restarted — that is the point.
set -uo pipefail

RELEASE_FLIP_VERSION="1.0.0"
SELF_DIR="$(CDPATH='' cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(CDPATH='' cd "$SELF_DIR/../.." && pwd)"

# shellcheck source=/dev/null
. "$SELF_DIR/release-lib.sh"
# shellcheck source=/dev/null
[ -r "$ROOT/bin/fleet/ymir-platform.sh" ] && . "$ROOT/bin/fleet/ymir-platform.sh"
release_config

usage() {
  cat <<'EOF'
release-flip — make one release live in one atomic rename.

  bin/engine/release-flip.sh <sha|dir>          # health first, then flip, then watch
  bin/engine/release-flip.sh <sha> --no-live    # do not raise the release's services
  bin/engine/release-flip.sh <sha> --window N   # watch N seconds (default $YMIR_FLIP_WINDOW)
  bin/engine/release-flip.sh <sha> --no-window  # flip and stop watching
  bin/engine/release-flip.sh --status           # the current release, the shelf, the log

The link moves by `ln -s <release> <link>.tmp && mv -T <link>.tmp <link>`. A `rm`
before an `ln` is forbidden: it leaves a window where nothing is current.

A refusal leaves the link exactly where it was. A degradation inside the window is
flipped back automatically and recorded with its reason in
$YMIR_RELEASES_LOG.
EOF
}

say()  { printf '%s\n' "$*"; }
warn() { printf '%s\n' "$*" >&2; }
die()  { warn "error: $*"; exit 1; }

status() {
  cur="$(release_current || true)"
  say "current[1]{link,target}:"
  if [ -L "$YMIR_CURRENT_LINK" ]; then
    say "  \"$YMIR_CURRENT_LINK\",\"$(release_real "$YMIR_CURRENT_LINK")\""
  else
    say "  \"$YMIR_CURRENT_LINK\",\"unset\""
  fi
  say "releases[1]{dir,keep}:"
  say "  \"$YMIR_RELEASES_DIR\",\"$YMIR_RELEASES_KEEP\""
  say "shelf[1]{release,size,mtime,current}:"
  for p in "$YMIR_RELEASES_DIR"/*/; do
    [ -d "$p" ] || continue
    id="${p%/}"; id="${id##*/}"
    case "$id" in *[!0-9a-f]*) continue ;; esac
    mark="no"; [ -n "$cur" ] && [ "$id" = "$cur" ] && mark="yes"
    sz="$(release_human "$(release_size "$p")")"
    when="$(release_when "$(release_mtime "$p")")"
    say "  \"$id\",\"$sz\",\"$when\",\"$mark\""
  done
  if [ -r "$YMIR_RELEASES_LOG" ]; then
    say "log[1]{path,last-lines}:"
    say "  \"$YMIR_RELEASES_LOG\""
    tail -5 "$YMIR_RELEASES_LOG" | sed 's/^/  /'
  fi
  exit 0
}

[ $# -gt 0 ] || { usage >&2; exit 2; }
TARGET=""; LIVE=1; WINDOW="$YMIR_FLIP_WINDOW"; WATCH=1
while [ $# -gt 0 ]; do
  case "${1-}" in
    -h|--help)       usage; exit 0 ;;
    -v|-V|--version) printf 'release-flip %s\n' "$RELEASE_FLIP_VERSION"; exit 0 ;;
    --status)        status ;;
    --no-live)       LIVE=0; shift ;;
    --window)        WINDOW="${2-}"; shift 2 ;;
    --no-window)     WATCH=0; shift ;;
    -*)              die "unknown flag $1 (help: release-flip.sh --help)" ;;
    *)               TARGET="$1"; shift ;;
  esac
done
[ -n "$TARGET" ] || { usage >&2; exit 2; }
case "$WINDOW" in ''|*[!0-9]*) die "--window needs a number of seconds" ;; esac

# ── which release ───────────────────────────────────────────────────────────
if [ -d "$TARGET" ]; then
  DIR="$(release_real "$TARGET")"
else
  resolved="$(release_resolve "$ROOT" "$TARGET")" || die "$TARGET names no commit in $ROOT — build it first: bin/engine/release-build.sh $TARGET"
  DIR="$(release_dir_for "${resolved##* }")"
fi
[ -d "$DIR" ] || die "no release at $DIR — build it first: bin/engine/release-build.sh ${TARGET}"
[ -r "$DIR/RELEASE-MANIFEST.json" ] || die "$DIR carries no manifest — it is not a release"
ID="${DIR##*/}"

PREV="$(release_current || true)"
say "flip[1]{from,to,link,window,live}:"
say "  \"${PREV:-none}\",\"$ID\",\"$YMIR_CURRENT_LINK\",\"${WATCH:+${WINDOW}s}\",\"$LIVE\""

if [ -n "$PREV" ] && [ "$PREV" = "$ID" ]; then
  say "state[1]{verdict,detail}:"
  say "  \"already-current\",\"$ID is what $YMIR_CURRENT_LINK already names — nothing was moved\""
  exit 0
fi

# ── 1. HEALTH FIRST ─────────────────────────────────────────────────────────
# Nothing moves on a refusal: the check runs entirely against the candidate.
health_args=("$DIR")
[ "$LIVE" = 1 ] && health_args+=(--live)
say "health[1]{door,result}:"
if h_out="$(bash "$SELF_DIR/release-health.sh" "${health_args[@]}" 2>&1)"; then
  say "  \"release-health.sh\",\"healthy\""
  printf '%s\n' "$h_out" | grep -E '"service:|"assets"|"deps"|"own-scripts"' | sed 's/^/  /' || true
else
  reason="$(printf '%s' "$h_out" | grep -E '"FAIL"' | head -3 | sed 's/^ *//' | tr '\n' '; ')"
  say "  \"release-health.sh\",\"REFUSED\""
  printf '%s\n' "$h_out" | sed 's/^/  /'
  release_log "refused" "to=$ID" "from=${PREV:-none}" "health=refused" "reason=${reason:-see release-health.sh}"
  say "state[1]{verdict,detail}:"
  say "  \"refused\",\"$ID did not pass its health check — $YMIR_CURRENT_LINK was not touched\""
  exit 1
fi

# ── 2. THE ONE RENAME ───────────────────────────────────────────────────────
# Never a delete before the link: the temp symlink is prepared, then renamed over.
release_atomic_link "$DIR" "$YMIR_CURRENT_LINK" || {
  release_log "refused" "to=$ID" "from=${PREV:-none}" "health=ok" "reason=the rename failed; the link was not removed"
  die "the atomic rename failed — $YMIR_CURRENT_LINK was not removed, it still names ${PREV:-nothing}"
}
NOW="$(release_current || true)"
[ "$NOW" = "$ID" ] || die "the link moved but names '${NOW:-nothing}', not $ID"
say "swap[1]{link,target,method}:"
say "  \"$YMIR_CURRENT_LINK\",\"$DIR\",\"ln -s …tmp + mv $(release_mv_flag) (one rename)\""
release_log "flip" "from=${PREV:-none}" "to=$ID" "health=ok" "window=${WATCH:+${WINDOW}s}${WATCH:-0}" "result=flipped"

# ── 3. THE WINDOW: did the release degrade after it went live? ──────────────
# The 3am path: the door checks its own work and undoes it, rather than waiting
# for a person to notice that the hall is dark.
if [ "$WATCH" = 1 ] && [ "$WINDOW" -gt 0 ]; then
  sleep "$WINDOW"
  if w_out="$(bash "$SELF_DIR/release-health.sh" "$YMIR_CURRENT_LINK" --quiet 2>&1)"; then
    say "window[1]{seconds,result}:"
    say "  \"${WINDOW}s\",\"still healthy\""
  else
    reason="$(printf '%s' "$w_out" | grep -E '"FAIL"' | head -3 | sed 's/^ *//' | tr '\n' '; ')"
    say "window[1]{seconds,result,reason}:"
    say "  \"${WINDOW}s\",\"degraded\",\"${reason:-release-health.sh refused the live link}\""
    if [ -z "$PREV" ]; then
      release_log "flip" "from=$ID" "to=none" "health=degraded" "window=${WINDOW}s" "result=no-rollback-target" "reason=${reason:-unknown}"
      say "state[1]{verdict,detail}:"
      say "  \"degraded\",\"$ID degraded inside the window and there is no previous release to roll back to\""
      exit 1
    fi
    PREV_DIR="$(release_dir_for "$PREV")"
    if [ ! -d "$PREV_DIR" ]; then
      release_log "flip" "from=$ID" "to=$PREV" "health=degraded" "window=${WINDOW}s" "result=rollback-impossible" "reason=the previous release is gone"
      die "$ID degraded inside the window, and $PREV_DIR is gone — there is nothing to roll back to"
    fi
    release_atomic_link "$PREV_DIR" "$YMIR_CURRENT_LINK" || {
      release_log "flip" "from=$ID" "to=$PREV" "health=degraded" "window=${WINDOW}s" "result=rollback-failed" "reason=the rename failed"
      die "$ID degraded inside the window and the rollback rename failed — $YMIR_CURRENT_LINK still names $ID"
    }
    release_log "flip" "from=$ID" "to=$PREV" "health=degraded" "window=${WINDOW}s" "result=rolled-back" "reason=${reason:-unknown}"
    say "state[1]{verdict,detail}:"
    say "  \"rolled-back\",\"$ID degraded inside ${WINDOW}s — $YMIR_CURRENT_LINK names $PREV again, because ${reason:-unknown}\""
    exit 1
  fi
fi

# ── 4. the previous release is still there, and still answers for itself ────
# A flip must never cost the release you would roll back to.
if [ -n "$PREV" ]; then
  PREV_DIR="$(release_dir_for "$PREV")"
  if [ -d "$PREV_DIR" ] && bash "$SELF_DIR/release-health.sh" "$PREV_DIR" --quiet >/dev/null 2>&1; then
    say "previous[1]{release,state}:"
    say "  \"$PREV\",\"still on disk and still healthy — rollback is one rename\""
  else
    say "previous[1]{release,state}:"
    say "  \"$PREV\",\"missing or unhealthy — the next flip has no rollback target\""
  fi
fi

say "flipped[1]{release,link,log}:"
say "  \"$ID\",\"$YMIR_CURRENT_LINK\",\"$YMIR_RELEASES_LOG\""
exit 0
