---
section: agents-work-collaboration
---
| Records | **The weekly draft sweep** (`bin/mail/draft-age.sh --weekly` · `hodd/state/draft-trend.jsonl` · [how-to](docs/features/draft-age-the-unwritten-letter.md)) | The daily brief asks *is anything too old* — from inside a job that can itself be dead, looking only at aged drafts, keeping no yesterday. The week asks a different question: **what did I start and not finish**. `--weekly` lists **every** draft oldest first with its age, appends `{at, drafts, aged, oldest_days}` to an append-only trend file so a habit is visible across weeks, and sends **one** line to the phone carrying a **send / edit / discard button per draft** (`bin/notify/send.sh --buttons`, the Bot API's own `reply_markup` rendered by `bin/notify/telegram-buttons.sh`). A week with no drafts says **nothing** and carves one no-op Rune; a week the door could not read records nothing and never looks quiet. Scheduled `@heart Mon 09:15` — the day gate Nornir learned for it (`BROKK_ROLES` · `.cron-invalid` for a day it cannot read). Proved by `bin/mail/tests/test_draft_age.py` (quiet week · every draft named · aged week · the trend appends and never rewrites · a skip records nothing) and `bin/notify/tests/test_send_buttons.py` | [docs/features/draft-age-the-unwritten-letter.md](docs/features/draft-age-the-unwritten-letter.md) |

## CHANGE LOG

- 2026-11-17 — added with the weekly sweep (plan 305, appended decision).
