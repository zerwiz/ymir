# Bilskirnir: the mic raises the voice, each agent has a settings button, and the face is never stale

**Status:** built and tested in Bilskirnir's window on heimdall, 2026-11-13 (plan 275), at the Allfather's word.

## What changed

| Seen | Fix | Proven |
|---|---|---|
| Pressing the mic said "The house voice is not raised (run bin/voice/voice-door.sh host)" after a reboot | The mic press raises Rödd's engine through `voice-door.sh host` (detached, no `--now`, so the door still refuses during a call) and waits up to 90 s | A voice session from the window: the engine rose on the GPU and the call was granted after 44 s |
| No way to delete an agent from the list | A settings button on each agent row: Settings, and Delete agent… with a second "for good" step; the first agent in the hall opens its settings instead | The menu, the confirm step and "Keep it" driven in the window |
| The menu could go off the screen | It opens above the row when there is less than 150 px below, and never wider than the window | At a 351 px viewport the bottom row's menu opened above, fully visible |
| "Conversation memory NaN% full" in a fresh room | No limit measured yet is said as "not measured yet" | Read from Nanna's settings |
| The window showed an old face after a rebuild | `index.html` is served with `Cache-Control: no-cache` | The header, and the new face after a restart |

Still owed: while the engine loads (about 40 s), the window should say "the voice is starting" instead of waiting quietly.
