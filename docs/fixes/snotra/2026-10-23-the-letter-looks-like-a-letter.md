## snotra · 2026-10-23 — the letter looks like a letter, and the cards read like cards

### Files
- `bin/time/snotra/snotra-letter.py` (plain-text body + email-safe HTML; multipart draft)
- `bin/time/snotra/snotra-project.py`, `trello_client.py` (members, due dates, checklists, body)
- `hodd/identity/places/synteon/documentation/place.yaml` (roles.chair, roles.operator)

### What was wrong
- **The drafts carried raw Markdown.** `## heading`, `**bold**`, `---` were pasted as the *text* body, so
  Gmail showed the syntax instead of a letter. Plain text is a format, not a fallback.
- **The drafts carried no HTML part** although `mail-send.sh` has supported `--html` all along.
- **Cards had no member and no due date** — an action that names an owner in prose is not assigned to
  anyone, and a card with no date never falls due.
- **The card bodies were flat lines**: no headings, no rules, the quote indistinguishable from the context.

### What the research said (fetched, not assumed)
- Trello renders markdown headings/bold/italics/lists/rules but **not tables** — a `|` grid arrives as
  prose, so every field is now a bold label on its own line.
- Acceptance criteria belong in a **native checklist**, not a bullet list (`- [ ]` renders as text).
- A card should have **one owner, as a member**, and a **real due date**.
- Plain-text email: **no markdown, no header syntax**; hierarchy by capitals and whitespace; the ask
  marked with `*`; attachments named in full; ~72-column lines.
- **WCAG 2.2 AA (1.4.3): 4.5:1 for normal text, 3:1 for large** — the palette uses `#26261f` on `#ffffff`
  (≈ 13:1) and `#5b5b56` for muted labels (≈ 7:1).

### What now stands
- `letters/<person>.txt` — the email body, plain and readable, the ask marked `* WHAT I NEED FROM YOU`.
- `letters/<person>.html` — a single-column 600px card, inline CSS, system fonts, section headings, an
  amber call-out for the ask, a quiet grey coverage box, and a footer that says who sent it.
- the draft is **multipart**: text first, HTML alternative, then five attachments.
- cards: **member** (owner resolved on the board, then the workspace; an unmatched name is reported, never
  invented), **native due** (a bare date becomes noon UTC so it never reads late), **checklist**
  (`Definition of done` for actions, `To confirm` for proposed decisions), and a body with a heading,
  bold labels, rules, the quote in italics with its timestamp, and `record-key` last.
- measured on one card read back: `due 2026-10-22T12:00:00.000Z`, `members ['6ad67aa2…']`,
  `checklists ['Definition of done']`.
