## snotra · 2026-10-23 — a meeting record went missing; the guard that makes it survivable

A tracked transcript — `hodd/life/meetings/2026-10-23-ping-reygan-craig-mic.transcript.md` — was **gone from
disk**. It was caught only because the commit guard refuses a deletion (Rule 11): the push stopped, the file
was restored from git, and the push went through.

**The cause is not provable from the record**, and it is written here as unproven rather than guessed: the
live tail truncates its OWN document, and the pipeline writes `<base>.md` and `<base>.transcript.txt` — neither
names the file that vanished, and no log line does either.

**`bin/time/snotra/meeting-record-guard.sh`** is the answer, and it only ever ADDS:
- `check` — every tracked `.md/.txt/.json/.jsonl` under `hodd/life/meetings` that is missing on disk (exit 1
  when any is);
- `fix` — restores each from git and **carves a rune per restore**, so a vanished meeting leaves a mark
  instead of a silence.

**And it is in the instrument:** `smoke.sh` now asserts *"every tracked meeting record is on disk"* — 38 pass,
0 skip, 0 fail — and a cron row runs the guard nightly at 03:15, before the backup.

**The law it earns:** *a record the system produced cannot be removed by the system that produced it.*
Attribution is nice; survivability is the requirement.
