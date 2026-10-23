## snotra · 2026-10-23 — `bin/assistant/ground.py`: the readers Skírnir was missing

### Files
- `bin/assistant/ground.py` (new — read-only readers, no model)

### Why
A partner was greeted with the owner's name, "what can you do" was refused, a Swedish request went unanswered, and
"have we emailed Reygan, and what was in it?" had no answer — while every fact sat in the house's own files.

### What it answers
```bash
python3 bin/assistant/ground.py who "@JupiterRoyal"     # → Reygan Assareh · @JupiterRoyal · reygan@inmostinvest.com
python3 bin/assistant/ground.py person "Reygan Assareh"  # per meeting: letter draft/sent, filed, replies, read date
python3 bin/assistant/ground.py decisions "agenda"       # the record items matching the words, with ids + status
python3 bin/assistant/ground.py calendar [1d|ISO..ISO]   # free|busy|unknown + the probe's freshness
```
It also carries `apply_for(question, asker, chat)` — the knowledge application: a file in
`hodd/identity/assistant/pending/` and a row in `asks.json`, so a request the house cannot answer becomes a
question for the Allfather instead of a refusal.

### The laws it keeps
read-only, never the mailbox, never the vault · a send is a send only when `letters.json` carries `sent.at` · an
absent file is **not recorded**, never *not sent* · a missing person is **not in the register**, never a borrowed
name · a calendar answer names its freshness · every answer carries `source` (the door) and `read` (the date), so
the surface can cite it (Rule 37).

### Measured tonight
```
who "@JupiterRoyal"     → Reygan Assareh (found: true, telegram JupiterRoyal, email reygan@inmostinvest.com)
person "Reygan Assareh" → M-20261022-sync-reygan-craig: letter draft · filed 3 · replies 0 · read 2026-10-23
calendar 1d             → verdict busy, source cache, as_of 2026-10-23T19:10Z
```

### NOT done, and said plainly
**It is not yet wired into `skirnir.py`.** The module is built and tested on its own; the one-line integration (at
the refusal site: try `ground.who` → `ground.person` → `ground.decisions` → `ground.availability`, and offer the
knowledge application when nothing answers) must land **with the assistant's own test suite green**, not in the last
minutes of a session that has a live partner conversation running. That is the next session's first task.
