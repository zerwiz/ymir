# Opening a file on the right display

> **Status: built and tested (2026-10-18).** `bin/seat/sessrumnir/open-on.sh` +
> `bin/seat/sessrumnir/display-lib.sh`, with `.agents/tests/open-on.test.sh`.

## What it is

When Ymir opens a document for you — a plan, a note, a file you asked to see — it should
know **which screen it belongs on**, not drop it wherever the mouse happens to be.

`open-on.sh` does three things and nothing else:

1. **One window per file.** If the file is already open, it focuses that window instead of
   opening a second one. `--new` forces another.
2. **The display is chosen by ROLE**, not by a port name buried in a script.
3. **It knows the window manager's dialect.** Hyprland 0.55 and earlier take classic
   dispatchers (`movewindow mon:HDMI-A-1`); Hyprland 0.56 with an Omarchy Lua config takes
   **Lua dispatchers** (`hl.dsp.window.move({ … })`) and rejects the classic strings with a
   syntax error that looks like a broken desktop. The dialect is *probed*, never guessed
   from a version string.

## What you need

- A Hyprland session (Omarchy). **Anywhere else it still works** — the file opens and it
  tells you placement was skipped.
- A GUI editor it can resolve: `$YMIR_EDITOR`, or one line in `~/.config/ymir/editor`,
  else the first of `marktext`, `zed`, `code`, `cursor`, `obsidian` that is installed.

## The commands

```sh
bin/seat/sessrumnir/open-on.sh <file> [--role reading|code|primary|<MONITOR>]
                                      [--editor marktext] [--new] [--fullscreen]
                                      [--dry-run] [--wait <seconds>]
```

| piece | meaning |
|---|---|
| `--role reading` | **the largest monitor** — where a document is read. The default. |
| `--role code` | the focused monitor — where the work already is |
| `--role HDMI-A-1` | a monitor named directly, passed through untouched |
| `--dry-run` | print the plan — file, editor, role, monitor, dialect — and change nothing |
| `--fullscreen` | fill that monitor |

**Recording your own screens** (optional; the defaults above apply without it):

```sh
mkdir -p ~/.config/ymir
printf 'reading = HDMI-A-1\ncode = eDP-1\n' > ~/.config/ymir/displays.conf
```

**Also wired into the harness:** `/edit` (and `ctrl+shift+e`) open GUI editors **through
this opener** when it is found, so a file you ask for lands on the right display.

## Limits, stated plainly

- It moves the window **it** opened (or re-focused). It never edits your Hyprland config,
  and it never moves a window you placed yourself.
- One file at a time; one editor per call.
- Roles are *your* words: `reading` means the largest screen unless you say otherwise.
- On a non-Hyprland desktop the placement is a clean skip (exit 3), not a failure — the
  file still opens.
- Exit codes: `0` opened and placed · `1` the file or the editor failed · `2` usage ·
  `3` opened but unplaced (no window manager).

## If it does not work

| symptom | cause | do |
|---|---|---|
| `error: no editor found` | nothing resolvable | `export YMIR_EDITOR=marktext`, or write one line in `~/.config/ymir/editor` |
| the window never appears | the editor is not installed, or it opens slowly | `--wait 40`, or launch the editor yourself once and re-run |
| `placement skipped` | no window manager answered | you are not in a Hyprland session (or `$YMIR_HYPRCTL` is wrong) |
| it opened twice | the editor does not put the file name in its window title | report it: reuse matches on class + file name |
| the wrong screen | the role resolved elsewhere | name the monitor directly, or record `~/.config/ymir/displays.conf` |
