# The head proxy and the idle watcher end with the voice engine

**Date:** 2026-11-20 · **Component:** voice · **Plan:** 326.8

## What was wrong

The voice door raises three units: the engine (`ymir-voice-host`), the idle watcher that lowers it, and the head
proxy in front of an online mind. Only the engine had an owner that closed it. The proxy was found still running
hours after the engine it served had stopped.

## What changed

- `rodd-head-proxy.service` is raised with `PartOf=ymir-voice-host.service`, so every stop of the engine stops it:
  the idle stop, `host --stop`, and Rödd's window closing. The proxy is raised before the engine. A probe proved
  that `PartOf` still binds when the owner is created later.
- `ymir-voice-idle.service` is raised with `BindsTo=` and `After=` the engine, so it ends whenever the engine does,
  a crash included.
- `voice-door.sh host --stop` also stops a proxy raised before this change.

## Proof

Two throwaway units, the helper raised first with `PartOf` the other: both active, then both inactive one second
after only the owner was stopped.

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #840
