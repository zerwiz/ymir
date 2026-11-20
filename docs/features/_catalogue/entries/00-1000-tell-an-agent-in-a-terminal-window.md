---
section: core-install-run-operate
---
| Operate | **Tell an agent in a terminal window** (`bin/agents/window-tell.sh`) | The door for an agent the operator started by hand in a plain terminal (foot, kitty, alacritty, ghostty …), where `eindri-send.sh` cannot reach because there is no herdr pane. `--list` names every terminal agent it can find (agent pid, terminal, window, workspace, title, working directory); a target is a pid, a window address or a word from the title or directory. It focuses that window through Hyprland, types one stamped line (`[from <who>] …`) with `wtype`, presses Enter and gives focus back — and types **nothing** if focus did not land. A long message is never typed: `--letter <file>` writes it from stdin and types only the pointer. Wayland + Hyprland + wtype, or a named skip | [Tell an agent in a terminal window](docs/features/tell-an-agent-in-a-terminal-window.md) |

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #840
