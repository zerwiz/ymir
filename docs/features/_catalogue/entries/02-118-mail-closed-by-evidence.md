---
section: agents-work-collaboration
---
| Records | **Closed by evidence — a conversation ends by a document, a meeting, a filing, or a marked "answered elsewhere"** (`bin/mail/threads.sh` · [how-to](docs/features/mail-threads-and-lanes.md)) | The audit of the 49, 2026-11-17: the mutual NDA was signed on 16 October and confirmed on the 19th, and the lane still read open, because it accepted nothing but a reply. A lane that only accepts a letter marks finished work as debt forever. The door now reads the home's `hodd/memory/mail/evidence.yaml` (or `--evidence FILE`) and closes a thread on three more kinds — **document** (a path), **meeting** (the record), **filing** (the register row) — naming the kind, the reference and the message id on the closed line. The fifth kind is a mark, not a reply: `answered-elsewhere`, a letter to the same person inside `--window DAYS` (14) about something else, counted separately and never as an answer. A row is checked before it may close anything: a **sender domain** is refused outright, and a document or meeting row that narrows to the sender alone is refused with the reason, because a rule matching a sender's domain folded the unsigned development agreement into the signed NDA and hid it. Refusals are named on stderr and counted in `--json`. Proved by `bin/mail/tests/test_threads.py` (23 proofs) | [docs/features/mail-threads-and-lanes.md](docs/features/mail-threads-and-lanes.md) |

## CHANGE LOG

- 2026-11-16 — review-mend: added missing heading for #808
