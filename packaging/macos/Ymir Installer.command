#!/usr/bin/env bash
# Ymir Installer.command — double-click this on a Mac.
#
# macOS gets its Linux host the same way Windows does: a VM. This launcher finds
# the Ymir checkout and hands over to bin/bootstrap-macos.sh, which raises Ubuntu
# in Lima and installs Ymir inside it. It is a .command file so Finder runs it on
# a double-click — no terminal knowledge required of the operator.
#
# If there is no checkout yet, it clones one first (the URL below, overridable
# with YMIR_REPO).
set -u
REPO="${YMIR_REPO:-https://github.com/zerwiz/ymir.git}"
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "Ymir — macOS bootstrap"
echo

# 1. find a checkout: beside this file, ~/Ymir, or clone one.
ROOT=""
for cand in "$HERE/../.." "$HOME/Ymir" "$HOME/Documents/Ymir-src"; do
  [ -x "$cand/bin/bootstrap-macos.sh" ] && { ROOT="$(cd "$cand" && pwd)"; break; }
done
if [ -z "$ROOT" ]; then
  echo "cloning Ymir into $HOME/Ymir …"
  git clone "$REPO" "$HOME/Ymir" || { echo "clone failed — set YMIR_REPO to your checkout URL"; read -r -p "press return to close" _; exit 1; }
  ROOT="$HOME/Ymir"
fi

echo "checkout: $ROOT"
echo

# 2. readiness, then the bootstrap. The bootstrap itself is gated on macOS and
#    refuses politely anywhere else, so this launcher stays dumb on purpose.
"$ROOT/bin/bootstrap-macos.sh" --check
echo
read -r -p "Proceed with the install? [y/N] " reply
case "$reply" in
  y|Y|yes|YES) "$ROOT/bin/bootstrap-macos.sh" ;;
  *) echo "nothing changed." ;;
esac

echo
read -r -p "press return to close" _
