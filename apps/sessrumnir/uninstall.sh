#!/usr/bin/env bash
# uninstall.sh — take the launcher entry away. Its store (~/.config/sessrumnir) is never touched.
data="${XDG_DATA_HOME:-$HOME/.local/share}"
rm -f "$data/applications/ymir-sessrumnir.desktop" && printf 'sessrumnir: launcher entry removed; ~/.config/sessrumnir is kept\n'
