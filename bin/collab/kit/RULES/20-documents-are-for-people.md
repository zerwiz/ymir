# 20 — A document is written for a person to read

Written 2026-11-11, from the house rule of the same day (Ymir `RULES/52`), at the operator's word: *"in documentation
we want to always use good looking documents so humans can read them simply."*

## The law

Any document a person will read is written **for that person**. That includes a plan, a ticket, an architecture page, a
research note, a runbook, a README, a fix note and a rule. It uses:

- headings that say what each section answers;
- short paragraphs (sentences of about 20 words, never over 40, active voice);
- **Markdown tables** when each item has three or more facts;
- **Mermaid diagrams** for systems, flows, sequences and states (GitHub renders them);
- **callouts** (`> [!NOTE]`, `> [!IMPORTANT]`, `> [!WARNING]`) for what is owed or easy to miss.

It never uses machine-shaped blocks such as `name[n]{a,b}:` followed by quoted rows, or diagrams drawn in ASCII
boxes. Those stay in what only a machine reads: tool output, a registry a script parses, a ledger row.

## Why

Agents wrote whole plans and architecture pages in a machine format because an older rule said that format "belonged in
files". The facts were right, and a person could not read them. A document nobody can read is a document nobody
reviews.

## How

Start from `docs/templates/INDEX.md`. It has a template for every kind of document, with each licence. A document still
in the old shape is converted when it is next touched. The conversion is format only: every fact, number and link is
kept, and the change log says so.

## References

- `docs/templates/INDEX.md` — the template shelf
- `docs/headers.md` — the header every document opens with
- `RULES/19-plan-validate-execute.md` — plans and tickets
- Ymir `RULES/52-documents-are-for-people.md` — the house law this rule carries
