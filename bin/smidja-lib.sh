#!/usr/bin/env bash
# smidja-lib.sh — where the smithy's parts actually live.
#
# Two installs, one name. In a clone the smithy sits at `apps/smidja-factory`
# (the registry's `repo: apps/<path>` block clones it there), and
# `.agents/skills/smidja-factory` is a symlink to it. In a packaged install the
# tree has no `apps/` at all: the smithy arrives as a dependency, at
# `node_modules/@zerwiz/smidja-factory`, and that symlink dangles.
#
# Every script that needs the visualizer resolves it HERE, so the two shapes can
# never disagree (Rule 07). Source-safe; defines functions only.
#
#   smidja_factory_dir    <result-var>   the smithy: skill, skills/, templates/, apps/
#   smidja_visualizer_dir <result-var>   the board: its server, its UI source, its dist
set -u

# A surface has a name the operator knows and a package has a name npm serves;
# they are not always the same, and the smithy is the pair that proves it.
SMIDJA_SURFACE="smidja"
SMIDJA_PACKAGE="smidja-factory"

smidja_factory_dir() {  # <result-var> — the smithy's directory, or empty
  # The general resolver (bin/app-lib.sh) knows both shapes; the smithy is one
  # surface among them. The old skill symlink is the last resort, and a dangling
  # one is not a home — the visualizer must be readable there.
  local _smd_rv=${1-} _smd_c
  [ -n "$_smd_rv" ] || return 2
  if [ -z "${YMIR_APP_LIB_LOADED:-}" ]; then
    local _sl; _sl="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    [ -r "$_sl/app-lib.sh" ] && { . "$_sl/app-lib.sh"; YMIR_APP_LIB_LOADED=1; }
  fi
  if app_dir smidja _smd_c 2>/dev/null && [ -d "$_smd_c/apps/visualizer" ]; then
    printf -v "$_smd_rv" '%s' "$_smd_c"; return 0
  fi
  _smd_c="${YMIR_ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/.agents/skills/$SMIDJA_PACKAGE"
  [ -d "$_smd_c/apps/visualizer" ] && { printf -v "$_smd_rv" '%s' "$_smd_c"; return 0; }
  printf -v "$_smd_rv" '%s' ""
  return 1
}

smidja_visualizer_dir() {  # <result-var> — the visualizer (server · UI source · dist)
  local result_var=${1-} factory
  [ -n "$result_var" ] || return 2
  if smidja_factory_dir factory; then
    printf -v "$result_var" '%s' "$factory/apps/visualizer"
    return 0
  fi
  printf -v "$result_var" '%s' ""
  return 1
}
