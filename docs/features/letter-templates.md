# Letter templates — make an email look as good as it reads

**What it is.** A shelf of ready-made HTML email layouts inside the house, so a letter you send looks
deliberate instead of plain. Seven templates from three respected sources, already downloaded into the tree and
free to use (MIT licence, licence files travel with them). Pick one, replace the words, send.

**Why it exists.** The mail door has always been able to send a styled letter — it just never told anyone *what*
to style it with, so every letter looked like whichever hand happened to write it.

## What you need

Nothing to install. The templates are already in your copy of Ymir:

    systems/snotra/services/letters/templates/

## Do it — a nice-looking letter in one step

**You no longer have to dress anything.** `mail-send.sh draft` renders your words into `leemunroe-simple` by itself,
so a plain `--body` arrives as a designed letter. Notifications to the Allfather (`bin/notify/mail.sh`) are dressed the
same way, by the same renderer, so the house does not send two kinds of mail.

    systems/snotra/services/letters/mail-send.sh draft \
      --to someone@example.com --subject "Your suite is open" \
      --body /tmp/letter.md --footer "Example9 · sent from the house"

That is the whole call. `--plain` sends the bare words on purpose (a machine-to-machine note needs no typeface).
`--template NAME` picks another renderer-supported layout — today only `leemunroe-simple` is re-renderable, and any
other name is refused with the reason rather than silently dressed in the wrong shape.

**When you want a different template**, dress it by hand and pass the file — the three steps below still work, and they
are the only way to use the Cerberus and Mailgun layouts:

1. **Copy a template and make it yours.**

       cp systems/snotra/services/letters/templates/leemunroe-simple/email.html /tmp/letter.html

   Which one to pick: **leemunroe-simple** for a letter that asks for one thing (a reply, a decision, an
   invitation); **cerberus/cerberus-hybrid.html** for a fuller letter with a header and a footer;
   **mailgun-transactional/action.html**, `/alert.html`, `/billing.html` for something to act on, something that
   changed, or a table of amounts.

2. **Write the real words separately.** The plain-text version is not decoration — it is what every phone, watch and
   screen reader falls back to:

       # /tmp/letter.md

3. **Draft it with both.**

       systems/snotra/services/letters/mail-send.sh draft \
         --to someone@example.com \
         --subject "Your suite is open" \
         --body /tmp/letter.md \
         --html /tmp/letter.html

   The door answers with a draft id. Nothing has been sent. Approve those exact words, then send:

       systems/snotra/services/approve/snotra-approve.sh approve <draft-id>
       systems/snotra/services/letters/mail-send.sh send <draft-id>

## The rules that keep it looking good everywhere

- **Keep the styles on the elements.** Email clients throw away most style blocks; what is written inline survives.
- **No scripts, no remote fonts, no tracking pixels.** Most of it is stripped anyway, and a remote image tells a
  stranger's server that your reader opened the letter.
- **Delete the placeholder images.** The Cerberus templates ship pictures from a demo service
  (`via.placeholder.com`); remove those tags or replace them with an image you host.
- **One column, about 600 pixels.** It then reads on a phone without pinching.
- **Nothing private inside a template.** That folder is part of a public repository — a template is a shape, never a
  place to keep facts.

## Limits

- These are layouts, not a branding system. The house's own look — colours, wordmark, footer — is not in them yet.
- A letter still needs the operator's approval before it leaves; the template changes how it looks, never who may send
  it.
- `snotra-letter.py`, which writes meeting letters automatically, still uses its own plain layout. Dressing those is a
  separate change.
- The renderer only re-renders `leemunroe-simple`. The Cerberus and Mailgun files are one-line HTML with no content
  markers, so rewriting them would mean rewriting them: dress one by hand and pass it with `--html`.

## The house letter design — thirteen letter types, themed (added 2026-11-11)

**Most letters should start here.** Write the words with a few markers and the house designs them:

    L=systems/snotra/services/letters
    python3 $L/letter-design.py --types        # update, decision request, agenda, meeting record, follow-up, request,
                                               # notice, quote, welcome, weekly digest, introduction, thank-you, house notice
    python3 $L/letter-design.py --themes       # ymir (dark, Ymir's own colours), ymir-light, plain, and your own
    cp $L/templates/house/types/update.md /tmp/letter.md     # fill in the {{placeholders}}
    python3 $L/letter-design.py /tmp/letter.md > /tmp/preview.html   # look at it in a browser
    bash $L/mail-send.sh draft --to someone@example.com --subject "…" --body /tmp/letter.md

A body that opens with a `theme:` header is designed automatically; the plain-text twin is the same words. The blocks:
`## heading`, paragraphs, `- lists`, `1. **title** — detail`, `| tables |`, `> quotes`, `::: callout`, `::: note Title`,
`::: warning Title`, `::: card 1 | Owner | Title`, `::: stats`, `::: button Label | https://…` (all but `button` end with
`:::`). `python3 $L/letter-design.py --gallery /tmp/gallery` renders every type in every theme for a look.

**Your own companies' themes and private letter types** go in your home, not in this repository:
`$YMIR_HOME/hodd/identity/letters/themes.yaml` (each theme `extends:` a shipped one) and
`$YMIR_HOME/hodd/identity/letters/types/`.

**Letter types for outreach and replies (added 2026-11-12).** Beside the meeting and project letters there are now
types for reaching out and answering: `outreach` (first contact), `outreach-nudge` (a follow-up when there was no
reply), `inquiry-reply` (someone asked about your services), `answer` (the short answer first), `status-reply` (we
have it and are on it), `accept`, `decline`, `proposal`, `partnership`, `invitation`, `reschedule`, `confirmation`,
`apology`, `feedback-request`, `reminder`, `investor-update` and `goodbye`. `letter-design.py --types` lists them all
with what each is for.

**Who prepared the letter.** Every designed letter ends with a small line under its footer, `Made with Ymir by
<agent> · ymir.zerwiz.org`, where the agent is the name your own seat carries (from `~/.pi/agent/extensions/.ymir-seat`).
"Ymir" and the address both link to Ymir's homepage, and the address is written out for mail programs that strip
links. No machine name appears. Write `made_by: <your text>` in the letter's header to change the words,
`made_by_url: <address>` (or the `YMIR_HOMEPAGE_URL` environment variable) to change the link, or `made_by: off` to
remove the line.

**A theme with no company name.** A theme in your home with `label: ""` leaves the bottom of the letter free of any
company name. Use it for letters you send as yourself rather than for a company.

Agents find all of this through the skill `snotra-letters`.

## If it does not work

- **The draft is refused** with a `private-guard` finding: the letter carries something private (a machine path, an
  internal address, a name that belongs in the hoard). Fix the words, not the guard.
- **The HTML looks broken in one client:** check you kept the styles inline and did not remove the outer table.
- **The door says `send refused … STALE`:** the draft changed after it was approved. Approve it again — one word, one
  send.

## CHANGE LOG

- **2026-11-12 (later)** — the made-by line links to Ymir's homepage and shows its address.
- **2026-11-12** — seventeen letter types for outreach and replies (30 in all).
- **2026-11-12** — every letter says it was made with Ymir and by which agent (`made_by:`); a home theme with an
  empty label shows no company name.
- **2026-11-11** — the house letter design: `letter-design.py`, thirteen letter types, themes from Ymir's design tokens
  and from the home, designed by default when a body opens with `theme:`; the skill `snotra-letters` names every shelf.
- **2026-11-09** — a letter is dressed by default. `mail-send.sh draft` renders `--body` into `leemunroe-simple`
  (`letter-html.py`), `--plain` is the deliberate opt-out, `--template` names another renderer-supported layout, and
  `bin/notify/mail.sh` dresses the operator's notifications the same way. The three manual steps remain for the
  templates the renderer cannot see into.
- **2026-11-07** — first written, with the shelf it describes: seven templates vendored at pinned commits, both mail
  doors naming them, and the house rules a template does not relax.
