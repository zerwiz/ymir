# Fix — the 105 Snotra shims are retired, and the move is finished

**What was wrong.** `bin/time/snotra/` held **107 files: 105 retired shims and 2 real ones.** The move to
`systems/snotra/` finished on 2026-10-24 for its doors, but the old spellings stayed, each a small script that
execs the real door and then announces the move. For a month they were the reason the move looked unfinished —
and the reason a warning appeared on every successful run of anything that still named them.

**What made this safe to do.** Not the deletion: the proof before it.

```
# every invocation of a shim path, across the tree — comments, migrations and the real tests/ excluded
grep -rn 'bin/time/snotra' --include='*.sh' --include='*.py' . \
  | grep -v '^./bin/time/snotra/' | grep -vE ':[0-9]+:[[:space:]]*#' \
  | grep -v '^./.agents/migrations/' | grep -v 'bin/time/snotra/tests/'
# → 0 lines
```
That run followed PR 806, which repointed 38 call sites onto their real doors and proved the same behaviour
through the new path. The zero is the reason the deletion is a cleanup and not a break.

**What still lives at the old spelling, and why.** Two things, neither of them a shim:
- `bin/time/snotra/tests/` — the suite the doors ship with; it never moved, and the doors call it by its real path.
- `bin/time/snotra/calendar-write.sh` — written there after the move began; the ledger names it as still current.

**The ledger.** The `bin/time/snotra/` entry moves from `partial: true` to `superseded: true`, and its
`still_current` list — which named twenty-one files as survivors, most of them long since shims — now names the two
that are true. A ledger that lists a deleted file as current is the same fault in a different place.

**The 105 that went** (105 files):

| | | | | |
|---|---|---|---|---|
| `asana_adapter.py` | `audio-retention.sh` | `calendar-ask.sh` | `calendar-attendees.sh` | `calendar-auth.sh` |
| `calendar-invite.sh` | `channel_calendar.py` | `channel_chat.py` | `channel_email.py` | `channel_kb.py` |
| `channel_todo.py` | `clickup_adapter.py` | `fathom_ingest.py` | `gong_ingest.py` | `google-auth.sh` |
| `hall-snapshot.sh` | `jira_adapter.py` | `knit_ingest.py` | `linear_adapter.py` | `mail-send.sh` |
| `meet_ingest.py` | `meeting-record-guard.sh` | `monday_adapter.py` | `notion_adapter.py` | `org_adapter.py` |
| `otter_ingest.py` | `participants-fill.sh` | `readai_ingest.py` | `reasoning_adapter.py` | `smoke.sh` |
| `snotra-agenda.py` | `snotra-agenda.sh` | `snotra-approve.sh` | `snotra-attrib.py` | `snotra-attrib.sh` |
| `snotra-audio-ladder.py` | `snotra-audio-ladder.sh` | `snotra-autojoin.sh` | `snotra-board.py` | `snotra-board.sh` |
| `snotra-bot.sh` | `snotra-capture.sh` | `snotra-card-moves.py` | `snotra-card-moves.sh` | `snotra-cdp.py` |
| `snotra-cron.sh` | `snotra-detect.sh` | `snotra-dispatch.py` | `snotra-dispatch.sh` | `snotra-ensure.sh` |
| `snotra-evidence.sh` | `snotra-friday-synch.py` | `snotra-friday-synch.sh` | `snotra-grooming.py` | `snotra-grooming.sh` |
| `snotra-harvest.py` | `snotra-harvest.sh` | `snotra-ingest.sh` | `snotra-init.sh` | `snotra-iscall.sh` |
| `snotra-layout.py` | `snotra-layout.sh` | `snotra-letter.py` | `snotra-letter.sh` | `snotra-live.sh` |
| `snotra-mail-watch.py` | `snotra-mail-watch.sh` | `snotra-meet.sh` | `snotra-mine.sh` | `snotra-pipeline.sh` |
| `snotra-project.py` | `snotra-project.sh` | `snotra-promote.py` | `snotra-promote.sh` | `snotra-provenance.sh` |
| `snotra-reason.sh` | `snotra-render-email.sh` | `snotra-render-pdf.sh` | `snotra-render-template.py` | `snotra-route.py` |
| `snotra-route.sh` | `snotra-rules.py` | `snotra-rules.sh` | `snotra-signoff.sh` | `snotra-store.sh` |
| `snotra-stream.sh` | `snotra-talk.py` | `snotra-transcribe-bot.py` | `snotra-transcribe-bot.sh` | `snotra-transcribe.sh` |
| `snotra-trello.py` | `snotra-trello.sh` | `snotra-voice-device.sh` | `snotra-voice.py` | `snotra_paths.py` |
| `stt-shim.py` | `stt-wire.sh` | `teams_ingest.py` | `transcript_ingest.py` | `trello-map.sh` |
| `trello_adapter.py` | `trello_client.py` | `tts-lease.sh` | `ymir-say.sh` | `zoom_ingest.py` |
