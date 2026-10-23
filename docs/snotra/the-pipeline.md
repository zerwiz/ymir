# The pipeline — one command, and what it refuses

`bin/time/snotra/snotra-pipeline.sh` runs the whole chain for a meeting folder. Everything else in this
shelf is a step of it.

## The grammar

```bash
bin/time/snotra/snotra-pipeline.sh run <meeting-dir> [--dry-run] [--draft] [--shrink]
bin/time/snotra/snotra-pipeline.sh run --recent [DAYS] [--dry-run] [--draft] [--shrink]
bin/time/snotra/snotra-pipeline.sh status <meeting-dir>
```

| switch | what it changes | what it never changes |
|---|---|---|
| `--dry-run` | project/agenda run `plan`; nothing is written anywhere | the order of the chain |
| `--draft` | the letters also become Gmail drafts | nothing is ever sent — sending needs `snotra-approve.sh` |
| `--shrink` | after a verified transcript, the audio ladder runs | it cannot run before the transcript |
| `--recent N` | every meeting folder modified in the last N days (default 2) | one run at a time (flock) |

## The chain, in order

```
record     the record validates (the engine's own validator) — a record that does not validate stops here
harvest    the bot's own audio: fetch + verify byte-for-byte  ·  or verify the staged copy
signal     the bot's STT log audited: ok:true with no words is a WARN when our own transcript stands in,
           a FAILURE when nothing produced text at all
transcribe our own whisper.cpp pass → evidence/bot/transcript.bot.txt (+ .srt, + transcribe.json)
speakers   the capture log split by speakerIndex → one WAV per speaker (the attribution substrate)
layout     the folder standard: a stray stops the chain
project    the record onto the place's boards, by kind — then read back and verified
agenda     the dated agenda card for the next meeting, in the place's agenda list
letters    one letter per participant, rendered from the record (drafts only with --draft)
ladder     verifies → requires a transcript → compresses → strips the duplicated pcm (only with --shrink)
```

A **SKIP** always prints its reason. Nothing in the chain is silent: a step that cannot run says which
prerequisite is missing.

## Failure semantics

| verdict | meaning | exit |
|---|---|---|
| `PASS` | the step proved what it claims | — |
| `WARN` | the vendor failed, our own route covers it (e.g. the bot's STT returned no words) | still 0 |
| `SKIP` | the step does not apply here, with the reason printed | still 0 |
| `FAIL` | the chain **stops** and names the step | 1 |

Two rules make a FAIL honest:

- **a transcript with fewer than 50 words is a failure**, not a record;
- **a meeting with no Meet link is not a failure** — no bot recording can exist, and the harvest step says so.

Every run appends **one rune** to the ledger, so an unattended night leaves a mark whether it worked or not.

## The runbook

**A new meeting** (after the bot has left the room):

```bash
D=~/Documents/ymirhome/svartalfaheim/<company>/meetings/<YYYY-MM-DD>-<slug>
bin/time/snotra/snotra-pipeline.sh run "$D" --dry-run     # what would happen — read it first
bin/time/snotra/snotra-pipeline.sh run "$D" --draft       # do it, and prepare the letters
```

**Then the two human acts**, in this order:

1. **read the letters** in `<meeting>/letters/*.txt` — they are what goes out;
2. **approve and send**: `bin/time/snotra/snotra-approve.sh approve <draft-id>` per letter, then
   `bin/time/snotra/snotra-letter.sh send "$D" --approved`. Nothing sends without this.

**A meeting that went wrong** — the door names the sentence, and the sentence names the remedy:

| what you see | what it means | what to do |
|---|---|---|
| `the bot store is unreachable` | the Vexa API is down or the port moved | `VEXA_API_URL=…`, check `docker ps` |
| `no storage credentials` | the capture log needs S3 creds | `VEXA_COMPOSE_ENV=<compose .env>` or `VEXA_S3_*` |
| `the bot never sat in <code>` | wrong meeting, or the bot never joined | check the join code in the record |
| `size mismatch … refused, not rounded` | the download is incomplete | run `fetch` again; do **not** force it |
| `no transcript, no shrinking` | the ladder refused, correctly | transcribe first |
| `layout{… strays: 1}` | something was left at the top level | `snotra-layout.sh apply` (it moves, never deletes) |
| `misfiled` in `project verify` | a human moved a card | leave it; `--move` is the operator's call |
| `unmatched{name: …}` | the owner is not on the board nor in the workspace | add them to the workspace, then re-run |

## Unattended (the cron line)

The chain is safe to schedule: it is idempotent, locked, and writes a rune. The install (one line in
`config/cron.yaml`, under the Nornir asset's rules) is:

```yaml
- at: "03:10"
  cmd: "bin/time/snotra/snotra-pipeline.sh run --recent 1 --draft"
  note: "Snotra: last night's meetings → record, board, letters (drafts only)"
```

**Two prerequisites** the job depends on, both already true on this seat: the Vexa stack running with the
STT shim reachable (`bin/time/snotra/stt-wire.sh`), and the Trello grant in `~/.pi/agent/mcp-auth.json`.
A night where either is missing fails **loudly** at that step and stops — it does not half-file a meeting.

## What the pipeline deliberately does not do

- **It never sends mail.** Sending is the operator's act, bound to the draft's bytes.
- **It never promotes a decision.** `snotra-promote.sh` requires `--by "<a person>"`.
- **It never invents a person.** An owner who is not on the board is reported, not guessed.
- **It never deletes audio without a transcript**, and never deletes text at all.
