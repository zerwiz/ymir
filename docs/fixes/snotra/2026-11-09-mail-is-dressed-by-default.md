# snotra · 2026-11-09 · Mail is dressed by default

## What was wrong

A letter could always be styled, and almost never was. `mail-send.sh` took `--html` and nobody passed it, so the house
sent plain text — in his words, *"we are mailing it ugly emails from ymir to often"*. The shelf of seven vendored
templates was a step someone had to remember, which is the same as a step nobody takes.

Worse, the operator's own notification door (`bin/notify/mail.sh`) is a *separate* sender: it posts to
`users/me/messages/send` itself and built one plain-text part. So the house had two mail paths and two looks.

## Why it happened

The door was written for a person who knew which template they wanted. It had no default because a default implies
choosing a shape for the caller, and the first version of the shelf was about *provenance* (pinned commits, MIT
notices) rather than about *use*.

## What changed

- **`systems/snotra/services/letters/letter-html.py`** — the renderer. A plain body becomes a letter inside
  `leemunroe-simple`: headings, bullet lists, `**bold**` and bare URLs dressed, every value escaped, and the template's
  demo lines (sample preheader, fictional company address, htmlemail.io credit) removed. It edits four markers, which is
  the whole reason it supports one template and **refuses the other six by name** with the reason and the remedy.
- **`mail-send.sh draft`** — renders when `--html` is absent; `--plain` is the deliberate opt-out; `--template` names
  another renderer-supported layout; `--footer` is the only line it will add. Help text updated to say so.
- **`bin/notify/mail.sh`** — builds the same two halves from the same renderer. A renderer that fails prints the reason
  on stderr and the notice still leaves: a typeface must never cost a message.
- **Two gates that had been red since the plan-129 move** — `test_outbound_gate.py` read the retired shims for the
  door's own behaviour, so `MailGate.test_4` and `CalendarGate.test_6` proved nothing. Both read the moved doors now.
  `bin/collab/letter.sh` names the approval door in its header, so the "sends around the gate" ward stops flagging a
  door that only ever drafts.
- Two new gate cases: a dressed draft and a `--plain` draft, both parsed out of the exact bytes the door would send.
- Docs in the same change: the templates README, `docs/features/letter-templates.md`, the catalogue entry
  `02-015-a-letter-is-dressed-by-default.md` (FEATURES.md re-woven), and the owning Galdr asset.

## What was run, and what it printed

```
python3 systems/snotra/services/letters/letter-html.py --self-test
      PASS  letter-html: eleven proofs — markers, escaping, footer, refusals

python3 bin/time/snotra/tests/test_outbound_gate.py
      Ran 14 tests in 19.06s — OK          (was 12 pass · 2 fail before this change)

bash systems/snotra/services/letters/mail-send.sh draft --to … --subject … --body /tmp/probe-body.md \
     --footer "Example9 · sent from the house" --dry-run
      eml → content-type: multipart/alternative · text/plain 69 chars · text/html 7823 chars
      no "Company Inc", no "htmlemail.io", no "This is preheader text"; the footer and the <ul> present

bin/notify/mail.sh --kind merged --subject "PR #45 is open" --body-text "…"   (against a stub Gmail API)
      content-type: multipart/alternative · text/plain 216 chars · text/html 8035 chars · no demo line
```

## What this does not do

`snotra-letter.py` (the meeting letter generator) still builds its own plain layout — dressing it is a separate change,
named on the feature page rather than quietly assumed.

## CHANGE LOG

- **2026-11-09** — Written with the change it records: a letter is dressed by default (`letter-html.py`, `mail-send.sh`
  1.0.3, `bin/notify/mail.sh`), the two gates that had been red since the plan-129 move are repointed at the moved
  doors, and the tests answer their own DNS so the suite depends on neither the internet nor somebody's real mailbox.
