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
bin/time/snotra/snotra-store.sh new work "roadmap" --title "Road map" \
  --source ping --platform ping --classification confidential
bin/time/snotra/snotra-store.sh put <id> transcript.md --as transcript
bin/time/snotra/snotra-store.sh index
bin/time/snotra/snotra-store.sh verify --all

# 2. Þing on demand — raise a room where you are, then lower it
bin/thing/ping-room.sh start --mode tailnet
bin/thing/ping-room.sh url
bin/thing/ping-room.sh stop

# 3. calendar auto-join — plan first, run later
bin/time/snotra/snotra-autojoin.sh scan
bin/time/snotra/snotra-autojoin.sh run            # dry run
bin/time/snotra/snotra-autojoin.sh run --apply    # sends the bot

# 4. the bot — Snotra joins a call through Vexa
bin/time/snotra/snotra-bot.sh join https://meet.google.com/abc-defg-hij
bin/time/snotra/snotra-bot.sh status <id>
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
