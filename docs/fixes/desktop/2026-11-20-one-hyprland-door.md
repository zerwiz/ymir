## desktop · 2026-11-20 — one Hyprland door (plan 341, phases 1–3)

### Why

On Hyprland 0.56 with an Omarchy Lua config, the classic dispatcher strings fail with a Lua parse error. Examples
are `focuswindow address:…`, `workspace 9` and `movetoworkspacesilent 9,…`. `hyprctl keyword` fails too, with
*"keyword can't work with non-legacy parsers. Use eval."*

Hyprland gives both answers with **exit 0**. A caller that wrote its own dispatch therefore landed nowhere, and
reported success.

`bin/desktop/display-lib.sh` already probed the dialect, but only two files used it. Measured before this change:

| Caller | What it did |
|---|---|
| `bin/desktop/sessrumnir-launch.sh` | hard-coded the Lua focus, so on a classic Hyprland it did nothing |
| `scripts/electron.sh` | hard-coded the same Lua focus, and called a refused focus `raised` |
| `bin/desktop/ymir-app` | tried the Lua form, then the classic one, by hand |
| `bin/desktop/desktop-place.sh` | `hyprctl reload … \|\| true`, so a broken `ymir-launchers.lua` was thrown away |
| `bin/desktop/editor-place.sh` | reloaded, then read `configerrors` without naming a file |
| `bin/host/host-sense.sh` | claimed placement works through `hyprctl keyword windowrule/dispatch` |
| boot-stopwatch, desktop-verify, omarchy-sense, security-audit, ymir-edit | each read `hyprctl … -j` raw |

### The fix

**`bin/desktop/hypr.sh` is the command-line face of `display-lib.sh`.** It is not a second library: the dialect
is still known in one file only. The verbs are `dialect`, `windows`, `find`, `active`, `focus`, `back`, `type`,
`workspace`, `workspaces`, `move`, `monitors`, `notify`, `config check`, `config reload` and `set`.

`display-lib.sh` gains the matching functions. It also gains `hypr_act`, which reads Hyprland's answer as well
as its exit code, so a refused act is a failure (exit 1) and never a silent green. The dialect probe now reads
the answer too, because a classic build may say "unknown request" with exit 0.

Two moves change behaviour:

- `window_to_desktop` is now silent in both dialects. Lua gets `workspace = "N", follow = false`. Classic gets
  `movetoworkspacesilent N,address:…` instead of a focus followed by a move.
- `desktop-place.sh apply` now ends red (exit 1) when the reload leaves config errors, and prints the broken file
  and line on stderr. `omarchy-install.sh` already reports a failed apply as a WARN.

Every caller listed above now goes through the door. `bin/gates/guards/hypr-door-guard.sh` is in the one ward
list (`bin/gates/guards.sh`). It refuses `hyprctl dispatch | eval | keyword | reload | setprop` in code anywhere
under `bin/` or `scripts/` except `display-lib.sh`.

### What `type` guards

`type` is the only verb that acts on what the operator is looking at, so it carries three guards:

1. It refuses (exit 3) while `bin/desk/in-call.sh holder` prints anything.
2. It types nothing unless Hyprland reports that focus landed on the target (exit 4 otherwise).
3. It gives focus back to the window that had it before.

The counsel in plan 341 also asks for two seconds without a keystroke first. That is **not built**, because it
waits on the Allfather's answer to plan 341 question 1.

### Proof

- `bin/desktop/tests/test_hypr_door.sh`: 79 cases, every verb in both dialects. They run against recorded
  `hyprctl -j` fixtures and a stand-in hyprctl that refuses the wrong dialect in the real words. No compositor
  is needed.
- `bin/gates/tests/test_hypr_door_guard.sh`: 8 cases. The real tree is clean, and a direct act is refused by
  file and line.
- `.agents/tests/ymir-edit-display.test.sh`: updated for the silent Lua move, and all cases pass.
- Live on the dev machine (Hyprland 0.56.2, Lua), read verbs only: `dialect` answered `lua`, `0.56.2`.
  `windows` listed three windows and named the `claude` agent inside a terminal. `find foot` refused and named
  both terminals. `config check` answered `clean`. `host-sense.sh` still answers `placement yes`.
- `grep -rn 'hyprctl dispatch' bin/` now finds only `display-lib.sh`.

### Not done here

Plan 341.4 to 341.6 (the watch, the Omarchy pass-through and the MCP face) are later phases. `window-tell.sh`
lives on another branch (`eindri/window-tell`) and already sources `display-lib.sh`.
