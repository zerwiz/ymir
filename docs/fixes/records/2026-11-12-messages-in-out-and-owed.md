# Fix — the house keeps every message in, out and owed, and proposes what it moves on his list

**What was wrong.** Only mail was recorded in both directions. Telegram was read live by the bot and sent by the
hotline, but neither direction was kept. "What we still need to send" lay on five shelves, and his to-do was fed
by nothing. On 2026-11-12 he ticked three items by hand that his own mail already showed were done.

**What was done.**

- `bin/records/comms.py` (door: `comms.sh`) reads `hodd/memory/mail/messages.jsonl` where it lies and keeps
  `hodd/memory/comms/<channel>.jsonl`, with one row shape: channel, direction, who, thread, project, at, ref.
- Skírnir's Telegram adapter (`systems/skirnir/services/telegram.py`) appends a row for every message it hears and
  every answer it sends. `bin/notify/send.sh` appends one when its Telegram leg delivers. Each append is guarded,
  so the record can never break the thing it records. `send.sh` now honours `TELEGRAM_API_BASE`, as the adapter
  already did.
- `owed` gathers the five shelves and Gmail drafts. A letter whose person has since been sent a mail on its subject
  is shown as `sent?`, with that mail.
- `todo-matches` proposes ticks, new items and waiting-ons, each with its evidence. `todo-apply` writes only the
  approved ids, as dated lines in a house-kept half of `todo.md`. His own lines are never edited.
- `bin/mail/mail-scan.sh` gains a read-only `--query`, used for Gmail drafts and a platform's reminder series.
- The 07:00 brief gains a messages section. Rödd's toolbox gains `comms` and `todo_from_mail`.

**How it is proven.** `python3 -m unittest discover -s bin/records/tests -p 'test_comms.py'` runs 10 tests on a
fixture home. They cover: exactly the three true ticks and no false one (a Foreman mail does not tick "merge Foreman
PR #20", and another document's "completed" does not tick the signature); the owed list naming every shelf; his
lines left untouched after an apply; and Telegram recorded both ways through the real adapter loop and the real
hotline, against a local stand-in for the Bot API.

On his real home, run on the to-do as it stood before his hand-ticks (`git show 5a010708^:…/todo.md`), the door
proposes exactly the playbook drafts (high), SignWell (medium) and the Accounted invitation (medium). On today's
file it proposes nothing.

## CHANGE LOG

- **2026-11-12** — written with the door.
