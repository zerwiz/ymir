## snotra · 2026-10-23 — `snotra-dispatch.sh who "<person>"`: what we sent, and where each person was

### Files
- `bin/time/snotra/snotra-dispatch.{sh,py}` (new — read-only)

### Why
The Allfather: *"he should know if we have emailed Reygan, cuz we have — and what was in that email"*, and *"did we
send them the board? what meeting were they in?"*. Every answer existed in four files — `record.json`
(`participants[]`), `letters.json` (drafted/sent + time), `cards.json` (what was filed), `replies.jsonl` (what came
back) — and no door read them together.

### What it does
```bash
snotra-dispatch.sh who "Reygan Assareh"   # per meeting: letter state · filed cards · replies · when written
snotra-dispatch.sh who --unsent           # meetings whose letters are drafted and NOT sent
```
Measured today: `meeting{M-20261022-sync-reygan-craig, letter:draft r-… · not sent, filed:3, replies:0, read:2026-10-23
19:22}` and `meeting{M-20261020-roadmap-trello, letter:not recorded, filed:not recorded, read:no letters.json}`.

### The laws it keeps
- **never the mailbox** — it reads the vault; the watcher owns the mail;
- **a send is a send only when `letters.json` carries `sent.at`** — a draft is a draft, however it looks;
- **an absent file is "not recorded", never "not sent"** (Rule 37);
- every row names the meeting id and the date the state file was written, so a reader can check it.
