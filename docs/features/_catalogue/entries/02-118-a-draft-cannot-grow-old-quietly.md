---
section: agents-work-collaboration
---
| Records | **A draft cannot grow old quietly** (`bin/mail/draft-age.sh` · [how-to](docs/features/draft-age-the-unwritten-letter.md)) | A letter started and never sent is the one piece of correspondence that fails in silence: nobody waits for it, so nothing reminds anyone. The door reads Gmail's drafts, gives each one its age in days, and **exits 1, naming every offender**, when a draft is older than the limit (`--days`, default 2). No grant is a **named SKIP**, never a zero that reads like an empty outbox; an unreadable mailbox is `UNABLE` (exit 3). It is read-only: GETs and the one token POST, proved by what the stub never saw. `bin/time/nornir-job-daily-briefing.sh` asks it once before composing: the line lands under *The letters nobody sent*, and an aged draft puts a warning at the top of the brief and makes the job exit non-zero instead of green. Proved by `bin/mail/tests/test_draft_age.py` (11 proofs, incl. no drafts · a fresh draft · an aged draft failing · the brief not publishing a clean day) | [docs/features/draft-age-the-unwritten-letter.md](docs/features/draft-age-the-unwritten-letter.md) |

## CHANGE LOG

- 2026-11-17 — added with the door and its brief wiring.
