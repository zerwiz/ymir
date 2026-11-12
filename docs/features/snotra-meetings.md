# Snotra — one meeting record, from any seat

**What it is.** Four small doors that make a meeting capture into a record, wherever it
was heard: the local ear, a bot in a Meet/Zoom/Teams call, or a Þing room raised on the
computer you are on. They all write the same directory, so the record does not care which
one heard the room.

## What you need

- `$YMIR_HOME` (the hoard) — the record lives there, never in the repo.
- For the bot: a Vexa endpoint (`VEXA_API_URL`, HTTPS) and a key in the vault.
- For Þing: a MiroTalk checkout (`PING_MIROTALK_DIR`), an image (`PING_IMAGE`), or
  `PING_CMD` for a test room.
- For auto-join: the calendar cache that Mánagandr writes.

## The four doors

```sh
# 1. the store — one contract for every meeting
systems/snotra/services/record/snotra-store.sh new work "roadmap" --title "Road map" \
  --source ping --platform ping --classification confidential
systems/snotra/services/record/snotra-store.sh put <id> transcript.md --as transcript
systems/snotra/services/record/snotra-store.sh index
systems/snotra/services/record/snotra-store.sh verify --all

# 2. Þing on demand — raise a room where you are, then lower it
bin/thing/ping-room.sh start --mode tailnet
bin/thing/ping-room.sh url
bin/thing/ping-room.sh stop

# 3. calendar auto-join — plan first, run later
systems/snotra/services/ear/snotra-autojoin.sh scan
systems/snotra/services/ear/snotra-autojoin.sh run            # dry run
systems/snotra/services/ear/snotra-autojoin.sh run --apply    # sends the bot

# 4. the bot — Snotra joins a call through Vexa
systems/snotra/services/ear/snotra-bot.sh join https://meet.google.com/abc-defg-hij
systems/snotra/services/ear/snotra-bot.sh status <id>
```

## The record

```
$YMIR_HOME/hodd/life/meetings/<work|personal>/<YYYYMMDD-HHMM>-<slug>/
  meeting.json  transcript.md  minutes.md  decisions.md  actions.md  cards.json
  audio/  .owner  .state  .transcribe.lock  .corrections.md
```

`meeting.json.workspace` must equal the lane directory, or the write fails. Audio is
never committed; the store refuses it when git does not ignore it. A record is
append-only: `put` refuses to overwrite; a correction is `--as corrections`.

## Limits

- The bot needs a Vexa endpoint; this door does not run the engine.
- Þing in P2P mode records in a participant's browser, not on the server.
- Auto-join is dry-run unless `--apply`; the personal lane is off by default.
- The store is a filesystem contract, not a database. Syncthing/git move it.

## If it does not work

| Symptom | Cause | Fix |
|---|---|---|
| `workspace != lane` | the JSON and the directory disagree | move the directory or fix the field; never guess |
| `refusing to overwrite` | the record is append-only | use `--as corrections` |
| `audio is not git-ignored` | the home's `.gitignore` lacks the rule | add `hodd/life/meetings/**/audio/` |
| `VEXA_API_URL is not set` | no bot endpoint | set it in the vault; HTTPS only |
| `no MiroTalk` | no checkout, image or command | set `PING_MIROTALK_DIR` or `PING_IMAGE` |
| `no video link` | the event has no conference URL | the calendar reader must expose it |

Tests: `bash tests/run.sh` (61 assertions across four suites).

## Letting the assistant speak in the room

**What it is.** `systems/snotra/services/ear/snotra-stream.sh` is Ymir's voice in a meeting that runs
**on this computer**. `say` speaks one line; `talk` runs the **streaming loop** — it hears
in ~2-second chunks, answers **only when it is named**, composes one short answer, and
speaks it sentence by sentence (the next sentence is rendered while the current one plays).
Kokoro makes the voice; the `snotra_mic` PipeWire source carries it; a meeting client that
selects *Snotra Mic* as its microphone transmits it.

**What you need.** `kokoro-serve.service` (the door raises it), a whisper server on
`:10300` (`whisper-server` — the loop transcribes with it), the virtual microphone
(`snotra-voice-device.sh ensure`, done automatically), and a call **on this seat** — a
remote call heard only by the Vexa bot has no local uplink to borrow.

```bash
systems/snotra/services/ear/snotra-voice-device.sh ensure          # the sink + the source, idempotent
systems/snotra/services/ear/snotra-stream.sh status                # muted? device? is Kokoro up?
systems/snotra/services/ear/snotra-stream.sh say "Craig, the actions are in the mail."
systems/snotra/services/ear/snotra-stream.sh talk --listen <source>   # the streaming loop
python3 systems/snotra/services/ear/snotra-talk.py --listen-file q.wav  # replay a recording (the test door)
systems/snotra/services/ear/snotra-stream.sh mute                  # one command, and it holds
```

**The speech law the door enforces.** The first word in a meeting is the speaker's own
name (`Skírnir, the Allfather's assistant, speaking.`) — an assistant mistaken for the
operator is worse than a silent one. It answers **only when addressed**, matched loosely
enough to survive speech recognition (whisper hears *"Skírnir"* as *"Scurnier"*). An answer
over 20 seconds is cut, not stretched. No URL, plan number or port is ever spoken. Every
utterance is one measured line in `talk.log` and one Rune.

**Limits.** The loop's turn is a **note passed, not a conversation**: a 2-second chunk plus
model time means it answers a question asked several seconds earlier — so it speaks only
when named. A cold rail model costs ~20 s for the first answer (a warm one is far faster;
use a small preset for meetings). The audio goes into the virtual source, so **the client
must have that source selected as its microphone** — this door cannot reach a browser that
is using the real microphone.

**If it does not work.** `status` first: `muted=yes` means `unmute`; no device means run
`snotra-voice-device.sh ensure`; no voice means `systemctl --user start kokoro-serve` and
`journalctl --user -u kokoro-serve`; silence in the room means the client is not listening
to *Snotra Mic*.

## The ladder — transcript → minutes → promises → todos

**What it is.** `bin/records/snotra-ladder.sh` finishes what the ear starts. The ear recorded and
transcribed and then **stopped**, and nothing said so: measured 2026-11-09 the shelf held
`3 meetings · 2 transcripts · 0 minutes · 0 promises`. The ladder now walks four rungs and
names the one it cannot pass.

```sh
bin/records/snotra-ladder.sh steps                     # what the four rungs are, and what each proves
bin/records/snotra-ladder.sh run <id-or-folder>        # one meeting
bin/records/snotra-ladder.sh run --pending             # every transcript with no minutes
bin/records/snotra-ladder.sh status <id>               # where this meeting stands
bin/records/snotra-ladder.sh --self-test               # a finished run and a failed step, proven
```

```
ladder[4]{step,what}:
  "transcript","the words beside the recording (transcribed on the seat when only audio exists)"
  "minutes","composed BY THE MODEL from the transcript and the people present, into that meeting's own folder"
  "promises","every promise the minutes carry, written as actions.md in the same folder"
  "todos","every promise filed on the board in the same act (bin/records/todos.sh)"
```

**A step that fails says so.** It writes `stopped at <step>: <reason>` into the meeting's own
`.state`, fires the hotline, and exits non-zero — so a meeting that failed at transcription
never looks finished. A rung that is already done is not redone twice, and a promise filed once
is not filed again (the board is keyed per meeting and rung).

**The minutes are the model's, not a template's.** Which model is the seat's own choice
(`SNOTRA_RAIL_MODEL` in the watch unit's drop-in, then `RAIL_MODEL`, then the rail's first
served model); the rail URL and the key resolve through `bin/model/rail-resolve.sh` and the
vault. If no rail answers, the rung FAILS with the reason rather than inventing minutes.

## The index — what your calls produced

`bin/records/meetings.sh` reads the folders and derives one row per meeting; it is never a
second record. Beyond `list · show · totals` it answers:

```sh
bin/records/meetings.sh json            # the same rows, machine-readable (one shape for every reader)
bin/records/meetings.sh brief           # the ONE line the daily brief carries
bin/records/meetings.sh state <id>      # finished, or `stopped at <step>: <reason>`
bin/records/meetings.sh plans <id>      # the plans this meeting produced
```

**The join both ways.** A plan written out of a meeting carries `from_meeting: <id>` in its
header — `bin/records/plan.sh new <slug> --title "<title>" --from-meeting <id>` writes it, and
`bin/records/plan.sh from-meeting <id>` reads it back. `meetings.sh plans <id>` refuses rather
than guessing when no plan names the meeting.

**If it does not work.** `meetings.sh totals` is the ground truth: `with_minutes` at 0 means the
ladder has not run (or stopped — `meetings.sh state <id>` says which). An empty `plans` answer
means no plan header names that meeting yet.

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
