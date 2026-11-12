#!/usr/bin/env bash
# data-home.sh — Bilskirnir's state lives in ONE place per user, never inside a checkout (plan 275 S5).
#
# WHY (measured 2026-11-12): the hall kept its database, agents, engines, desk and `.env` under
# apps/bilskirnir/ of whichever checkout ran it. When the launcher moved to the pinned runtime, the icon opened a
# second, empty hall — the operator's agents and conversations were still in the working tree's copy.
#
#   apps/bilskirnir/scripts/data-home.sh [--check]
#
# The home is BILSKIRNIR_DATA_HOME, else ${XDG_DATA_HOME:-~/.local/share}/ymir/bilskirnir. It holds `data/` and
# `.env`; the checkout gets two links. Nothing is ever deleted:
#   · no home yet, the checkout has real state  → the state MOVES into the home, then is linked
#   · a home exists, the checkout has its own   → the checkout's copy is set aside as <name>.aside-<stamp>, then linked
#   · already linked                             → nothing to do
# --check prints `linked` (exit 0) or what would change (exit 1), and changes nothing.
set -u
APP="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOME_DIR="${BILSKIRNIR_DATA_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/ymir/bilskirnir}"
STAMP="$(date +%Y%m%d-%H%M%S)"

# With no home yet, the REAL hall is chosen, not whichever checkout runs first: every Bilskirnir checkout on this
# machine is a candidate (this one, the main tree, the pinned runtime), and the one with the largest database —
# the most agents and conversations — donates its state. The others set theirs aside when they run.
donor="$APP"
if [ ! -e "$HOME_DIR/data" ]; then
  best=0
  for c in "$APP" "${YMIR_RUNTIME_DIR:-$HOME/ymir-runtime}/apps/bilskirnir" ${BILSKIRNIR_CANDIDATES:-}; do
    db="$c/data/grokbot.db"
    [ -f "$db" ] && [ ! -L "$c/data" ] || continue
    # never take a hall from under a running server: its own start will link it when it next runs
    [ "$c" != "$APP" ] && [ -f "$c/data/run/server.pid" ] && kill -0 "$(cat "$c/data/run/server.pid" 2>/dev/null)" 2>/dev/null && continue
    sz=$(stat -c %s "$db" 2>/dev/null || echo 0)
    [ "$sz" -gt "$best" ] && { best=$sz; donor="$(cd "$c" && pwd)"; }
  done
  _mt="$APP"; while [ "$_mt" != / ] && [ ! -f "$_mt/bin/desktop/main-tree.sh" ]; do _mt="$(dirname "$_mt")"; done
  _canon="$(bash "$_mt/bin/desktop/main-tree.sh" "$_mt" 2>/dev/null || true)"
  db="${_canon:-/nonexistent}/apps/bilskirnir/data/grokbot.db"
  if [ -f "$db" ] && [ ! -L "${_canon}/apps/bilskirnir/data" ]; then
    sz=$(stat -c %s "$db" 2>/dev/null || echo 0); [ "$sz" -gt "$best" ] && donor="${_canon}/apps/bilskirnir"
  fi
fi
check=0; [ "${1:-}" = "--check" ] && check=1

state=0
for name in data .env; do
  here="$APP/$name"; there="$HOME_DIR/$name"
  if [ -L "$here" ] && [ "$(readlink -f "$here")" = "$(readlink -f "$there" 2>/dev/null || printf '%s' "$there")" ]; then
    continue
  fi
  state=1
  if [ "$check" = 1 ]; then
    if [ -e "$there" ]; then printf 'would link %s → %s (the checkout copy set aside)\n' "$name" "$there"
    elif [ -e "$here" ]; then printf 'would move %s into %s\n' "$name" "$HOME_DIR"
    else printf 'would create %s in %s\n' "$name" "$HOME_DIR"; fi
    continue
  fi
  mkdir -p "$HOME_DIR"
  if [ -e "$there" ]; then
    # the home already has it: keep this checkout's copy beside it, never lose it
    [ -e "$here" ] || [ -L "$here" ] && mv "$here" "$here.aside-$STAMP"
  elif [ "$donor" != "$APP" ] && { [ -e "$donor/$name" ] && [ ! -L "$donor/$name" ]; }; then
    # another checkout holds the real hall: it moves into the home, and is linked where it was
    mv "$donor/$name" "$there" && ln -s "$there" "$donor/$name"
    [ -e "$here" ] || [ -L "$here" ] && mv "$here" "$here.aside-$STAMP"
  elif [ -e "$here" ] && [ ! -L "$here" ]; then
    mv "$here" "$there"
  else
    rm -f "$here" 2>/dev/null
    if [ "$name" = data ]; then mkdir -p "$there"; else : > "$there"; chmod 600 "$there"; fi
  fi
  ln -s "$there" "$here"
  printf 'data-home: %s → %s\n' "$name" "$there"
done

if [ "$check" = 1 ]; then
  [ "$state" = 0 ] && { printf 'linked\t%s\n' "$HOME_DIR"; exit 0; }
  exit 1
fi
exit 0
