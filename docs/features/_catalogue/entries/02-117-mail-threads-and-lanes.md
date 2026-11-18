---
section: agents-work-collaboration
---
| Records | **The lanes — did we answer this, and what is this thread waiting on** (`bin/mail/threads.sh` · [how-to](docs/features/mail-threads-and-lanes.md)) | Plan 305 §2.1, phase 1: the store held 226 messages both ways with a `thread_key` on every row and joined none of them, so the house could say what arrived and what it sent and never *did we answer this*. One reader over the one record prints one row per conversation — direction of the last message · when · whether an outbound message came after the last inbound · days an answer is owed · lane — in four lanes: **needs-you** (the only one that speaks) · **answered** · **waiting-on-them** · **closed** (his mark, a notice that owes nothing, or a finished exchange). `--json` is the face a dispatcher consumes, `--lane` filters, and the door **reads only**: the store is byte-identical afterwards. Proved by `bin/mail/tests/test_threads.py` (13 proofs, incl. the answered · unanswered · waiting fixtures) | [docs/features/mail-threads-and-lanes.md](docs/features/mail-threads-and-lanes.md) |

## CHANGE LOG

- 2026-11-16 — added with the door (plan 305 phase 1).
