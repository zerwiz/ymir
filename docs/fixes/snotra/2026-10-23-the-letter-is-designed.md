## snotra · 2026-10-23 — the letter is designed, and every value in it still comes from the record

### Files
- `bin/time/snotra/snotra-letter.py` — `letter_html()` rebuilt to the Allfather's design
- `docs/snotra/the-letters.md` (the design section, later this pass)

### What changed
The Allfather supplied a full page design — a dark header band, a three-figure summary bar, grade chips
(A red · B amber · C grey), question cards, an "assignee / open actions" table, an attachments grid, the ask
in a rule-bordered callout, a next-meeting card, and a signed footer. It is now **the** letter, generated from
the record:

| part of the design | where its values come from |
|---|---|
| header: company · title · date · participants | `meeting.company` (resolved to the display name in `companies.yaml`) · `title` · `started_at` · `participants[present]` |
| summary bar (14 · 4 · 3) | the record's own counts — never typed |
| grade chips + legend | `decisions[].grade`, ordered A → B → C |
| question cards | `questions[].question`, with `asked_by` when the record names one |
| assignee / open actions | `actions[].owner`, counted — the record's owners, nothing inferred |
| attachments grid | **only the files the draft actually carries**, labelled by extension |
| the ask | the record's confirmation action, quoted, with its id, owner, `definition_of_done` and due date |
| the note | the record's risk mitigation, verbatim, with its `RSK-…` id |
| "how to answer" | the letter's own instruction (confirm / `objection: …`), naming the id rule the watcher uses |
| next meeting | the place's cadence (Monday + `monday_at`), marked **proposed** |
| footer | `roles.operator` as the signer, the company, the mailbox |

**No sentence in it is new.** The two lines that are ours — "how to answer" and the footer — are instructions
about the letter itself, not claims about the meeting.

### Measured
```
letters/reygan-assareh.html   21 066 bytes   (was 5 334)
probes: 'Example8 Technologies' 2 · '#12263f' 10 · 'Grade A · Critical' 1 · '2026-10-24' 2 · 'DEC-20261022' 1
sections: Who does what · What I need from you · How to answer · Next meeting   all present
sent: the designed letter to <the operator's address> only (approved cde98d0b…)
```
The two partner drafts carry the same design and stay unsent until his word.

**2026-11-03 (correction, appended):** the operator's name and address were redacted from this note. They are personal data: they belong in the home, and a public fix note may say *the operator* and nothing more (RULES/04, RULES/06 — the correction is recorded, not the leak).

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: a person the house meets. The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).
