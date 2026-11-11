## docs · unversioned · 2026-11-11 — a document is written for a person to read

### Why

The Allfather, after a day of architecture pages and plans written in TOON blocks: *"i cant read what is says in simple
ways. we are having this problem globally."*

Rule 38 (2026-10-23) banned TOON from answers, then said those blocks *"belong in files, ledgers, fix notes"*. Its Scope
section said a TOON block in a plan *"is correct and stays exactly as it is."* `AGENTS.md`'s voice section repeated the
sentence, and Galdr's principle 1 (TOON on stdout) was read as covering documents too. Every agent followed those words
into every document. The house had no writing skill: `bin/agents/skill-find.sh` returned nothing for documentation,
layout or diagrams.

### What changed

- **`RULES/52-documents-are-for-people.md`** (new). Any document a person reads uses headings, short paragraphs,
  Markdown tables, Mermaid diagrams and GitHub callouts, and never TOON. TOON stays in what only a machine reads. A
  TOON document is converted, format only, when next touched. The rule cites the research it rests on: Diátaxis,
  Google's style guide on tables and lists, GitHub's Mermaid and alerts, the C4 model, and plain-language guidelines.
- **`.agents/skills/bragi-documents/`** (new). The working guide: the first screen, which tool when, which diagram,
  converting a TOON block, a done-check. Its `assets/templates/` holds four house templates (plan, architecture,
  research, rule), eleven from The Good Docs Project (MIT No Attribution), two from MADR (MIT or CC0) and arc42's
  plain Markdown (CC BY-SA 4.0). They are shipped unchanged except for renamed files and the guide links pointed
  upstream. `INDEX.md` maps each kind of document to its template and licence.
- **Dated appends**, nothing rewritten: `RULES/38` (the clause withdrawn for documents), `AGENTS.md` (the contract
  section), Galdr's `principles.md` (principle 1 is about stdout, not documents).
- **`RULES/README.md`**: row 52 added, and the `rules_index` count set to the disk's 48. It was already stale on
  `origin/main` (46 declared, 47 on disk since rule 51), and `rules-number-guard.sh` failed there before this change.

### Owed

A ward that refuses a new TOON block in a Markdown document under `docs/`, `plans/`, `RULES/` and `README.md` files.
Until it exists, the reviewer refuses it.

### Files

- `RULES/52-documents-are-for-people.md` · `RULES/38-the-answer.md` · `RULES/README.md` · `AGENTS.md`
- `.agents/skills/bragi-documents/SKILL.md` · `.agents/skills/bragi-documents/assets/templates/**`
- `.agents/skills/galdr-ymirsystem/assets/principles.md`
