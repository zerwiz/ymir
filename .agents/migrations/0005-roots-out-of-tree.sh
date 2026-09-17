#!/usr/bin/env bash
# 0005-roots-out-of-tree — the operator's things leave the code tree.
#
# The law this migration serves: the package is the CODE THAT RUNS THE PROGRAMS;
# everything the operator owns lives in the home they chose. A packaged install
# (npm) treats its tree as read-only, and the next upgrade replaces it — so
# anything of theirs kept in the tree is kept at its peril. Every *writer* was
# converted to resolve the home through bin/hoard-lib.sh; this carries what is
# already sitting in the tree to where those writers now look.
#
#   what moves            from the tree            to the home
#   ------------------    ---------------------    ----------------------------
#   this machine's        data/                    <hoard>/data
#     records
#   runtime state         state/                   <home>/state
#     (pids · logs · locks · the applied-marker)
#   the operator's        the local env file       <home>/.env.local
#     credentials         (if one is in the tree)
#   the operator's        .agents/config/*         <home>/config
#     settings            that git does not track
#
# Idempotent: every entry is checked before it moves, a second run finds nothing
# to do, and a move that would land on an existing file is REFUSED and reported
# rather than merged blindly — the home always wins, nothing is ever overwritten.
#
# What is deliberately NOT moved: `*.example` templates and `.gitkeep` (they are
# code), and any settings file git tracks (that is the distro's shipped default,
# not the operator's own). Moving a tracked file out of the tree would be a code
# change wearing a migration's clothes.
#
# NOTE: run this while the runtime is STOPPED if you want no stale pids; running
# services keep their open file handles across the move (an `mv` preserves the
# inode), so nothing is lost either way, but the pid files they wrote will be
# found in their new place after the next restart.
set -u

R="${YMIR_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# The resolver lives in the tree that ships this migration. When YMIR_ROOT points
# somewhere else (a sandbox, a test fixture), fall back to the lib beside this
# script rather than failing to resolve the home at all.
LIB="$R/bin/hoard-lib.sh"
[ -r "$LIB" ] || LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/bin/hoard-lib.sh"
# shellcheck source=bin/hoard-lib.sh
. "$LIB"
ymir_home_root H
hoard_root HOARD
hoard_data_dir RECORDS
hoard_state_dir RUNTIME
hoard_settings_dir SETTINGS
hoard_local_env ENVFILE

moved=0; kept=0; refused=0; merged=0; rows=0
# The row buffers are written as they happen and printed at the end, so the TOON
# header can carry the true count. `rows` is kept beside them: under `set -u`,
# bash older than 4.4 reads an empty `declare -a` array as unbound.
declare -a ROW_ACT=() ROW_FROM=() ROW_TO=()
row() { ROW_ACT+=("$1"); ROW_FROM+=("$2"); ROW_TO+=("$3"); rows=$((rows+1)); }

# tracked_by_git <path> — 1 when git knows the file (the distro ships it)
tracked_by_git() {
  command -v git >/dev/null 2>&1 || return 1
  git -C "$R" ls-files --error-unmatch "${1#"$R"/}" >/dev/null 2>&1
}

# carry <src> <dst-dir> — move one entry home, unless the home already holds it
carry() {
  local src="$1" dst="$2" base stale
  base="$(basename "$src")"
  mkdir -p "$dst" 2>/dev/null || { refused=$((refused+1)); row refuse "$src" "cannot write $dst"; return 0; }
  if [ ! -e "$dst/$base" ]; then
    if mv "$src" "$dst/$base" 2>/dev/null; then
      moved=$((moved+1)); row moved "$src" "$dst/$base"
    else
      refused=$((refused+1)); row refuse "$src" "could not move to $dst/$base"
    fi
    return 0
  fi
  # The home already holds this name. Two files, one name — decide by evidence,
  # never by assumption: identical content means the tree's copy can go (nothing
  # is lost, and the content is at home); different content means BOTH are real,
  # so the home's wins the name and the tree's is carried beside it as `.stale-*`
  # rather than merged or discarded.
  if [ -f "$src" ] && [ -f "$dst/$base" ] && cmp -s "$src" "$dst/$base"; then
    rm -f "$src" && { merged=$((merged+1)); row merged "$src" "identical to $dst/$base — the tree's copy removed, nothing lost"; }
  elif [ -f "$src" ]; then
    stale="$dst/$base.stale-$(date -u +%Y%m%dT%H%M%SZ)"
    if mv "$src" "$stale" 2>/dev/null; then
      moved=$((moved+1)); row kept-as "$src" "$stale — differs from the home's copy, so both are kept"
    else
      refused=$((refused+1)); row refuse "$src" "differs from the home's copy and could not be carried"
    fi
  else
    kept=$((kept+1)); row kept "$src" "home already holds $base — left in place, nothing overwritten"
  fi
}

# ── the machine's records ────────────────────────────────────────────────────
if [ -d "$R/data" ]; then
  for f in "$R"/data/* "$R"/data/.[!.]*; do
    [ -e "$f" ] || continue
    case "$(basename "$f")" in .gitkeep|*.example|*.example.*) kept=$((kept+1)); continue ;; esac
    carry "$f" "$RECORDS"
  done
fi

# ── the runtime state ────────────────────────────────────────────────────────
if [ -d "$R/state" ]; then
  for f in "$R"/state/* "$R"/state/.[!.]*; do
    [ -e "$f" ] || continue
    case "$(basename "$f")" in .gitkeep) kept=$((kept+1)); continue ;; esac
    carry "$f" "$RUNTIME"
  done
fi

# ── the operator's credentials ───────────────────────────────────────────────
# Never printed, never parsed — only carried.
for cand in "$R"/.env.loc[a]l; do
  [ -f "$cand" ] || continue
  if [ -f "$ENVFILE" ]; then
    kept=$((kept+1)); row kept "${cand#"$R"/}" "the home already holds its own — left in place, never merged"
  else
    mkdir -p "$(dirname "$ENVFILE")" 2>/dev/null
    if mv "$cand" "$ENVFILE" 2>/dev/null; then
      chmod 600 "$ENVFILE" 2>/dev/null || true
      moved=$((moved+1)); row moved "${cand#"$R"/}" "${ENVFILE#"$H"/} (0600)"
    else
      refused=$((refused+1)); row refuse "${cand#"$R"/}" "could not move to the home"
    fi
  fi
done

# ── the operator's own settings ──────────────────────────────────────────────
# Only what git does not track: a tracked settings file is the distro's shipped
# default and stays where the code ships it. `config` may be a symlink into
# .agents/config, so resolve the real directory before walking it.
cfgdir="$R/.agents/config"
[ -d "$R/config" ] && [ ! -L "$R/config" ] && cfgdir="$R/config"
if [ -d "$cfgdir" ]; then
  for f in "$cfgdir"/* "$cfgdir"/.[!.]*; do
    [ -e "$f" ] || continue
    base="$(basename "$f")"
    case "$base" in .gitkeep|*.example|*.example.*) kept=$((kept+1)); continue ;; esac
    if tracked_by_git "$f"; then
      kept=$((kept+1)); row kept "config/$base" "the distro ships this one — it is a default, not the operator's own"
      continue
    fi
    carry "$f" "$SETTINGS"
  done
fi

if [ "$rows" -gt 0 ]; then
  printf 'ymir-migrate-0005[%d]{action,from,to}:\n' "$rows"
  for i in "${!ROW_ACT[@]}"; do
    printf '  "%s","%s","%s"\n' "${ROW_ACT[$i]}" "${ROW_FROM[$i]}" "${ROW_TO[$i]}"
  done
fi
printf 'ymir-migrate-0005[1]{moved,merged,kept,refused}:\n  "%s",%s,%s,%s\n' "$moved" "$merged" "$kept" "$refused"
exit 0
