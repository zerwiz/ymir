# Rödd gets his four hands, and the boot stops crashing

**Date:** 2026-11-09 · **Plan:** 231 (§2 the six hands, §3 the crash) · **Component:** voice
**Law:** RULES/25 (name the borrow), RULES/07 (resolve, never hardcode), RULES/39 (a refusal is
spoken, never silent)

## What was wrong — measured, not guessed

Rödd's own log says `host up on 127.0.0.1:8890` and `toolbox {"ok": true, "tools": 37}`: the voice
was **not** toolless. What it lacked was the four handles plan 231 names — and the boot path was
crashing in a way that looked like a compositor fault.

Two faults, both read from the code and then reproduced:

1. **The hands.** `arm_who`, `eindri_list` and `eindri_send` did not exist in
   `bin/voice/voice_tools.py`; the calendar had no write hand at all. Rödd could hand the arm
   holder a message (`talk_to_arm`) but could not see whether anyone was holding it, list the
   workers, or send one of them a line.
2. **The crash.** `apps/rodd/src/main.js` started the UI server and, after a 30-second deadline,
   called `reject(new Error('ui server did not answer'))` into an unhandled promise. Electron
   answers an unhandled rejection with a crash — that is the SIGTRAP read in the core. The boot
   path was the crash, not the window system.

## What was built

**Four hands in the toolbox, each answering with its door's own words:**

```
tool[4]{hand,door,refusal}
  "arm_who","bin/voice/rodd-arm.sh who","exit 3 = nobody holds the arm, said plainly"
  "eindri_list","herdr agent list","no pane backend = said, never an empty list"
  "eindri_send","bin/agents/eindri-send.sh","the door's `sent`/`FAILED` is repeated verbatim; a FAILED is never spoken as sent"
  "calendar_write","bin/time/snotra/calendar-write.sh","the door's scope refusal is passed through unchanged"
```

**The boot path (`apps/rodd/src/main.js`):** the spawn keeps the last twenty stderr lines, a
missing interpreter is caught as an `error` event (the case that used to hang for the full
deadline), a failure prints **one** console line naming the interpreter and the directory, the door
pauses and retries **once**, and then a window shows the sentence — "The UI server did not start" —
with the log path and the last lines, and the process leaves with exit code 1. Additions:
`RODD_BOOT_TIMEOUT_MS` (default 20000) and `RODD_BOOT_RETRY_PAUSE_MS` (default 1500), plus
`unhandledRejection`/`uncaughtException` guards that name what happened before they stop.

## Verified

- `node apps/rodd/smoke/test-boot-path.mjs` — the real `main.js` loaded with a recorder in place of
  Electron and an interpreter that cannot start: **every proof held** (two attempts, one named line
  per attempt, the sentence in the window, no forced exit, exit code 1).
- Each new tool called through `voice_tools.execute_tool` on this seat: `arm_who` returned the
  holder's pid and generation from the lease; `eindri_list` returned 13 seated agents (2 working);
  `eindri_send` to a pane that does not exist returned **NOT DELIVERED** with the door's `FAILED`;
  `calendar_write status` returned `read-only` and the missing `calendar.events`.
- `apps/rodd/smoke/test-all-tools.py` carries the four new tools with safe arguments (the send is
  pointed at a pane that does not exist, the arm lease at a path that is not there) so the suite
  proves the refusals and never touches a real inbox.

## Not changed

The microphone is still opened only for the voice pipeline this app does not start, and the app
still refuses to host a voice it did not raise. `apps/rodd/start.sh` is untouched.

## CHANGE LOG

- **2026-11-09** — The four hands, and the boot path that used to end in a core file (plan 231
  R1/R3). Written with `docs/features/rodd-the-voice.md`'s dated section.
