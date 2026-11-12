#!/usr/bin/env bash
# raise.sh — the whole house in one word: the web AND the windows.
#
# scripts/start.sh raises the services; scripts/electron.sh raises the desktop
# shells. Two lifecycles that never met — which is why "the electrons are not
# running" was true while 28 processes stood, and why a web restart left the
# shells pointing at a dead port. This is the pair of hands.
#
#   scripts/raise.sh              # services + every desktop shell
#   scripts/raise.sh --web        # the services only
#   scripts/raise.sh --desktop    # the shells only
#   scripts/raise.sh --root       # print the tree this script resolves

# ── THE APPS RUN FROM MAIN, NOT FROM A WORKTREE (the Allfather, 2026-11-08: "are this the full apps. not
# just the start buttons?"). The launcher entries were only the visible half: the RUNTIME is this script,
# its node_modules, its built assets and the processes it raises. So a worktree re-executes the canonical
# tree's copy of this very script, and everything below it — Electron, the assets, the API — comes from main.
if [ -z "${YMIR_ALLOW_WORKTREE_RUNTIME:-}" ]; then
  # Compare ROOT with ROOT (2026-11-12): the old guard compared the canonical root with this script's own
  # folder, so from scripts/ it always fired and re-ran "<root>/electron.sh" (no such file) — every icon on
  # the pin died; from bin/desktop/ it looked for the resolver one level too high and never ran at all.
  _self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
  _root="$(dirname "$_self")"
  while [ "$_root" != / ] && [ ! -f "$_root/bin/desktop/main-tree.sh" ]; do _root="$(dirname "$_root")"; done
  _canon="$(bash "$_root/bin/desktop/main-tree.sh" "$_root" 2>/dev/null || true)"
  if [ -n "${_canon:-}" ] && [ "$_canon" != "$_root" ] && [ -f "$_canon/${_self#"$_root"/}" ]; then
    printf '%s: running from a WORKTREE — the app runtime is locked to main (%s), re-executing there\n' \
      "$(basename "$0")" "$_canon" >&2
    exec bash "$_canon/${_self#"$_root"/}" "$@"
  fi
fi
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

WHAT="all"
case "${1-}" in
  --web) WHAT=web ;;
  --desktop) WHAT=desktop ;;
  # --root: where this script thinks the tree is (plan 221 P0 proves a release with it)
  --root) printf '%s\n' "$ROOT"; exit 0 ;;
  -h|--help|"") sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

if [ "$WHAT" != "desktop" ]; then
  printf '\n— the web —\n'
  "$ROOT/scripts/start.sh" || printf 'raise: start.sh reported errors\n' >&2
fi

if [ "$WHAT" != "web" ]; then
  printf '\n— the windows —\n'
  # Every shell, by name: hlidskjalf is the default view; smidja and odrerir need
  # their own start; sessrumnir is its own app.
  "$ROOT/scripts/electron.sh" start || printf 'raise: hlidskjalf failed\n' >&2
  for v in smidja odrerir; do
    "$ROOT/scripts/electron.sh" start --view "$v" || printf 'raise: %s failed\n' "$v" >&2
  done
  if [ -x "$ROOT/bin/desktop/sessrumnir-launch.sh" ]; then
    "$ROOT/bin/desktop/sessrumnir-launch.sh" start || printf 'raise: sessrumnir failed\n' >&2
  fi
  printf '\n'
  "$ROOT/scripts/electron.sh" status
fi
