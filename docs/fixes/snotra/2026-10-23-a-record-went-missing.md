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

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: a person the house meets. The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).

## CHANGE LOG

- 2026-11-14 — review-mend: added missing heading for #755
