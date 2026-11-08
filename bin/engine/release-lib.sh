#!/usr/bin/env bash
# release-lib.sh — the ONE place that knows where a release lives and how a flip happens.
#
# Plan 221 (the atomic runtime). The idea in one sentence: an update produces a new
# IMMUTABLE release, a single symlink names the live one, the flip is one atomic
# rename, and a running app keeps the release it started in until it is restarted.
#
# This library holds the three things that must never be written twice:
#   (1) the paths        — where releases, the current link, the shared shelf and the
#                          flip log live (Rule 07: resolved, one documented default each)
#   (2) the release id   — a commit is abbreviated ONCE, here, so a directory name and a
#                          log line can never disagree about which build they mean
#   (3) the swap         — `ln -s target link.tmp && mv -T link.tmp link`, one rename.
#                          A `rm` before an `ln` is a WINDOW WHERE NOTHING IS CURRENT, and
#                          plan 221 §10 names it a phase failure, not a style note.
#
# Source-safe; defines functions and variables only.
#
# Configuration (Rule 07 — resolved, never hardcoded):
#   $YMIR_HOME/config/releases.env   YMIR_RELEASES_DIR · YMIR_CURRENT_LINK · YMIR_SHARED_DIR
#                                    YMIR_RELEASES_KEEP · YMIR_RELEASES_LOG · YMIR_FLIP_WINDOW
#   defaults: ~/ymir-releases · ~/ymir-current · ~/ymir-shared · 3 · ~/.local/state/ymir/releases.log · 5
set -u

# shellcheck source=/dev/null
_RELEASE_LIB_DIR="$(CDPATH='' cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The operator's home and its roots are resolved by hoard-lib, never guessed.
if ! declare -f ymir_home_root >/dev/null 2>&1; then
  for _rl in "$_RELEASE_LIB_DIR/../vault/hoard-lib.sh" "$_RELEASE_LIB_DIR/hoard-lib.sh"; do
    # shellcheck disable=SC1090
    [ -r "$_rl" ] && { . "$_rl"; break; }
  done
  unset _rl
fi

release_config() {
  local home="" conf=""
  declare -f ymir_home_root >/dev/null 2>&1 && ymir_home_root home 2>/dev/null
  [ -n "$home" ] || home="${YMIR_HOME:-}"
  conf="${home:+$home/config/releases.env}"
  # shellcheck disable=SC1090
  [ -n "$conf" ] && [ -r "$conf" ] && . "$conf"

  YMIR_RELEASES_DIR="${YMIR_RELEASES_DIR:-$HOME/ymir-releases}"
  YMIR_CURRENT_LINK="${YMIR_CURRENT_LINK:-$HOME/ymir-current}"
  YMIR_SHARED_DIR="${YMIR_SHARED_DIR:-$HOME/ymir-shared}"
  YMIR_RELEASES_KEEP="${YMIR_RELEASES_KEEP:-3}"
  YMIR_RELEASES_LOG="${YMIR_RELEASES_LOG:-${XDG_STATE_HOME:-$HOME/.local/state}/ymir/releases.log}"
  YMIR_FLIP_WINDOW="${YMIR_FLIP_WINDOW:-5}"

  RELEASE_HOME="$home"
  export YMIR_RELEASES_DIR YMIR_CURRENT_LINK YMIR_SHARED_DIR YMIR_RELEASES_KEEP YMIR_RELEASES_LOG YMIR_FLIP_WINDOW
}

# realpath without depending on readlink -f (BSD has none) — ymir_readlink_f when present.
release_real() {  # <path> → the resolved path, or the path itself when it does not exist
  local p="${1-}"
  if declare -f ymir_readlink_f >/dev/null 2>&1; then
    ymir_readlink_f "$p" 2>/dev/null && return 0
  fi
  if command -v readlink >/dev/null 2>&1 && readlink -f "$p" >/dev/null 2>&1; then
    readlink -f "$p"; return 0
  fi
  ( cd "$p" 2>/dev/null && pwd -P ) || printf '%s' "$p"
}

# A commit, abbreviated once. 12 characters is what the ledger, the log and the
# directory name all use; a caller may pass HEAD, a branch, a full sha or the id.
release_resolve() {  # <repo> <ref> → prints "<full-sha> <id>"; exit 1 when unknown
  local repo="${1-}" ref="${2-}" full=""
  full="$(git -C "$repo" rev-parse --verify --quiet "${ref}^{commit}" 2>/dev/null)" || return 1
  [ -n "$full" ] || return 1
  printf '%s %s' "$full" "${full:0:12}"
}

release_dir_for() {  # <id> → the release directory path (never checks that it exists)
  printf '%s/%s' "${YMIR_RELEASES_DIR:-$HOME/ymir-releases}" "${1-}"
}

# ── the swap: one rename, and never a delete before it ────────────────────────
# `ln -s new current.tmp && mv -T current.tmp current` replaces the SYMLINK, not the
# directory it names, in one rename(2). The forbidden form — `rm -f current && ln -s
# new current` — leaves a window where nothing is current; plan 221 §10 records it.
# BSD mv has -h instead of -T; the flag is probed, never assumed (RULES/25).
_RELEASE_MV_FLAG=""
release_mv_flag() {
  [ -n "$_RELEASE_MV_FLAG" ] && { printf '%s' "$_RELEASE_MV_FLAG"; return 0; }
  local d; d="$(mktemp -d 2>/dev/null)" || return 1
  mkdir -p "$d/target" 2>/dev/null
  ln -s "$d/target" "$d/link" 2>/dev/null
  ln -s "$d/target" "$d/tmp" 2>/dev/null
  if mv -T "$d/tmp" "$d/link" 2>/dev/null && [ -L "$d/link" ] && [ ! -e "$d/tmp" ]; then
    _RELEASE_MV_FLAG="-T"; rm -rf "$d"; printf '%s' "-T"; return 0
  fi
  ln -sfn "$d/target" "$d/tmp" 2>/dev/null
  if mv -h "$d/tmp" "$d/link" 2>/dev/null && [ -L "$d/link" ] && [ ! -e "$d/tmp" ]; then
    _RELEASE_MV_FLAG="-h"; rm -rf "$d"; printf '%s' "-h"; return 0
  fi
  rm -rf "$d"
  return 1
}

release_atomic_link() {  # <target> <link> — one rename; never removes <link> first
  local target="${1-}" link="${2-}" flag tmp
  [ -n "$target" ] && [ -n "$link" ] || return 2
  flag="$(release_mv_flag)" || {
    printf 'error: this mv offers neither -T nor -h, so a symlink cannot be swapped in one rename\n' >&2
    printf 'help: the flip refuses rather than deleting the live link first (plan 221 §10)\n' >&2
    return 1
  }
  tmp="${link}.tmp.$$"
  # A leftover temp from a crashed flip is ours to clear; the LINK never is.
  [ -L "$tmp" ] && rm -f "$tmp"
  ln -s "$target" "$tmp" || return 1
  if ! mv "$flag" "$tmp" "$link" 2>/dev/null; then
    rm -f "$tmp"
    return 1
  fi
  [ -L "$link" ] || return 1
  [ "$(release_real "$link")" = "$(release_real "$target")" ] || return 1
  return 0
}

release_log() {  # <action> <rest-of-line...> — append-only, one line per act
  local action="${1-}"; shift || true
  mkdir -p "$(dirname "$YMIR_RELEASES_LOG")" 2>/dev/null || return 1
  printf '%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$action" "$*" >>"$YMIR_RELEASES_LOG"
}

# The release the world currently points at — empty when nothing is current.
release_current() {
  [ -L "$YMIR_CURRENT_LINK" ] || return 1
  local p; p="$(release_real "$YMIR_CURRENT_LINK")"
  [ -n "$p" ] && [ -d "$p" ] && printf '%s' "${p##*/}"
}

release_mtime() {  # <path> → epoch seconds (BSD stat has no -c, GNU has no -f)
  stat -c %Y "${1-}" 2>/dev/null || stat -f %m "${1-}" 2>/dev/null || printf '0'
}

release_size() {  # <path> → apparent size in bytes
  if du -sk "${1-}" >/dev/null 2>&1; then
    du -sk "${1-}" 2>/dev/null | awk '{printf "%d", $1 * 1024}'
  else
    printf '0'
  fi
}

release_human() {  # <bytes> → "612M"
  awk -v b="${1:-0}" 'BEGIN{ split("B K M G T", u, " "); i=1; while (b>=1024 && i<5){ b/=1024; i++ } printf "%d%s", b, u[i] }'
}

release_when() {  # <epoch> → an ISO stamp (GNU date -d, BSD date -r)
  local t="${1:-0}"
  date -u -d "@$t" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
    || date -u -r "$t" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
    || printf '?'
}

# ── retention: keep N, prune by age, BEFORE a build and never after a failure ──
# Plan 221 §10: "every guide keeps N previous releases on disk, because rollback must
# be instant", and the prune runs FIRST so a failed build never costs the release you
# would roll back to. The current release is never a candidate.
release_prune() {  # [--dry-run] → prints one row per kept/pruned release
  local dry=0 keep="${YMIR_RELEASES_KEEP:-3}" cur="" n=0 p id order
  [ "${1-}" = "--dry-run" ] && dry=1
  [ -d "$YMIR_RELEASES_DIR" ] || return 0
  cur="$(release_current || true)"
  # oldest first: rollback must keep the NEWEST, so the sort is by mtime ascending.
  # A glob and a stat, never `find -printf` — BSD find has none (RULES/05).
  order="$(for p in "$YMIR_RELEASES_DIR"/*/; do
             [ -d "$p" ] || continue
             printf '%s %s\n' "$(release_mtime "$p")" "${p%/}"
           done | sort -n | awk '{ $1=""; sub(/^ /,""); print }')"
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    id="${p##*/}"
    case "$id" in *.partial-*|.*) continue ;; esac
    case "$id" in *[!0-9a-f]*) continue ;; esac
    [ "${#id}" -ge 7 ] || continue
    n=$((n + 1))
    if [ -n "$cur" ] && [ "$id" = "$cur" ]; then
      printf '  "%s","keep","the current release"\n' "$id"; continue
    fi
    if [ "$n" -le "$keep" ]; then
      printf '  "%s","keep","within the last %s"\n' "$id" "$keep"; continue
    fi
    if [ "$dry" = 1 ]; then
      printf '  "%s","would-prune","older than the last %s"\n' "$id" "$keep"
    else
      rm -rf -- "$p" && printf '  "%s","pruned","older than the last %s"\n' "$id" "$keep"
    fi
  done <<EOF
$order
EOF
}

# The manifest is the release's own claim about itself; read one field without jq.
release_manifest() {  # <dir> <key> → the value, empty when absent
  local f="${1-}/RELEASE-MANIFEST.json" key="${2-}"
  [ -r "$f" ] || return 1
  sed -n "s/.*\"${key}\": *\"\{0,1\}\([^\",]*\)\"\{0,1\}.*/\1/p" "$f" | head -1
}

# Attribution: a port is served by a pid, and that pid's cwd names the tree it runs
# from. A service "answering" is not a service answering FROM THIS DIRECTORY; the
# cwd (and, for the gate, the root it reports) is what proves it.
release_port_pid() {  # <port> → pid or empty
  local port="${1-}"
  command -v ss >/dev/null 2>&1 || return 1
  ss -lptnH "sport = :$port" 2>/dev/null | grep -o 'pid=[0-9]*' | head -1 | cut -d= -f2
}

release_pid_root() {  # <pid> → the tree the process runs from, or empty
  local pid="${1-}" cwd=""
  [ -n "$pid" ] && [ -d "/proc/$pid" ] || return 1
  cwd="$(release_real "/proc/$pid/cwd" 2>/dev/null)"
  [ -n "$cwd" ] || return 1
  printf '%s' "$cwd"
}

release_under() {  # <path> <root> — 0 when path is root or inside it
  local p="${1-}" r="${2-}"
  [ -n "$p" ] && [ -n "$r" ] || return 1
  [ "$p" = "$r" ] && return 0
  case "$p" in "$r"/*) return 0 ;; esac
  return 1
}
