## hlidskjalf · unversioned · 2026-10-07 — one button for the live tail, and a stop that never hangs the browser

### Why
`bin/time/snotra/snotra-live.sh` was forged and proven, but only on the command line:
the Allfather had to remember the script, its arguments and its two doors. He asked
for exactly one thing — *"add this to the ui in hlidskjalf so i can start and stop it
simple"* — and the acceptance test was simple, so the surface is one chip beside the
halls switcher: click, name it, listen; click again, close the book.

The design is decided by one fact about the script: **`stop` is slow**. It joins every
slice into one WAV, re-transcribes the recording, asks the rail for a summary, writes
the minutes and carves a Rune — minutes on a one-hour meeting. A UI that POSTs that
and waits is a spinner the Allfather cannot trust, and a browser that gives up on it
looks broken while the work is in fact fine. So `POST /api/snotra/live/stop` spawns the
script DETACHED and answers `{closing:true}` at once, and the surface keeps polling
`GET /api/snotra/live` until it reports itself stopped.

The gate is a FRONT for the script, not a second pipeline. It calls the script and
reports what the script says:

- `GET /api/snotra/live` runs `snotra-live.sh status`, parses its one TOON row
  (`live_tail{state:…,doc:…}`) and returns that row plus the newest `[hh:mm:ss]`
  lines of the document the script named. No transcription, no slice timing, no engine
  discovery is re-implemented anywhere in `apps/hlidskjalf/`.
- `POST /api/snotra/live/start` is bounded (`timeout 20`) and returns the script's
  refusal VERBATIM on a non-zero exit — including "ONE ear at a time", which names the
  ear that is busy instead of the surface inventing a generic error.
- `POST /api/snotra/live/stop` is detached; a `liveClosing` latch in the gate is what
  makes `closing` outrank the script's own `stopped`, because the script silences
  ffmpeg in its first seconds and `status` alone would report stopped while the
  minutes are still being written. The latch also refuses a second `start` while a
  drain is in flight — a race the script's own probe cannot see, since the drain is
  the gate's detached child.

Transcript CONTENT stays private: the document lives in
`$YMIR_HOME/hodd/life/meetings/` and only these three authenticated routes read it,
for the operator. No transcript text was written into the repo, a fixture, a log or
this note.

### Files
- `apps/hlidskjalf/src/services/api.ts` — `LiveTailStatus` / `LiveTailStartResponse` /
  `LiveTailStopResponse` and the three calls (`liveStatus` / `liveStart` / `liveStop`)
- `apps/hlidskjalf/src/components/SnotraLive.tsx` — the one control and the readout
- `apps/hlidskjalf/src/app/Topbar.tsx` — the control, beside the halls switcher
- `apps/hlidskjalf/src/styles/shell.css` — `.snotra-live*` (tokens only)
- `apps/hlidskjalf/server/index.ts` — the three routes, `parseLiveRow`, `liveStatus`,
  `liveLines`, the `liveClosing` latch
- `.agents/skills/galdr-ymirsystem/assets/hlidskjalf-ui.md` — the new section

### Verified on this seat
`npm run typecheck` and `npm run build` green. The gate was run from this worktree on
`:3899` against the REAL script: start returned the script's own "The live tail
opens…", the document grew to 13 stamped lines read back through
`GET /api/snotra/live`, a second `start` was refused with the script's own sentence
(HTTP 409), and `stop` answered `{closing:true}` immediately while the polls reported
`closing` until the drain finished. No new gate was added — a topbar control plus a
panel is the surface the ask needed.