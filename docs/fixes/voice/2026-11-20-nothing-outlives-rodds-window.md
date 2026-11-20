# Nothing Rödd raises outlives her window

**Date:** 2026-11-20 · **Component:** voice · **Plan:** 326.8 · **Repos:** Ymir (`bin/voice/voice-door.sh`) and Rödd (`start.sh`)

## What was wrong

Rödd's unit is a oneshot that stays "active" after its start script returns. Nothing noticed when the window closed.
Measured on 2026-11-19: the toolbox (`voice-toolbox.py`, port 8891) was still running 5 h 51 min after the window
had gone. The head proxy (port 8893) outlived the engine it served. The engine waited for its five-minute idle stop.

## What changed

Every process Rödd raises has an owner that closes it:

| Process | Raised by | Closed by |
|---|---|---|
| the window (Electron) and its UI server | Rödd's `start.sh` | the person (the window's own close) |
| the toolbox (8891), the tunnel | Rödd's `start.sh` | `start.sh --stop`, run when the unit stops |
| the unit itself | the launcher | **new:** a warden that watches the window's main process and stops the unit when it ends, for its own invocation only |
| the voice engine (8890) | `voice-door.sh host` | **new:** `start.sh --stop` lowers it on this machine; still also its idle watcher |
| the head proxy (8893) | `voice-door.sh host` | **new:** `PartOf` the engine |
| the idle watcher | `voice-door.sh host` | **new:** `BindsTo` the engine |

## Proof

Rödd raised from the branch under a test unit, a live session held, then only the window closed. Twice:

| | During the session | After the window closed |
|---|---|---|
| ports 8890 · 8891 · 8893 · 9416 | all listening | all free (in 7 s and in under 10 s) |
| microphone streams | 1 (`ymir-rodd`, electron) | 0 |
| the engine on the GPU | 2,762–3,036 MiB | gone; only voxtype and the model rail remain, neither Rödd's |
| units: Rödd · engine · proxy · watcher | active | inactive |

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #840
