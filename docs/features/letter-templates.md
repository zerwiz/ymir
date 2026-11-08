# Letter templates — make an email look as good as it reads

**What it is.** A shelf of ready-made HTML email layouts inside the house, so a letter you send looks
deliberate instead of plain. Seven templates from three respected sources, already downloaded into the tree and
free to use (MIT licence, licence files travel with them). Pick one, replace the words, send.

**Why it exists.** The mail door has always been able to send a styled letter — it just never told anyone *what*
to style it with, so every letter looked like whichever hand happened to write it.

## What you need

Nothing to install. The templates are already in your copy of Ymir:

    systems/snotra/services/letters/templates/

## Do it — a nice-looking letter in three steps

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

## If it does not work

- **The draft is refused** with a `private-guard` finding: the letter carries something private (a machine path, an
  internal address, a name that belongs in the hoard). Fix the words, not the guard.
- **The HTML looks broken in one client:** check you kept the styles inline and did not remove the outer table.
- **The door says `send refused … STALE`:** the draft changed after it was approved. Approve it again — one word, one
  send.

## CHANGE LOG

- **2026-11-07** — first written, with the shelf it describes: seven templates vendored at pinned commits, both mail
  doors naming them, and the house rules a template does not relax.
