# snotra · 2026-11-12 — the made-by line links to Ymir's homepage

## Files
- `systems/snotra/services/letters/letter-design.py`: `made_by_html()`, `YMIR_HOMEPAGE`, the `made_by_url:` header;
  three self-test checks
- `.agents/skills/snotra-letters/SKILL.md`, `docs/features/letter-templates.md`

## Why
The operator, 2026-11-12: *"in the templates for the mails when were saying made by ymir. send the link also to ymirs
homepage. https://ymir.zerwiz.org"*. The line said who made the letter, but a reader had no way to find Ymir.

## What changed
- The line under every designed letter's footer now reads `Made with Ymir by <agent> · ymir.zerwiz.org`. "Ymir" and
  the address both link to the homepage. The address is written out because some mail programs strip links.
- The link resolves from `made_by_url:` in the letter's header, then `YMIR_HOMEPAGE_URL`, then the public homepage
  (Rule 07: one documented default). `made_by: off` still removes the whole line.

## Proof
`python3 systems/snotra/services/letters/letter-design.py --self-test` → `ok (31 types × 10 themes)`. The checks
cover the agent's name, the homepage link, the shown address, and `made_by_url:` changing the link.

## CHANGE LOG
- **2026-11-12** — Written with the change.
