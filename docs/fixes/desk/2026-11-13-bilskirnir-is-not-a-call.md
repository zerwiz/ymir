# The call guard no longer mistakes Bilskirnir's own microphone for a call

**Status:** fixed on heimdall, 2026-11-13 (plan 275), at the Allfather's word: *"nanna's streaming voice ain't
starting for me."*

Pressing the mic in Bilskirnir opens the window's microphone and asks the voice door to raise Rödd's engine. The
door's call guard (`bin/desk/in-call.sh`) saw a client named "Bilskirnir" holding the microphone and refused: *"refused:
Bilskirnir holds the microphone — the operator is in a call, so the voice engine will not start"*. The guard already
ignores the house's own voice clients (the engine and Rödd's window); Bilskirnir was never added. It is now, in the
default `YMIR_DESK_IGNORE`. A real call (Discord, Meet, a browser) still stops the engine from starting.

## CHANGE LOG

- 2026-11-13 — review-mend: added missing heading for #730
