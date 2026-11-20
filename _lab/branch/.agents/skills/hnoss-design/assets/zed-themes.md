# zed-themes — forging a Zed editor theme from the omarchy palette

> **Craft:** Hnoss, the design smithy — an asset under `hnoss-design`.
> **Load when:** the task is a Zed editor theme, a theme "for zed", a
> see-through/blurred editor theme, or any "make it look like omarchy" ask
> aimed at an editor rather than the desktop.
> **Forged:** 2026-09-24, from the live Aetheria theme on the heimdall seat.

## 1. The errand's true shape

When the Allfather says "make a theme for zed following the omarchy theme", the
deliverable is **one JSON file in `~/.config/zed/themes/`** and a one-line
pointer in `~/.config/zed/settings.json`. That is the whole errand.

**The trap (learned the loud way):** do **not** touch Hyprland, omarchy's
`hyprland.lua`, window rules, or blur settings for this ask. The compositor and
the editor are separate halls. A Zed theme errand ends at Zed's config; a
compositor blur rule is a *separate* errand the Allfather must request on its
own. On 2026-09-24 a stray `o.window("dev.zed.Zed", { blur = true })` was added
to `~/.config/hypr/hyprland.lua` and failed validation
(`hl.window_rule: unknown field 'blur'`) — it was reverted. The house law:
**the errand's scope is sacred; never widen it.**

## 2. Where the omarchy palette lives

The active omarchy theme is the source of truth. On this box:

```
~/.config/omarchy/themes/<theme>/colors.toml   # the palette (Aetheria, Andlangr, …)
```

`omarchy theme list` names the installed themes; the first is the live one
(Aetheria on heimdall). `colors.toml` carries the canonical tokens:

```
accent / cursor / foreground / background
selection_foreground / selection_background
color0 … color15          # the ANSI terminal ladder
```

Aetheria's tokens (the palette the 2026-09-24 theme was forged from):

```
palette[8]{token,value}:
  "background","#0e091d"   (violet-night — the soul of the theme)
  "foreground","#14B9B5"   (teal — the primary text)
  "accent","#BE3F50"       (berry — focus, selection, borders)
  "cursor","#ff7f41"       (ember — cursor / accent text)
  "selection_background","#14B9B5"
  "selection_foreground","#0e091d"
  "muted","#118789"        (derived teal — dimmed text, gutters; from color15 #11AEB3 blended down)
  "surface","#262133"      (derived violet — hover, active lines)
```

## 3. The Zed theme file

- **Location:** `~/.config/zed/themes/<name>.json` — Zed loads every JSON in
  this directory at launch; the theme picker lists each file's `themes[].name`.
- **Schema:** `https://zed.dev/schema/themes/v0.2.0.json` (the current one —
  `v0.1.0.json` is older; prefer 0.2.0 which accepts the full key set).
- **Shape:** one outer `themes[]` array; each entry has `name`, `appearance`
  (`"dark"` for Aetheria-family), and `style`.
- **Key families in `style`:**
  - `background` / `surface.background` / `elevated_surface.background` — the
    window, panels, popovers
  - `text` / `text.muted` / `text.accent` / `icon.*` — ink
  - `editor.background` / `editor.gutter.background` / `editor.line_number` /
    `editor.active_line.background` — the pane
  - `status_bar.background` / `title_bar.background` / `toolbar.background` /
    `tab_bar.background` / `tab.active_background` — chrome
  - `terminal.ansi.*` — the terminal ladder (map straight from `color0…15`)
  - `syntax.*` — token colors; each entry is `{ color, font_style, font_weight }`
  - `players[]` — collaborator cursors (one per hue)

## 4. The blurred / see-through recipe

Zed renders translucency from **alpha-channelled hex** (`#RRGGBBAA`) plus one
flag. The proven recipe (mirrors the `catppuccin-blur` and `blankeos-zen`
blurred extensions, and the forged `Aetheria Blur`):

```
blur_recipe[4]{key,value,why}:
  "background.appearance","\"blurred\"","tells Zed this theme is meant for a see-through window"
  "background","#0e091dd0","the base surface at ~82% — the desktop shows through softly"
  "editor.background","#0e091d00","the pane itself fully transparent — the blur shows behind the code"
  "panel/toolbar/tab chrome","#0e091d00","chrome melts away; only bars with text keep #0e091dd0"
```

Keep **text and syntax colors opaque** — translucency belongs to surfaces, never
to ink. A `00` alpha on the editor is the whole trick: the compositor's blur
(where enabled) renders behind the code.

## 5. Mapping Aetheria → the ANSI ladder

`colors.toml`'s `color0…color15` map to `terminal.ansi.*` in order:

```
ansi_map[16]{toml,zed}:
  "color0","terminal.ansi.black"
  "color1","terminal.ansi.red"
  "color2","terminal.ansi.green"
  "color3","terminal.ansi.yellow"
  "color4","terminal.ansi.blue"
  "color5","terminal.ansi.magenta"
  "color6","terminal.ansi.cyan"
  "color7","terminal.ansi.white"
  "color8","terminal.ansi.bright_black"
  "color9","terminal.ansi.bright_red"
  "color10","terminal.ansi.bright_green"
  "color11","terminal.ansi.bright_yellow"
  "color12","terminal.ansi.bright_blue"
  "color13","terminal.ansi.bright_magenta"
  "color14","terminal.ansi.bright_cyan"
  "color15","terminal.ansi.bright_white"
```

Aetheria's notable quirk: its ladder is **not** conventional (red is lime
`#c8e967`, green is crimson `#E20342`). Map it faithfully — the omarchy soul is
in the surprise.

## 6. Syntax tokens (the Aetheria voice)

The forged theme's syntax map — the load-bearing choices:

```
syntax[8]{token,color,role}:
  "string","#E20342","crimson — strings carry the theme's heat"
  "comment","#118789","muted teal, italic — whispers"
  "function","#BE3F50","berry — the accent, call sites"
  "keyword","#9147a8","violet — control words"
  "number","#c8e967","lime — numerals stand out"
  "type","#7cd699","green-teal — type names"
  "variable","#14B9B5","teal — the primary ink"
  "operator","#FF7F41","ember — operators glow"
```

## 7. Pointing Zed at the theme

`~/.config/zed/settings.json` is a single JSON line. Set `"theme"` to the
theme's `themes[].name` exactly:

```json
{"theme": "Aetheria Blur"}
```

(Keep any other keys already present — icon_theme, agent, project_panel, … —
untouched; edit only the `theme` value.)

## 8. Verification (before claiming done)

```
verify[4]{check,command}:
  "JSON parses","python3 -c \"import json; json.load(open('<theme>.json'))\""
  "name + appearance","read the file: themes[0].name and .appearance are right"
  "settings pointer","~/.config/zed/settings.json carries the exact theme name"
  "picker sees it","launch Zed; the theme appears in the theme picker (themes dir is read at launch)"
```

The file is read at launch — a running Zed needs a restart (or theme re-pick)
to show a new theme. No compositor reload, no configerrors, no window rules.

## 9. Extending to another omarchy theme

Andlangr and the stock themes each carry their own `colors.toml`. The recipe is
palette-agnostic: read that theme's tokens, map §2/§5/§6, name the Zed file
`<theme>-blur.json`, set `"theme"` to the same name. The blurred recipe is the
same for every dark omarchy theme.

## 10. The adaptive generator (the true errand — follows the live theme)

> **Added 2026-09-24.** The Allfather's real ask was not a static theme: it is a
> blurred Zed theme that **adapts to whatever omarchy theme is live**, the way
> pi's own theme does (`~/.pi/agent/themes/omarchy-system.json` is regenerated
> from the live theme via `pi.json.tpl`). The sibling pattern already existed on
> this box: `omazed` (`/usr/bin/omazed` + `/usr/bin/omazed-generator.sh` +
> `/usr/bin/omazed-theme.tpl`) — a generator plus a `theme-set` hook that
> re-forges a Zed theme on **every omarchy theme switch**. Its template is not
> blurred. The blurred adaptive twin is:
>
> - **Generator:** `assets/zed-blur-generator.sh` (this skill) — installed at
>   `~/.local/bin/zed-blur-generator.sh`.
> - **Hook:** `~/.config/omarchy/hooks/theme-set.d/zed-blur` — calls the
>   generator with the theme name, exactly like `omazed`'s hook.
>
> **How it works:**
>
> ```
> adaptive[5]{step,what}:
>   "read","resolve the live theme path (v4 ~/.local/state/omarchy/current/theme, else v3 ~/.config/omarchy/current/theme)"
>   "parse","colors.toml → background, foreground, accent, cursor, selection_*, color0…15"
>   "derive","muted (fg→bg 55%), dim (30%), surface (bg→fg 8%) — palette-agnostic blends"
>   "forge","~/.config/zed/themes/omarchy-blur.json — name 'Omarchy Blur', blurred appearance, editor/panel at 00 alpha, chrome at d0/d8/e0"
>   "point","settings.json 'theme' → 'Omarchy Blur' (stable name — the pointer never breaks across theme switches)"
> ```
>
> The theme name is **stable** (`Omarchy Blur`) so Zed's settings pointer never
> goes stale; only the colors change with the live omarchy theme. When the
> Allfather switches omarchy theme (e.g. Aetheria → Andlangr), the `theme-set`
> hook fires and the generator re-forges the blurred theme from the new palette
> automatically.
>
> **The blur recipe inside the generator** is the §4 recipe, parameterised:
> `background.appearance = "blurred"`, `editor.background`/`panel.background`/
> `toolbar`/`tab_bar` at `#<bg>00` (see-through), title/status/elevated at
> `#<bg>d0`/`d8`/`e0` (softly translucent), text and syntax opaque.
>
> **Verification after forging:**
>
> ```
> verify_adaptive[4]{check,command}:
>   "JSON parses","python3 -m json.tool ~/.config/zed/themes/omarchy-blur.json"
>   "palette is live","grep '\"background\"' the file — it matches the current theme's colors.toml background"
>   "settings pointer","grep '\"theme\"' ~/.config/zed/settings.json → \"Omarchy Blur\""
>   "hook fires","bash ~/.config/omarchy/hooks/theme-set.d/zed-blur '<theme>' — re-forges, still valid"
> ```
>
> **Scope again:** the generator writes only to `~/.config/zed/` — never to
> Hyprland, never to omarchy's own config. The errand's boundary holds.