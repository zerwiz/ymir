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
  local result_var=${1-} root="${YMIR_ROOT_DIR:-}" c
  [ -n "$result_var" ] || return 2
  if [ -z "$root" ]; then
    root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  fi
  for c in \
    "$root/apps/$SMIDJA_PACKAGE" \
    "$root/node_modules/@zerwiz/$SMIDJA_PACKAGE" \
    "$root/.agents/skills/$SMIDJA_PACKAGE"
  do
    # A dangling symlink is not a home: the visualizer must be readable there.
    [ -d "$c/apps/visualizer" ] && { printf -v "$result_var" '%s' "$c"; return 0; }
  done
  printf -v "$result_var" '%s' ""
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
