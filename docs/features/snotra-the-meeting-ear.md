# Snotra — the meeting ear

## What it is

**Snotra** is Ymir's meeting ear. It **captures** a call, **transcribes** it locally, **composes the
minutes** from the transcript with the house model, and turns **every promise into a todo**. It also has
**one door that says what it is doing** — armed or idle, why, since when, and whether the last meeting's
pipeline finished or stopped at a step.

## What you need

- A seat with a **microphone** for a **local room** (a call seat); a headless heart reports a clean skip.
  An **online** meeting is never heard by this microphone — the bot joins the room instead.
- The engine: `systems/snotra/services/ear/snotra-ensure.sh` discovers it and installs what is missing
  (whisper.cpp + one model); Arch: `pacman -S whisper-cpp`.
- A **model on the rail** to compose the minutes: the seat's `SNOTRA_RAIL_MODEL` (the unit drop-in names it),
  or `RAIL_MODEL`, or the rail resolver's first listed model. Without one the ladder **stops at `minutes` and
  says so** — it never writes a template and calls it minutes.

## Do it

Ask the ear what it is doing — this is the door to use first:

```bash
bin/records/snotra-what.sh now      # armed/idle · the rule that decided · since · until · no call seen in 24h
bin/records/snotra-what.sh last     # last capture: when · how long · who spoke · the minutes · FINISHED or STOPPED AT
bin/records/snotra-what.sh plan     # the ladder's steps and the one it is blocked at
bin/records/snotra-what.sh week     # calls · transcripts · minutes · promises · todos · stops
bin/records/snotra-what.sh off --reason "a room that must not be recorded"
bin/records/snotra-what.sh on
```

The watch itself:

```bash
bin/time/snotra/snotra-capture.sh status                       # is the ear listening right now?
systems/snotra/services/ear/snotra-ensure.sh status            # engine + model present?
systems/snotra/services/ear/snotra-ensure.sh ensure --install  # install what is missing
```

The meetings it produced:

```bash
bin/records/meetings.sh list         # one row per meeting: transcript? minutes? promises? plans?
bin/records/meetings.sh totals       # the four numbers the brief carries
bin/records/meetings.sh brief        # the ONE line the 07:00 brief prints
bin/records/meetings.sh show <id>    # the folder, the files, the state, in words
bin/records/meetings.sh plans <id>   # the plans a meeting produced (by `from_meeting:` in a plan header)
```

Finish a meeting the pipeline left half-done (idempotent — a finished rung is never redone):

```bash
systems/snotra/services/record/snotra-ladder.sh run <id>
```

A plan a meeting produced says so in its header, and the reverse query finds it:

```bash
bin/records/plan.sh new the-palette --title "The palette decision" --from-meeting <meeting-id>
bin/records/meetings.sh plans <meeting-id>
```

## The seven things the ear says out loud

Each one reaches the hotline (`bin/notify/send.sh --source snotra`): **arm** · **leave** ·
**capture start** · **capture stop** · **transcript ready** · **minutes filed** · **a step that FAILED**
(HIGH — on his phone). A step that fails also writes `stopped at <step>: <reason>` into the meeting's own
`.state`, so the record itself never looks finished.

## Notes and limits

- **Local and private.** Transcription is whisper.cpp on the seat — audio does not go to a cloud by default.
- **The microphone is never opened to hear an online meeting.** `start` refuses unless
  `SNOTRA_LOCAL_ROOM=1`: the room door is for people physically there. An online meeting is heard by the bot
  (`bin/time/snotra/snotra-bot.sh join <url>`).
- **A promise becomes a todo in the same act as the minutes**, keyed on the meeting and the promise, so
  re-running the ladder never files the same promise twice.
- **The minutes are only as good as the transcript.** The model is told to quote what was said and never to
  promote a discussion into a decision; a meeting with no decision in it says `- none stated`.
- **The index is derived.** Delete `bin/records/meetings.sh` and nothing is lost — the folders are the record.
- **Audio retention** is plan 30's rule (`audio-retention.sh`): compressed, offloaded by month.

## If it does not work

| What you see | What to do |
|---|---|
| `status` shows the engine missing | `snotra-ensure.sh ensure --install` (per‑OS road printed). |
| The watch never fires | The seat has no mic — expected on a headless seat; check the `fleet` step's capability raise. |
| `now` says `no call seen in 24h` | The watch is up and nothing has been captured — check that the meeting app carries a call role (`snotra-iscall.sh --why`). |
| `now` says `off by his hand` | `bin/records/snotra-what.sh on` clears it; the reason it was off is printed with it. |
| `last` says `STOPPED AT minutes: the model did not answer` | The rail is down or the model id is not served: check `bin/model/rail-resolve.sh status` and the unit's `SNOTRA_RAIL_MODEL`. |
| `last` says `STOPPED AT transcribe: …` | No transcript reached the folder — check the ear's log (`$YMIR_HOME/state/.snotra-detect.log`) and that whisper has a model. |
| No plan appears under `plans <id>` | The plan header carries no `from_meeting:` line (or names a different id) — the reverse query refuses to guess. |
