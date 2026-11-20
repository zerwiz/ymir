# The Hyprland door

## What it is

`bin/desktop/hypr.sh` is one command for everything the house does with Hyprland: listing windows, finding one,
focusing it, typing into it, switching desktops, moving windows, checking the config and changing an option.

It knows which dialect your Hyprland speaks. Hyprland 0.56 with an Omarchy config takes Lua (`hl.dsp.…`,
`eval`), and older versions take the classic strings. You type the same verb on both. The dialect is
probed when you run the command, never guessed from a version number.

## What you need

- A Hyprland session. Anywhere else every verb except `dialect` refuses by name and exits 3. Another desktop
  brings its own layer.
- `python3`, and `luac` for the syntax half of `config check` (it is skipped, and says so, without it).
- `wtype`, only for `type`.

## The commands

These verbs only read, and change nothing:

| Command | What it answers |
|---|---|
| `bin/desktop/hypr.sh dialect` | `lua`, `classic` or `none`, and the version |
| `bin/desktop/hypr.sh windows [--json]` | every window: address, class, desktop, monitor, pid, the agent inside it, title |
| `bin/desktop/hypr.sh find <query>` | one window address. The query can be a class, a title, a pid or an address |
| `bin/desktop/hypr.sh active` | the focused window's address |
| `bin/desktop/hypr.sh workspaces` · `workspace-active` · `workspace-free` | the desktops, the current one, the lowest empty one |
| `bin/desktop/hypr.sh monitors` · `monitor reading` | the screens, and which screen a role names |
| `bin/desktop/hypr.sh config check` | Hyprland's config errors, plus a syntax check of the house's `ymir-*.lua` files |

`find` never picks silently. If two windows match, it exits 4 and lists both. Add `--class`, `--title` or
`--pid` to say which kind of query you mean, or `--first` to take the first match.

These verbs act:

| Command | What it does |
|---|---|
| `bin/desktop/hypr.sh focus <query>` | focuses the window and remembers what had focus |
| `bin/desktop/hypr.sh back` | gives focus back to the window that had it |
| `bin/desktop/hypr.sh type <query> "<line>"` | focuses, checks focus landed, types the line, presses Enter, then gives focus back |
| `bin/desktop/hypr.sh workspace 3` | switches to desktop 3 |
| `bin/desktop/hypr.sh move <query> --workspace 5` | moves the window to desktop 5 without following it |
| `bin/desktop/hypr.sh move <query> --monitor reading` | moves the window to the screen a role names |
| `bin/desktop/hypr.sh notify "<text>"` | shows a notice on screen |
| `bin/desktop/hypr.sh config reload` | reloads Hyprland, then names the broken file and line if there is one |
| `bin/desktop/hypr.sh set general:gaps_in 5` | changes a runtime option: `eval hl.config(…)` on Lua, `keyword` on classic |

> [!IMPORTANT]
> `type` acts on what you are looking at, so it is guarded. It refuses while `bin/desk/in-call.sh holder` names
> a call. It types nothing unless focus truly landed on the window. It gives focus back afterwards. Add
> `--no-enter` to skip Enter, or `--stay` to keep focus on the target.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | done |
| 1 | a fault: Hyprland refused the act, or the config has errors |
| 2 | usage |
| 3 | refused: no Hyprland here, or the desk is in a call |
| 4 | no such window, several windows, or focus did not land |

## Limits

- `set` changes your live session. Whether the house may use it outside its own windows is still an open
  question in plan 341.
- `type` does not yet wait for two seconds without a keystroke before typing.
- The watch on config errors, the Omarchy pass-through and the MCP tools are later phases of plan 341.

## For people writing scripts

Do not call `hyprctl dispatch`, `eval`, `keyword` or `reload` yourself. Call this door, or source
`bin/desktop/display-lib.sh`. `bin/gates/guards/hypr-door-guard.sh` refuses a direct act anywhere else under
`bin/` or `scripts/`.

## If it does not work

- Every verb says `no Hyprland answers here`: `hyprctl monitors -j` cannot reach a running Hyprland from this
  shell. Check that `HYPRLAND_INSTANCE_SIGNATURE` is set.
- `type` says `focus did not land`: another window took focus, or the target is on a special desktop. Nothing
  was typed.
- `config reload` exits 1: read the file and line it names, fix that line, then reload again.
