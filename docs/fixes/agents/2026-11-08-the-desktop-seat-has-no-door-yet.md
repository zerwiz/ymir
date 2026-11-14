# agents · 2026-11-08 — the desktop seat: read what it shows, and say plainly that it cannot be posted into

## What

He asked the voice, by name and by description, to *"talk to Sessrúmnir, the app, the one of the four
apps"*. The voice had no hand for it at all and began to improvise — offering to "summon his presence",
then reaching for MCP servers that do not exist. Two faults, both small, both real:

- **`sessrumnir` (new, the voice's 36th hand)** — reads the app's own store
  (`~/.config/sessrumnir/workspaces.json`) and answers: is the app running, which workspaces it shows
  (with the active one marked), and how many Pi sessions the active workspace's shelf holds with the
  newest timestamp. Read-only, and it ends by naming the missing half out loud: **it cannot post into the
  app's conversations**, because Sessrúmnir speaks Electron IPC and publishes no door (plan 132 §43.4).
- **`errand_state` now says what it does not know.** The seats fix gave the voice a door onto the panes,
  but `errand_state` still answered with a bare list of recorded statuses — the same trap that made it
  say "no active agents" while six sat in panes. Both of its answers now say *RECORDED* and add
  "the panes hold more; call `seats` for what is actually working".

Both house briefs name the tool.

## Why

A voice that promises to "summon" an app it cannot reach, or that reads a recorded status file as if it
were the state of the machine, teaches the operator to distrust every other answer. The half that is
missing is said, once, in the answer itself.

## Verified

- `sessrumnir` through the toolbox (the window's own path): *"the app is running. workspaces (4): aigeeks&freeks
  … * ymir — ~/ymir … · 161 Pi session(s) in the active workspace's shelf, newest 11-08 14:04.
  I can read this; sending a line into one of the app's own sessions has no door yet."*
- `errand_state` with no arguments now opens *"Errands this seat has RECORDED (claimed state) — the panes
  hold more; call seats for what is actually working"*.
- the live page over Chrome DevTools MCP: `evaluate_script` → `36 tools | new: sessrumnir,seats,bash,mcp,
  cron_jobs,plans,research`; `list_console_messages` empty on a clean load.
- `apps/rodd/smoke.sh 45` after the rebuild: every stage PASS, `assistant audio arrived PASS 403968 bytes`.

## Not verified / owed

- **A door to post INTO Sessrúmnir** is still owed: an MCP or local HTTP face on the app (its own plan), or
  the voice steering a Pi session seated in a herdr pane — which works today and is the interim road.
- The session count is the shelf's file count, not "live conversations": a closed session is still a file.

## CHANGE LOG

- **2026-11-08** — written. The desktop seat's read-only hand, and the errand shelf taught to say what it
  cannot see.
