#!/bin/bash
# zed-blur-generator.sh — the adaptive blurred Zed theme
#
# Reads the LIVE omarchy theme's colors.toml and forges a blurred, see-through
# Zed theme from it, then points Zed's settings at it. Installed as a theme-set
# hook (theme-set.d/zed-blur) so it re-runs on EVERY omarchy theme switch —
# the Zed theme follows whatever theme omarchy wears, like pi's omarchy-system.
#
# The blur recipe (proven by catppuccin-blur / blankeos-zen-dark-blurred):
#   background.appearance = "blurred"
#   editor/panel/tab chrome  = background @ 00 alpha  (fully see-through)
#   window chrome (title/status/elevated) = background @ d0/d8/e0 alpha
#   text + syntax stay opaque for readability.
#
# Usage: zed-blur-generator.sh [theme-name]   (theme-name arg mirrors omazed's
# hook contract; the live theme is read regardless)

set -euo pipefail

# --- resolve the live omarchy theme path (v4 then v3, like omazed) ----------
OMARCHY_THEME_PATH_V4="$HOME/.local/state/omarchy/current/theme"
OMARCHY_THEME_PATH_V3="$HOME/.config/omarchy/current/theme"
THEME_PATH="$OMARCHY_THEME_PATH_V3"
if [[ -d "$OMARCHY_THEME_PATH_V4" ]]; then
  THEME_PATH="$OMARCHY_THEME_PATH_V4"
fi

COLORS_TOML="$THEME_PATH/colors.toml"
if [[ ! -f "$COLORS_TOML" ]]; then
  echo "zed-blur: no colors.toml at $COLORS_TOML" >&2
  exit 1
fi

ZED_THEMES_DIR="$HOME/.config/zed/themes"
ZED_SETTINGS="$HOME/.config/zed/settings.json"
OUT="$ZED_THEMES_DIR/omarchy-blur.json"
THEME_NAME="Omarchy Blur"
mkdir -p "$ZED_THEMES_DIR"

# --- parse a key from colors.toml (key = "value" | key = value) -------------
parse_key() {
  grep -E "^[[:space:]]*$1[[:space:]]*=" "$COLORS_TOML" | head -1 \
    | sed -E 's/^[^=]*=[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/' | tr -d '\r'
}

BG="$(parse_key background)";        BG="${BG:-#000000}"
FG="$(parse_key foreground)";        FG="${FG:-#ffffff}"
AC="$(parse_key accent)";            AC="${AC:-$FG}"
CURSOR="$(parse_key cursor)";        CURSOR="${CURSOR:-$AC}"
SEL_BG="$(parse_key selection_background)"; SEL_BG="${SEL_BG:-$AC}"
SEL_FG="$(parse_key selection_foreground)"; SEL_FG="${SEL_FG:-$BG}"
C0="$(parse_key color0)";   C0="${C0:-$BG}"
C1="$(parse_key color1)";   C1="${C1:-$AC}"
C2="$(parse_key color2)";   C2="${C2:-#22c55e}"
C3="$(parse_key color3)";   C3="${C3:-#eab308}"
C4="$(parse_key color4)";   C4="${C4:-$AC}"
C5="$(parse_key color5)";   C5="${C5:-#a855f7}"
C6="$(parse_key color6)";   C6="${C6:-#06b6d4}"
C7="$(parse_key color7)";   C7="${C7:-$FG}"
C8="$(parse_key color8)";   C8="${C8:-$C0}"
C9="$(parse_key color9)";   C9="${C9:-$C1}"
C10="$(parse_key color10)"; C10="${C10:-$C2}"
C11="$(parse_key color11)"; C11="${C11:-$C3}"
C12="$(parse_key color12)"; C12="${C12:-$C4}"
C13="$(parse_key color13)"; C13="${C13:-$C5}"
C14="$(parse_key color14)"; C14="${C14:-$C6}"
C15="$(parse_key color15)"; C15="${C15:-$C7}"

# --- derive muted/dim from foreground over background (simple 60/30 blend) --
blend() { # $1=hex1 $2=hex2 $3=percent-of-hex1
  local r1 g1 b1 r2 g2 b2 p q r g b
  r1=$((16#${1:1:2})); g1=$((16#${1:3:2})); b1=$((16#${1:5:2}))
  r2=$((16#${2:1:2})); g2=$((16#${2:3:2})); b2=$((16#${2:5:2}))
  p=$3; q=$((100 - p))
  r=$(( (r1 * p + r2 * q) / 100 )); g=$(( (g1 * p + g2 * q) / 100 )); b=$(( (b1 * p + b2 * q) / 100 ))
  printf '#%02x%02x%02x' "$r" "$g" "$b"
}
MUTED="$(blend "$FG" "$BG" 55)"
DIM="$(blend "$FG" "$BG" 30)"
SURF="$(blend "$BG" "$FG" 8)"        # hover surface (bg toward fg 8%)

# --- alpha helpers -----------------------------------------------------------
a() { printf '%s%s' "$1" "$2"; }   # $1=hex $2=alpha hex suffix (00, 33, d0, …)
A00="00"; A33="33"; A4C="4c"; A66="66"; A7F="7f"; A90="90"; A8C="8c"
AB3="b3"; ACC="cc"; AD0="d0"; AD8="d8"; AE0="e0"

# --- forge the theme ----------------------------------------------------------
cat > "$OUT" <<EOF
{
  "\$schema": "https://zed.dev/schema/themes/v0.2.0.json",
  "name": "$THEME_NAME",
  "author": "Brokk (Ymir) — adaptive blurred theme, follows the live omarchy theme",
  "themes": [
    {
      "name": "$THEME_NAME",
      "appearance": "dark",
      "style": {
        "background.appearance": "blurred",
        "background": "$(a "$BG" $AD0)",
        "foreground": "$FG",
        "border": "$(a "$BG" $A90)",
        "border.variant": "$SURF",
        "border.focused": "$AC",
        "border.selected": "$AC",
        "border.transparent": "#00000000",
        "border.disabled": "$SURF",
        "elevated_surface.background": "$(a "$BG" $AE0)",
        "surface.background": "$(a "$BG" $AD8)",
        "drop_target.background": "$(a "$AC" $A33)",
        "element.background": "$(a "$BG" $ACC)",
        "element.hover": "$SURF",
        "element.active": "$(a "$AC" $A66)",
        "element.selected": "$SURF",
        "element.disabled": "$MUTED",
        "ghost_element.background": "#00000000",
        "ghost_element.hover": "$SURF",
        "ghost_element.active": "$(a "$AC" $A66)",
        "ghost_element.selected": "$(a "$AC" $A33)",
        "ghost_element.disabled": "$SURF",
        "text": "$FG",
        "text.muted": "$MUTED",
        "text.placeholder": "$MUTED",
        "text.disabled": "$MUTED",
        "text.accent": "$AC",
        "icon": "$FG",
        "icon.muted": "$MUTED",
        "icon.disabled": "$MUTED",
        "icon.placeholder": "$MUTED",
        "icon.accent": "$AC",
        "status_bar.background": "$(a "$BG" $AD0)",
        "title_bar.background": "$(a "$BG" $AD0)",
        "title_bar.inactive_background": "$(a "$BG" $AB3)",
        "toolbar.background": "$(a "$BG" $A00)",
        "tab_bar.background": "$(a "$BG" $A00)",
        "tab.inactive_background": "$(a "$BG" $A00)",
        "tab.active_background": "$(a "$BG" $ACC)",
        "search.match_background": "$SURF",
        "panel.background": "$(a "$BG" $A00)",
        "panel.focused_border": "$AC",
        "pane.focused_border": "$AC",
        "scrollbar.thumb.background": "$(a "$FG" $A4C)",
        "scrollbar.thumb.hover_background": "$(a "$FG" $A7F)",
        "scrollbar.thumb.border": "#00000000",
        "scrollbar.track.background": "#00000000",
        "scrollbar.track.border": "#00000000",
        "editor.foreground": "$FG",
        "editor.background": "$(a "$BG" $A00)",
        "editor.gutter.background": "$(a "$BG" $A00)",
        "editor.subheader.background": "$(a "$BG" $A00)",
        "editor.active_line.background": "$SURF",
        "editor.highlighted_line.background": "$SURF",
        "editor.line_number": "$MUTED",
        "editor.active_line_number": "$FG",
        "editor.invisible": "$MUTED",
        "editor.wrap_guide": "$SURF",
        "editor.active_wrap_guide": "$MUTED",
        "editor.document_highlight.read_background": "$(a "$AC" $A33)",
        "editor.document_highlight.write_background": "$(a "$AC" $A33)",
        "terminal.background": "$(a "$BG" $A00)",
        "terminal.foreground": "$FG",
        "terminal.bright_foreground": "$FG",
        "terminal.dim_foreground": "$MUTED",
        "terminal.ansi.black": "$C0",
        "terminal.ansi.bright_black": "$C8",
        "terminal.ansi.dim_black": "$C0",
        "terminal.ansi.red": "$C1",
        "terminal.ansi.bright_red": "$C9",
        "terminal.ansi.dim_red": "$C1",
        "terminal.ansi.green": "$C2",
        "terminal.ansi.bright_green": "$C10",
        "terminal.ansi.dim_green": "$C2",
        "terminal.ansi.yellow": "$C3",
        "terminal.ansi.bright_yellow": "$C11",
        "terminal.ansi.dim_yellow": "$C3",
        "terminal.ansi.blue": "$C4",
        "terminal.ansi.bright_blue": "$C12",
        "terminal.ansi.dim_blue": "$C4",
        "terminal.ansi.magenta": "$C5",
        "terminal.ansi.bright_magenta": "$C13",
        "terminal.ansi.dim_magenta": "$C5",
        "terminal.ansi.cyan": "$C6",
        "terminal.ansi.bright_cyan": "$C14",
        "terminal.ansi.dim_cyan": "$C6",
        "terminal.ansi.white": "$C7",
        "terminal.ansi.bright_white": "$C15",
        "terminal.ansi.dim_white": "$C7",
        "link_text.hover": "$AC",
        "conflict": "$C3",
        "conflict.background": "$(a "$C3" $A33)",
        "conflict.border": "$C3",
        "created": "$C2",
        "created.background": "$(a "$C2" $A33)",
        "created.border": "$C2",
        "deleted": "$C1",
        "deleted.background": "$(a "$C1" $A33)",
        "deleted.border": "$C1",
        "error": "$C1",
        "error.background": "$(a "$C1" $A33)",
        "error.border": "$C1",
        "hidden": "$MUTED",
        "hidden.background": "$(a "$BG" $A00)",
        "hidden.border": "$SURF",
        "hint": "$MUTED",
        "hint.background": "$(a "$AC" $A33)",
        "hint.border": "$AC",
        "ignored": "$MUTED",
        "ignored.background": "$(a "$BG" $A00)",
        "ignored.border": "$SURF",
        "info": "$AC",
        "info.background": "$(a "$AC" $A33)",
        "info.border": "$AC",
        "modified": "$C3",
        "modified.background": "$(a "$C3" $A33)",
        "modified.border": "$C3",
        "predictive": "$MUTED",
        "predictive.background": "$SURF",
        "predictive.border": "$SURF",
        "renamed": "$AC",
        "renamed.background": "$(a "$AC" $A33)",
        "renamed.border": "$AC",
        "success": "$C2",
        "success.background": "$(a "$C2" $A33)",
        "success.border": "$C2",
        "unreachable": "$MUTED",
        "unreachable.background": "$(a "$BG" $A00)",
        "unreachable.border": "$SURF",
        "warning": "$C3",
        "warning.background": "$(a "$C3" $A66)",
        "warning.border": "$C3",
        "players": [
          { "cursor": "$AC", "background": "$AC", "selection": "$(a "$AC" $A33)" },
          { "cursor": "$C5", "background": "$C5", "selection": "$(a "$C5" $A33)" },
          { "cursor": "$C6", "background": "$C6", "selection": "$(a "$C6" $A33)" },
          { "cursor": "$C2", "background": "$C2", "selection": "$(a "$C2" $A33)" }
        ],
        "version_control.added": "$C2",
        "version_control.added_background": "$(a "$C2" $A33)",
        "version_control.deleted": "$C1",
        "version_control.deleted_background": "$(a "$C1" $A33)",
        "version_control.modified": "$C3",
        "version_control.modified_background": "$(a "$C3" $A33)",
        "syntax": {
          "attribute": { "color": "$C3", "font_style": null, "font_weight": null },
          "boolean": { "color": "$C1", "font_style": null, "font_weight": null },
          "comment": { "color": "$MUTED", "font_style": "italic", "font_weight": null },
          "comment.doc": { "color": "$MUTED", "font_style": "italic", "font_weight": null },
          "constant": { "color": "$C1", "font_style": null, "font_weight": null },
          "constructor": { "color": "$C5", "font_style": null, "font_weight": null },
          "embedded": { "color": "$FG", "font_style": null, "font_weight": null },
          "emphasis": { "color": "$C1", "font_style": "italic", "font_weight": null },
          "emphasis.strong": { "color": "$C1", "font_style": null, "font_weight": 700 },
          "enum": { "color": "$C6", "font_style": null, "font_weight": null },
          "function": { "color": "$C4", "font_style": null, "font_weight": null },
          "hint": { "color": "$C6", "font_style": null, "font_weight": 700 },
          "keyword": { "color": "$C5", "font_style": null, "font_weight": null },
          "label": { "color": "$C4", "font_style": null, "font_weight": null },
          "link_text": { "color": "$C4", "font_style": "italic", "font_weight": null },
          "link_uri": { "color": "$C5", "font_style": null, "font_weight": null },
          "number": { "color": "$C1", "font_style": null, "font_weight": null },
          "operator": { "color": "$C6", "font_style": null, "font_weight": null },
          "predictive": { "color": "$MUTED", "font_style": "italic", "font_weight": null },
          "preproc": { "color": "$FG", "font_style": null, "font_weight": null },
          "primary": { "color": "$FG", "font_style": null, "font_weight": null },
          "property": { "color": "$C4", "font_style": null, "font_weight": null },
          "punctuation": { "color": "$MUTED", "font_style": null, "font_weight": null },
          "punctuation.bracket": { "color": "$MUTED", "font_style": null, "font_weight": null },
          "punctuation.delimiter": { "color": "$MUTED", "font_style": null, "font_weight": null },
          "punctuation.list_marker": { "color": "$MUTED", "font_style": null, "font_weight": null },
          "punctuation.special": { "color": "$C6", "font_style": null, "font_weight": null },
          "string": { "color": "$C2", "font_style": null, "font_weight": null },
          "string.escape": { "color": "$C5", "font_style": null, "font_weight": null },
          "string.regex": { "color": "$C6", "font_style": null, "font_weight": null },
          "string.special": { "color": "$C5", "font_style": null, "font_weight": null },
          "string.special.symbol": { "color": "$C2", "font_style": null, "font_weight": null },
          "tag": { "color": "$C4", "font_style": null, "font_weight": null },
          "text.literal": { "color": "$C2", "font_style": null, "font_weight": null },
          "title": { "color": "$C4", "font_style": null, "font_weight": 700 },
          "type": { "color": "$C3", "font_style": null, "font_weight": null },
          "variable": { "color": "$FG", "font_style": null, "font_weight": null },
          "variable.special": { "color": "$C1", "font_style": null, "font_weight": null },
          "variant": { "color": "$C4", "font_style": null, "font_weight": null }
        }
      }
    }
  ]
}
EOF

# --- point Zed at it ----------------------------------------------------------
if [[ -f "$ZED_SETTINGS" ]]; then
  python3 - "$ZED_SETTINGS" "$THEME_NAME" <<'PY'
import json, sys
path, name = sys.argv[1], sys.argv[2]
with open(path) as f:
    s = json.load(f)
s["theme"] = name
with open(path, "w") as f:
    json.dump(s, f, indent=2)
    f.write("\n")
PY
else
  printf '{\n  "theme": "%s"\n}\n' "$THEME_NAME" > "$ZED_SETTINGS"
fi

echo "zed-blur: forged $THEME_NAME from $(basename "$THEME_PATH") -> $OUT"