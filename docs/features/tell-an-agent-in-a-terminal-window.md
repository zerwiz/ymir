# Tell an agent in a terminal window

## What it is

Some agents are not seated in herdr. You start Claude Code, Codex or another agent by hand in a terminal window, and it
works there. `bin/agents/eindri-send.sh` cannot reach it, because it has no pane. `bin/agents/window-tell.sh` can.

It does what you would do: it finds the window that owns the agent's process, focuses it, types one line, presses Enter
and puts your focus back where it was.

## What you need

- A Wayland session on Hyprland (`hyprctl`).
- `wtype` (`pacman -S wtype`).

Anywhere else the door refuses by name and types nothing.

## The commands

```bash
bin/agents/window-tell.sh --list                                   # who can be reached
bin/agents/window-tell.sh --from "the helm" 22821 "Pull main before you push."
bin/agents/window-tell.sh --dry-run launchers "test"               # say what it would do
bin/agents/window-tell.sh --from "the helm" --letter ~/letter.md 22821 < message.md
```

A target is the agent's pid, the terminal's pid, a window address (`0x…`), or a word found in the window title or the
agent's working directory. If a word matches two windows, the door refuses and asks for a pid.

## Long messages go in a letter

A typed line is one line. For anything longer, `--letter <file>` writes the message from stdin to that file and types
only the pointer: *"Please read <file> and answer by appending to it."* The agent answers in the same file.

## Limits

- It takes your focus for about a second. If you are typing in that moment, your keys may land in the other window.
- It types only when the focused window is the target after focusing; otherwise it types nothing and says so.
- A tell is handed, not done. Read the agent's answer before you count it.

## If it does not work

- `no agent stands in any terminal window` — the agent runs in herdr; use `eindri-send.sh`.
- `focus did not land` — the window is on a locked or special workspace; open it yourself and try again.
- Hyprland with a Lua config takes `hl.dsp.focus({ window = "address:…" })`; the door tries that first and falls back to
  the classic `focuswindow`.

## CHANGE LOG

- 2026-11-20 — first written.
