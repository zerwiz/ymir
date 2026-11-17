---
section: agents-work-collaboration
---
| Letters | **A reply names its message — the letters door infers the thread, or refuses** (`systems/snotra/services/letters/mail-send.sh` · [how-to](docs/features/letter-templates.md)) | Three letters went out in one night with `Re:` subjects that began new threads: naming a message meant knowing a Gmail id, and the one name a person has is the subject. A subject that opens `Re:` is now a claim the door proves before the letter is drafted — exactly **one** message in the mailbox matching the normalised subject (any number of leading `Re:`, case folded, whitespace collapsed) and the door sets `In-Reply-To`, `References` and the `threadId` itself, printing `answers <id> <subject> <sender> <date>`. **Zero** matches or **more than one** is a refusal naming its reason and listing every candidate (id · subject · sender · date); a mailbox that cannot be searched is a refusal too, never a silent new thread. `--new-thread` is the deliberate way to start a conversation without headers, `--reply-to <id>` still wins when given, and a subject that does not open `Re:` is untouched and never looked up. Proved by seven new cases in `bin/mail/tests/test_headers.py` (19 green), offline against a stood-in Gmail API and DNS | [docs/features/letter-templates.md](docs/features/letter-templates.md) |

## CHANGE LOG

- 2026-11-16 — review-mend: added missing heading for #812
