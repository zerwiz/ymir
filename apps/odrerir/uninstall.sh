#!/usr/bin/env bash
# uninstall.sh — take the launcher away. The live board in ~/.local/state/odrerir is never touched.
rm -f "${XDG_DATA_HOME:-$HOME/.local/share}/applications/ymir-odrerir.desktop" && printf 'odrerir: launcher entry removed; the board is kept\n'
