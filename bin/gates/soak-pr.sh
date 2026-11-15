#!/usr/bin/env bash
# soak-pr.sh — the P5 door: a pull request that touches an app runs that app's short soak.
#
#   soak-pr.sh                      # the range this branch adds, against its merge base
#   soak-pr.sh <base>..<head>       # an explicit range
#
# It answers three questions in order, and only the third raises a window:
#   1. does the change touch an app at all?          no  → a clean SKIP (nothing to soak)
#   2. can this host raise an app?                   no  → a clean SKIP, with the reason
#   3. does a raised app stay inside plan 286's budgets? → PASS, or FAIL naming the leak
#
# The skip in (2) is real, not a green: a CI runner has no display, no pinned runtime and no
# Electron, so the window proof belongs to the machine. What the gate still proves everywhere
# is that the app's harness exists, its registry answers and its budgets are readable — and
# `bin/gates/tests/test_soak.sh` proves the judge itself on a planted world.
#
# Exit: 0 pass or clean skip · 1 a leak · 2 usage.
set -u

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOAK="$SELF_DIR/soak.sh"
trap ':' EXIT

usage() { sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; }
case "${1-}" in -h|--help) usage; exit 0 ;; -*) printf 'error: unknown flag %s\n' "$1" >&2; exit 2 ;; esac

# The home comes from the ONE resolver, never restated (defaults-guard, Rule 07).
HOARD_LIB="$(cd "$SELF_DIR/.." && pwd)/vault/hoard-lib.sh"
if [ -r "$HOARD_LIB" ]; then . "$HOARD_LIB"; ymir_home_root HOME_DIR; else HOME_DIR="${YMIR_HOME:-}"; fi

repo="$(git -C "$SELF_DIR/.." rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$repo" ] || { printf 'soak_pr[1]{gate,status,detail}:\n  "soak","SKIP","not inside a git checkout"\n'; exit 0; }

# The range: named, or what this branch adds on top of the trunk it will merge into.
if [ -n "${1-}" ]; then range="$1"
elif [ -n "${YMIR_SOAK_RANGE:-}" ]; then range="$YMIR_SOAK_RANGE"
else
  trunk="$(git -C "$repo" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"
  [ -n "$trunk" ] || trunk=main
  base="$(git -C "$repo" merge-base "origin/$trunk" HEAD 2>/dev/null || git -C "$repo" merge-base "$trunk" HEAD 2>/dev/null || true)"
  [ -n "$base" ] || { printf 'soak_pr[1]{gate,status,detail}:\n  "soak","SKIP","no merge base with %s could be found"\n' "$trunk"; exit 0; }
  range="$base..HEAD"
fi

changed="$(git -C "$repo" diff --name-only "$range" 2>/dev/null | grep -E '^apps/(hlidskjalf|smidja-factory|odrerir|sessrumnir|bilskirnir|rodd)/' | head -1 || true)"
if [ -z "$changed" ]; then
  printf 'soak_pr[1]{gate,status,detail}:\n  "soak","SKIP","no app changed in %s"\n' "$range"
  exit 0
fi

# Can this host raise the window at all?
why=""
[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] || why="no display on this host"
[ -n "$why" ] || [ -d "${YMIR_RUNTIME_DIR:-$HOME/ymir-runtime}/apps" ] || why="no pinned runtime at ~/ymir-runtime"
[ -n "$why" ] || command -v node >/dev/null 2>&1 || why="node is not installed"
[ -n "$why" ] || [ -n "$(ls -d "$HOME/ymir-runtime"/node_modules/electron/dist/electron 2>/dev/null)" ] || why="no Electron runtime in the pin"
if [ -n "$why" ]; then
  printf 'soak_pr[1]{gate,status,detail}:\n  "soak","SKIP","%s — the app soak runs on a seat, not here (%s)"\n' "$why" "$range"
  exit 0
fi

desk="$(bash "$SELF_DIR/../desk/in-call.sh" holder 2>/dev/null | tr -d '\n')"
if [ -n "$desk" ]; then
  printf 'soak_pr[1]{gate,status,detail}:\n  "soak","SKIP","the desk is in a call (%s) — no app is raised while it is"\n' "$desk"
  exit 0
fi

YMIR_SOAK_REPO="$repo" bash "$SOAK" --pr-range "$range"
