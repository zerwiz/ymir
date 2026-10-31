# The letters — one per participant, from the record

The letter is how the meeting reaches people who were in it. It is **rendered**, never written by hand: three
of the same document in a folder (the fault of 2026-10-23 02:00) is what this page exists to prevent.

## Three files, one letter

```
letters/<person>.txt    the email BODY — plain text, and plain text is a format, not a fallback
letters/<person>.html   the same letter, designed — what most people will actually read
letters/<person>.md     the vault's readable copy
```

The Gmail draft is **multipart**: the text part, the HTML alternative, then the attachments.

## The body — plain-text rules (fetched, then applied)

| rule | why | in the letter |
|---|---|---|
| no markdown, no `#` headings | a text part shows syntax literally | sections are `YOUR ACTIONS`, `THE DECISIONS` — capitals |
| hierarchy without headings | Campaign Monitor's plain-text guidance | `  Grade A` indents, blank lines between blocks |
| mark the ask | one action must be unmissable | `* WHAT I NEED FROM YOU` |
| ~72 columns | readable without wrapping in strange ways | every paragraph is wrapped at 72 |
| names, not links | a text part cannot hyperlink | attachments are written out: `record.pdf`, `decisions.md`, … |

Order, which is the room's order rather than a template's:

```
greeting
one sentence: what this is (the record, not a summary) and its counts
YOUR ACTIONS            — only theirs, with date and "done when"
THE DECISIONS           — grouped A / B / C, "(you decided)" only where the record says so
OPEN QUESTIONS
* WHAT I NEED FROM YOU  — confirm or correct by <date>, and what silence means
WHAT THIS RECORD COVERS — the source, what is missing, the attribution state
ATTACHED
who holds the register · sender · "sent on the operator's approval"
```

## The design — an email-safe page

- **600 px, single column**, wrapped in a `role="presentation"` table (Outlook has no flexbox).
- **inline CSS**, a system font stack (`-apple-system, Segoe UI, Roboto, …`), 15.5 px / 1.62 body.
- **contrast** per WCAG 2.2 §1.4.3: `#26261f` on `#ffffff` ≈ 13:1; muted `#5b5b56` ≈ 7:1 — the floor is 4.5:1.
- **no images** at all, so there is no alt text to forget and no blocked-image hole in the layout.
- the ask sits in an amber call-out with a 4 px bronze left rule — one thing to see in a skim.
- the coverage block is a quiet grey box: present, not shouting.
- a footer naming the sender, the vault record id, and that corrections are appended, never edited in.

## The gate

```bash
snotra-letter.sh render <dir>            # writes the three files; sends nothing
snotra-letter.sh draft  <dir>            # Gmail drafts: text + html + attachments
snotra-approve.sh approve <draft-id>     # binds the approval to the draft's EXACT bytes
snotra-letter.sh send   <dir> --approved # refuses without the approval record
```

`snotra-approve.sh` hashes the draft: **edit one character after approval and the approval no longer
matches.** That exists because on 2026-10-23 a letter about how the company runs meetings reached the
partners before the operator had seen it.

## What a letter may not do

- **name an attachment it does not carry** (measured: three drafts promised three files and carried none);
- **claim to be the complete record** when the coverage block says otherwise;
- **ascribe a decision to a person** the record has not attributed;
- **be sent by an agent**.

## Appended 2026-10-24 — the gate is a verb of the door, not of the caller

The gate described above was real and it held for letters, because `snotra-letter.py send` asked it. Measured on
2026-10-24 (plan 124 §7), it held for **nothing else**: `mail-send.sh send <draft-id>` POSTed `drafts/send`
without asking, `calendar-invite.sh` posted with `sendUpdates=all`, and Gná's send path was an unwritten debt.

Three things changed, and none of them is a new rule — they make the existing one impossible to walk past:

- **`send` asks the gate itself.** `snotra-approve.sh gate mail <draft-id>` runs inside the door before the send
  request is built; `snotra-letter.py`'s own `check` is now a courtesy that saves a doomed call, not the guard.
- **The word is spent.** After a successful send the record carries a `.sent` sidecar and a second send is
  refused `ALREADY SENT` — one approval, one letter.
- **A calendar invitation is outbound mail.** `calendar-invite.sh` defaults to `sendUpdates=none` and posts
  `all` only when an approval record matches the event's own rendered body (`snotra-approve.sh approve-event
  evt-<key>`); `cancel --notify` is gated the same way.

Every refusal and every spend is carved into the Runes. The how-to for the operator is
`docs/features/the-outbound-gate.md`; the change record is
`docs/fixes/snotra/2026-10-24-the-gate-is-in-every-door.md`; the proofs are
`bin/time/snotra/tests/test_outbound_gate.py` (12, with no Google in the loop) and each door's `--self-test`.
