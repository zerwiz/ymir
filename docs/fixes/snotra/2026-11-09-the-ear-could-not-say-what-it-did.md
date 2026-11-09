# The ear could not say what it did — and it could not do it either

**Date:** 2026-11-09 · **Component:** snotra · **Doors:** `bin/records/snotra-what.sh` (new),
`systems/snotra/services/ear/snotra-capture.sh`, `systems/snotra/services/ear/snotra-detect.sh`

Plan 228 §2 (F1), from plan 112's own lesson: *a silent failure is indistinguishable from working*.

## What the Allfather saw

*"i dont get any notifications of this at all now"*, and the same day: the ear took the
microphone for three days and said nothing. Measured on this seat before the mend:

```
measured[4]{command,answer,what_it_means}:
  "bin/records/meetings.sh totals","3 meetings · 2 transcripts · 0 minutes · 0 promises","the pipeline stopped after the transcript"
  "snotra-capture.sh status","snotra: the door moved … and is not there (127)","the capture door was dead"
  "snotra-detect.sh status","in-call/idle from the state file, no sentence about the rule","the ear had no voice"
  "the hotline","nothing from systems/snotra/ ever arrived","the two calls that were wired sat in a door with no ROOT"
```

## The faults, in the order they hid each other

**1 · The capture door was dead.** `systems/snotra/services/ear/snotra-capture.sh` carried the
*retired shim's* path guard at the top of the real door. From `systems/snotra/services/ear`,
`$_d/../../..` is `<repo>/systems` — not the repo root — so `_new` could never exist and every
invocation printed *"the door moved … and is not there"* and exited **127**. `start`, `stop`,
`status`, `devices`: all dead, and `~/.fleet/snotra-capture.sh` had the same text, so the live
watch called a door that always refused. The watch was alive; the ear was not. The guard is gone.

**2 · The two hotline calls that existed could not fire.** `say_hotline()` used `$ROOT`, which
the file never set, so `[ -x "$door" ]` was `[ -x /bin/notify/send.sh ]` and returned quietly.
`ROOT` is now found by walking up to the tree that carries `RULES/` and `.agents/`, and in a
flat `~/.fleet` install the hotline is a clean skip rather than a wrong path (RULES/25).

**3 · The ear had no status door.** There were state files and no sentence. `bin/records/snotra-what.sh`
is that sentence: `now` (armed/idle · the rule that decided · since · until) · `last` (the last
capture, how long, who, where the minutes are, and **FINISHED or STOPPED AT** a step) · `plan`
(the four rungs and the blocked one) · `week` (counts) · `off|on` (his hand, with the reason
written into `$YMIR_HOME/state/.snotra-off`). It reads the state files the ear already writes and
keeps no record of its own.

**4 · A silent ear now says it is silent.** A watch that is active with nothing captured in 24
hours prints `no call seen in 24h` — in `now` and in the 07:00 brief.

**5 · The microphone law was stated as a mode instead of a device.** The arm refused unless
`SNOTRA_LOCAL_ROOM=1`, which is why the seat's own drop-in (`SNOTRA_MIC=` empty,
`SNOTRA_MONITOR=<sink monitor>`) could never take effect: the watch also *overrode* the
operator's `SNOTRA_MIC` with the detected microphone. Now the law is about the **device** — if
no microphone is resolved, the internal stream is captured and no device is opened; if a
microphone is resolved, it needs `SNOTRA_LOCAL_ROOM=1`; and the operator's env wins over the
snapshot (`${VAR-default}`, which keeps an empty value as a value).

## What changed

- [x] `systems/snotra/services/ear/snotra-capture.sh` — the dead shim guard removed; `ROOT`
      resolved; the hotline fires for capture start and stop; the device law replaces the mode
      law; `.snotra-mode` records *what* is being listened to (internal stream / whole room);
      `status` says it (`idle`, `last mode`).
- [x] `systems/snotra/services/ear/snotra-detect.sh` — the hotline on **arm** and on **leave**
      (and on a leave that recorded nothing, and on a leave below the meeting floor); the
      device law; the operator's `SNOTRA_MIC`/`SNOTRA_MONITOR` no longer overridden.
- [x] `bin/records/snotra-what.sh` — new door, five verbs, `--self-test` against a fixture state.
- [x] `bin/time/nornir-job-daily-briefing.sh` — the ear's own line, and the meetings line, in
      the brief.
- [x] `tests/test_snotra_ladder.sh` — proves the ear's voice and the ladder together (24 checks).
- [x] this note.

## The seven transitions, and where each one lives

```
transitions[7]{event,door,severity}:
  "armed","snotra-detect.sh do_arm","INFO"
  "left","snotra-detect.sh do_leave","INFO/MEDIUM (nothing recorded is MEDIUM)"
  "capture started","snotra-capture.sh do_start","INFO"
  "capture stopped","snotra-capture.sh do_stop","HIGH"
  "transcript ready","snotra-ladder.sh step_transcript","MEDIUM"
  "minutes filed","snotra-ladder.sh step_minutes","HIGH"
  "a step FAILED","snotra-ladder.sh run_one","HIGH — with `stopped at <step>: <reason>`"
```

## What did not change

- **The microphone is never opened to hear a call** (his law). The bot still joins the room; a
  microphone still needs to be asked for by name.
- The arm/leave gates, the probes, the silence floor, the transcription engine and the summarizer
  path are the same code.
- The seven transitions are keyed and deduped by the hotline's own `--key`, so a flap cannot
  repeat one into his phone.

## Measured after

```
after[4]{command,answer}:
  "snotra-capture.sh status","Snotra capture: idle · last mode: never captured here"
  "bin/records/snotra-what.sh now","armed — watching · the rule that decided: no call — no stream carries a call role … · no call seen in 24h"
  "bin/records/snotra-what.sh --self-test","22 checks, OK"
  "bash tests/test_snotra_ladder.sh","24 passed, 0 failed"
```

The unit was not edited: `off`/`on` write state, and the watch reads it.

## CHANGE LOG

- **2026-11-09** — Opened: what was measured before, the faults in the order they hid each other, what changed, and what was deliberately left for another hand.
