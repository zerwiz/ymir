# Letter templates — the shelf the mail door draws from

A letter that leaves this house should read as well in Gmail as it does in a terminal. These are
**vendored, pinned, licence-clean** HTML email templates: not inspiration, not links — files in the tree
that a letter can be built from today.

```
systems/snotra/services/letters/
├── mail-send.sh          draft | send | raw | discard | status   (--html FILE, --body FILE)
├── snotra-letter.py      renders letters/<person>.html from a meeting record
└── templates/            THIS SHELF
```

## How a letter uses one

`mail-send.sh draft` takes the plain-text body with `--body` and the styled body with `--html`; the same
call sends both as `multipart/alternative`, so a client that refuses HTML still gets clean prose.

```sh
cp systems/snotra/services/letters/templates/leemunroe-simple/email.html /tmp/letter.html
# replace the placeholders, keep the inline styles, drop every external image
bash systems/snotra/services/letters/mail-send.sh draft \
  --to someone@example.com \
  --subject "…" --body /tmp/letter.md --html /tmp/letter.html
```

`private-guard check --surface email --to <address> <file>` runs inside `draft()` and will refuse a letter
that carries private data. A template is a shape, never a place to keep facts.

## What is on the shelf

```
templates[7]{path,source,pinned,licence,best_for,watch}:
  "leemunroe-simple/email.html","github.com/leemunroe/responsive-html-email-template","60b5b6d (2024-03-20)","MIT","one column, one call to action — an invitation, a decision, a reply","none; the simplest of the three"
  "cerberus/cerberus-fluid.html","github.com/emailmonday/Cerberus","af3cec9 (2026-09-14)","MIT","fluid-hybrid: Outlook-safe, no media query required","replace the via.placeholder.com images"
  "cerberus/cerberus-responsive.html","github.com/emailmonday/Cerberus","af3cec9 (2026-09-14)","MIT","two-column that stacks on a phone","replace the via.placeholder.com images"
  "cerberus/cerberus-hybrid.html","github.com/emailmonday/Cerberus","af3cec9 (2026-09-14)","MIT","the fuller hybrid example — header, hero, body, footer","replace the via.placeholder.com images"
  "mailgun-transactional/action.html","github.com/mailgun/transactional-email-templates","e05e59e (2022-02-03)","MIT","a button that asks for one act — confirm, accept, book","plain, no external assets"
  "mailgun-transactional/alert.html","github.com/mailgun/transactional-email-templates","e05e59e (2022-02-03)","MIT","a notice that something changed or failed","plain, no external assets"
  "mailgun-transactional/billing.html","github.com/mailgun/transactional-email-templates","e05e59e (2022-02-03)","MIT","a table of items and amounts — an invoice, a quote, a summary","plain, no external assets"
```

Each folder carries its upstream `LICENSE`/`LICENSE.txt`. **Do not delete those files** while the code
beside them is used: MIT requires the notice to travel with the copy.

## The house rules a letter must still obey

- **Inline CSS only**, on the elements themselves; no `<style>` block is trusted across clients, though the
  hybrids carry one for the clients that honour it.
- **Tables, not flex or grid.** No JavaScript anywhere — most clients strip it silently.
- **No tracking pixel, no remote font, no third-party image.** An image is hosted by us or it is absent;
  a letter that phones out to a stranger's server leaks the reader to them.
- **One column at 600 px**, readable at 320 px, and legible with images off.
- **Plain text is not optional.** `--body` carries the real words; the HTML is the same words dressed.
- **Nothing private in a template.** A template is public by nature — it sits in a public repository.
- **A letter is signed by the Allfather's own name**, and it never carries a password, an internal
  address, a vault path or a fleet name.

## One local amendment, recorded

`mailgun-transactional/billing.html` ships with a demo mailbox (a fictional `support@` address on a `.inc` demo domain). It is replaced here with
`support@example.com`, because the house's `public-data-guard` reads any personal-looking address in the tree as a
private value (RULES/04) — and it is right to. Nothing else in the seven files was altered; a diff against the pinned
commit should show exactly that one line.

## Updating a template

Re-download from the pinned commit, not from the default branch, so a change upstairs cannot walk into
this tree unannounced:

```sh
curl -fsSL https://raw.githubusercontent.com/emailmonday/Cerberus/<sha>/cerberus-fluid.html \
  -o systems/snotra/services/letters/templates/cerberus/cerberus-fluid.html
```

Then record the new commit in the table above and note the reason in `docs/fixes/` if the shape of a
letter changes with it.

## Why these three sources

**Cerberus** is the reference the industry tests against: fluid-hybrid markup that survives Outlook's
word-engine without a media query. **leemunroe** is the one-file, one-action template that never needs
debugging. **Mailgun's transactional set** is the plainest correct markup for the three letters a
business actually sends — act, notice, invoice — and carries no branding to scrub off.

## CHANGE LOG

- **2026-11-07** — the shelf created: seven files from three MIT upstreams, pinned by commit, with the licence files
  beside them; one demo mailbox amended to an example address for `public-data-guard` (recorded above).
