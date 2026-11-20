# 2026-11-20 — a door to an agent in a terminal window

**Component:** agents · **Files:** `bin/agents/window-tell.sh`, `docs/features/tell-an-agent-in-a-terminal-window.md`,
one catalogue entry.

## Why

The operator asked the helm to update a Claude Code session he had started by hand in a terminal. `eindri-send.sh`
reaches only herdr panes, and the kernel's tty injection is off (`dev.tty.legacy_tiocsti = 0`) on purpose. The helm did
it by hand: walked the process tree to the terminal, focused the window, typed with `wtype`. His word: *"what you just
did must be a tool in ymir."*

## What changed

`window-tell.sh` lists terminal agents, resolves a target by pid, window or word, focuses it, types one stamped line and
returns focus. It refuses to type unless focus landed, refuses multi-line text, and hands long messages as a letter file.

## Found on the way

Hyprland's Lua config rejects the classic `hyprctl dispatch focuswindow address:…` with a Lua parse error; the form
that works is `hyprctl dispatch 'hl.dsp.focus({ window = "address:…" })'`. The door tries both.

## Proof

`--list` found the one hand-started Claude (pid, foot window, workspace 9). A dry run resolved it by pid and by a title
word; an unknown target refused with rc 2. The first real tell (the helm's letter to that session) was typed and the
session answered in its transcript.

## Correction (same day)

The first build carried its own Lua-or-classic focus. `bin/desktop/display-lib.sh` already owns the window manager's
dialect (`display_dialect`, `window_focus`), so `window-tell.sh` now sources it instead of keeping a second copy.

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #840
