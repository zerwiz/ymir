---
name: snotra-letters
description: >-
  Write and send any outgoing email so it arrives designed: the house letter design (13 letter types × themes,
  including Ymir's own colours from the design tokens), the seven vendored HTML layouts, the meeting letter, and the
  occasion templates — and the one door that drafts, previews, approves and sends. Use whenever an email, letter,
  update, agenda, meeting record, follow-up, request, notice, quote, welcome, introduction or digest is to be sent,
  or when asked "which template", "make it look better", "send it as HTML". Keywords — email, mail, letter,
  template, HTML, design, theme, newsletter, agenda, minutes, follow-up, invoice, quote, notice, draft, send.
argument-hint: "[types | themes | render <letter.md> | gallery <dir> | draft <letter.md>]"
---

# Snotra's letters — every outgoing mail, designed

A letter is written as **plain words with a few markers**; the house renders it into email-safe HTML and sends the
plain words beside it, so it reads well in any mail client. Nobody hand-builds HTML.

## The four shelves, and which to use

| shelf | where | use it for |
|---|---|---|
| **the letter design** — 13 letter types, the blocks, the themes | `systems/snotra/services/letters/letter-design.py`, types in `templates/house/types/` | **almost every letter** — start here |
| **the meeting letter** — the record of a meeting as a designed page | `systems/snotra/services/letters/snotra-letter.py` | the letter generated from a Snotra meeting record |
| **seven vendored layouts** — leemunroe-simple, Cerberus (fluid, responsive, hybrid), Mailgun (action, alert, billing) | `systems/snotra/services/letters/templates/` (README there) | a letter hand-dressed in a special layout; `leemunroe-simple` is the automatic fallback for a body with no theme |
| **occasion texts** — follow-ups after client, team, sales, board, stand-up and workshop meetings; agenda, sign-off, header | `midgard/email-templates/` | the words for those occasions — paste them into a letter type to design them |

Private letter types and company themes live in the **home**, never here (this repository is public):
`$YMIR_HOME/hodd/identity/letters/themes.yaml` and `$YMIR_HOME/hodd/identity/letters/types/`. The renderer reads them.

## Do it

```sh
L=systems/snotra/services/letters
python3 $L/letter-design.py --types                 # the letter types and what each is for
python3 $L/letter-design.py --themes                # the themes (shipped + the home's)
cp $L/templates/house/types/update.md /tmp/letter.md   # start from a type; fill the {{placeholders}}
python3 $L/letter-design.py /tmp/letter.md > /tmp/letter.html   # preview in a browser
bash $L/mail-send.sh draft --to a@x --subject "…" --body /tmp/letter.md   # designed automatically (theme: header)
# sending needs the operator's approval of those exact bytes: snotra-approve.sh approve <draft> → mail-send.sh send <draft>
```

## The markers

The letter opens with a header (`theme`, `kicker`, `title`, `subtitle`, `footer`, `preheader`, `use`). Then blocks,
separated by a blank line: `## heading` · paragraphs (`**bold**`, `` `code` ``, `[text](url)`) · `- list` ·
`1. **title** — detail` (numbered rows) · `| table |` (a `|---|` row makes a header) · `> quote` · `::: callout` ·
`::: note Title` · `::: warning Title` · `::: card 1 | Owner | Title` · `::: stats` (`value | label` per line) ·
`::: button Label | https://…`. Every `:::` block except `button` ends with `:::`.

## Rules

- **Never a secret in a letter** — the private guard refuses it, and a key belongs in a password manager.
- **Never send without the operator's word** — `send` refuses a draft whose approval does not match its bytes.
- **The company's theme for the company's mail** — keeps companies apart in the reader's inbox.
- **A new letter type** that is generic goes in `templates/house/types/` (public, placeholders only); one with a
  company's or a person's details goes in the home.
- Proof: `python3 systems/snotra/services/letters/letter-design.py --self-test` (every type in every theme).

## CHANGE LOG

- **2026-11-11** — first written with the house letter design (plan 250 §7): the four template shelves, the letter types, the themes, the markers.
