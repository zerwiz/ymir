# The letters gained a template shelf

**Date:** 2026-11-07 · **Component:** snotra · **Door:** `systems/snotra/services/letters/mail-send.sh` ·
`systems/snotra/services/letters/snotra-letter.sh`

## What the Allfather asked for

*"i wanna the email system to mention to use some of the html template for amil creations so they look noce. go
online an find a few templates that we can use for emails."* — then, when the candidates were named: *"donwoad them to
us"*.

## What was wrong

The mail door could already send a styled letter — `draft … --html FILE` has always built a
`multipart/alternative` message — but nothing in the tree said **what** to put in that file. Every letter so far was
hand-written HTML or none at all, so the quality of what a partner receives depended on which hand happened to be
sitting in the chair. Advice in a document is not a capability: the next hand writes another table.

## What was done

- **A shelf, not a link list.** Seven HTML templates from three upstreams, vendored at pinned commits under
  `systems/snotra/services/letters/templates/`, each with its own upstream `LICENSE` beside it:
  leemunroe `60b5b6d` (MIT) · Cerberus `af3cec9` (MIT, three patterns) · Mailgun transactional `e05e59e` (MIT,
  act · notice · invoice).
- **A README that is the contract.** Provenance with the exact commit, what each file is best for, the house rules a
  template does not relax (inline CSS, tables not flex, no JavaScript, no tracking pixel or remote image, 600 px,
  legible with images off, plain text is the real words, nothing private inside a template), and the procedure for
  updating: re-download from the **pin**, never from a default branch.
- **Both doors now name it.** `mail-send.sh --help` and `snotra-letter.sh --help` print the shelf and the reason to
  use it, so a hand that has never read the Galdr asset still finds it. The owning asset
  (`.agents/skills/galdr-ymirsystem/assets/snotra-meeting-ear.md`) carries the same section with the licence duty.

## How it was proved

```
proof[4]{what,how,result}:
  "the shelf is real","7 files + 3 licences + README, each HTML beginning with a doctype","present; 6.8 KB–43 KB"
  "the door accepts a template","draft … --html templates/leemunroe-simple/email.html --dry-run","eml written; Content-Type: multipart/alternative, text/plain part first"
  "nothing was sent while proving it","--dry-run (returns before any Gmail call)","no draft id, no message"
  "syntax","bash -n on both doors","silent"
```

The guard the draft path already runs (`private-guard check --surface email --to …`) was exercised on the same body,
clean.

## What is still owed

- The Cerberus files carry `via.placeholder.com` images by design; a letter that uses one must strip them first, or it
  phones out to a stranger's server. The README says so in the rules list.
- No house-branded template yet: the shelf gives shapes, not our own hand. That is design work (Hnoss), and it should
  arrive as its own row when the first letter actually needs it.
- `snotra-letter.py` still renders its own minimal inline HTML. Pointing it at a shelf template is a separate, small
  change with its own test — deliberately not bundled here, so this fix stays reviewable.

## CHANGE LOG

- **2026-11-07** — written with the change (nidavellir): the shelf vendored, the doors' help updated, the Galdr asset
  appended, and the two public-data findings mended before the push.

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: a dev machine. The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).
