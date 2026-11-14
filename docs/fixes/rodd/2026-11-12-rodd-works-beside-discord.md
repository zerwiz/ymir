# rodd · 2026-11-12 — Rödd answers, fast, beside Discord, with his mind, his to-do, his letters, the time and the fleet

## Files
- `apps/rodd/start.sh`: the head is the mind he chose in Rödd's settings (never nidavellir's forced alias); the engine
  line passes a forced head through `env` (an expansion cannot be an assignment prefix)
- `bin/voice/voice-door.sh`: per-machine settings from `~/.config/ymir/voice.env` (`YMIR_VOICE_GPU=on`,
  `YMIR_VOICE_PIPELINES`); a head the host's rail does not serve is never sent; `which-host`, the one resolver
- `bin/voice/voice_tools.py`: the to-do tools work on his one `todo.md`; `letter_types`, `letter_template`,
  `letter_draft` (a designed Gmail draft, never sent); `now`; `fleet`; the arm tools reach every machine; sessions
  kept in the home (`hodd/memory/rodd/sessions/`), read by `last_session`; the session log read locally when the host
  is this machine; her lines named Nanna
- `bin/voice/voice-toolbox.py`: `/head/models`, `/head/presets`, `/head/provider`, `/session`
- `apps/rodd/patch/patch-ui.py`, `house.css`: the Mind (provider and model dropdowns, add a provider with a key kept
  in the home), hold-to-talk as an optional switch, the real time in every session's brief, one sentence before every
  tool call, a working caption, sessions handed to the home, the subtitle on one row
- `apps/bilskirnir/server/src/models/detect.ts`, `choose.ts`: the presets from models.dev; a command line; the
  answer written synchronously (a pipe cut it at 64 KiB)
- `bin/model/providers-catalog.sh`, `bin/fleet/fleet-status.sh`, `bin/fleet/arm-send.sh`, `bin/voice/echo-cancel.sh` (new)

## Why
Plan 275, the 22:15 and later entries: Rödd never spoke (the engine asked heimdall's rail for nidavellir's alias and
exited), then spoke in 28 s (the voice on a starved CPU), heard the speakers, did not know his to-do, his letter
templates, the time or the fleet, and could reach only this machine's arm.

## Proof
On heimdall, through the window and the engine's log: first word in 0.2–0.5 s on the A5000; "Good evening … the
night's gone quiet" at 23:14; the fleet read aloud from five machines; the arm holders on heimdall and nidavellir named;
the to-do, letter, session and provider tools each run against a fenced copy of the home.

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: a dev machine. The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).

## CHANGE LOG

- 2026-11-14 — review-mend: added missing heading for #755
