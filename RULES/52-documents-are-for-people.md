# 52 — A document is written for a person to read

Written 2026-11-11 at the Allfather's word, after a day of architecture documents and plans written in TOON blocks:

> *"we need to update the rules we have in ymir etc that this layout of this are not acceptable.. i cant read what is
> says in simple ways. we are having this problem globally. in documentation we wanna use always good looking documents
> so humans can read them simple."*

## The law

Any document a person will read is written **for that person**. This covers a plan, an architecture page, a research
note, a runbook, a README, a fix note, an audit, or a rule. It uses headings, short paragraphs, real Markdown tables,
diagrams and callouts. **It never uses TOON blocks** (`name[n]{a,b,c}:` followed by quoted rows).

TOON stays where only a machine reads: tool output, a registry a script parses, a runes row, the `tasks-cli` answer, an
agent's working notes. **If a person is expected to read it, it is not TOON.**

## Why

Rule 38 (2026-10-23) banned TOON from *answers* to the Allfather. It then said those blocks "belong in files, ledgers,
fix notes", and every agent followed that sentence into every document. On 2026-11-11 a single evening produced seven
architecture pages and seventeen plans whose facts were right and whose shape was unreadable. The rule had moved the
problem from the chat into the files. This rule closes that door.

## How a document is laid out

The layout follows the open practices the research of 2026-11-11 found (sources below):

| Element | When to use it | How |
|---|---|---|
| **Heading** | every few paragraphs; a reader scans headings first | sentence case, says what the section answers |
| **Paragraph** | to explain why, and what it means | one idea, short sentences (aim for about 20 words, never over 40), active voice |
| **Bulleted list** | single items or pairs | one line each, parallel wording; numbered only when order matters |
| **Table** | three or more facts about each item | introduce it with a sentence; no table for layout, for one row, or for one column |
| **Mermaid diagram** | anything with boxes and arrows: a system, a flow, a state machine, a sequence | a fenced `mermaid` block; GitHub renders it natively |
| **Callout** | a warning, a decision owed, a thing easy to miss | GitHub alerts: `> [!NOTE]`, `> [!TIP]`, `> [!IMPORTANT]`, `> [!WARNING]`, `> [!CAUTION]` |
| **Code block** | real code, commands, and exact output only | never to hold prose or a table |

### Which diagram

```mermaid
flowchart LR
    Q{What are you showing?} --> A[Parts of a system<br/>and how they connect] --> A1["flowchart, or C4Context / C4Container"]
    Q --> B[Steps that happen in order<br/>between parties] --> B1[sequenceDiagram]
    Q --> C[A thing that moves<br/>between states] --> C1[stateDiagram-v2]
    Q --> D[Tables and their relations] --> D1[erDiagram]
    Q --> E[Work over time] --> E1[gantt]
```

For a system's architecture, follow the **C4 model**: a *context* diagram first (the system and who and what it talks
to), then a *container* diagram (the running parts). Go deeper only when it helps. ASCII-art boxes are replaced by
Mermaid whenever a document is touched.

### The shape of a document

Every document says what kind it is: a **tutorial** (learn by doing), a **how-to** (do one task), **reference** (look
something up), or an **explanation** (understand why). This follows the **Diátaxis** framework. One document is mostly
one kind. A plan is an explanation with a reference table of its slices.

The first screen of every document tells the reader four things:

1. what this is,
2. its status,
3. the answer in three sentences,
4. what is owed, and by whom.

## What this rule does not change

- **Append-only (Rule 06) still holds for content.** A document already written in TOON is converted when it is next
  touched. The conversion is **format only**: every fact, number and link is carried over. It is done in its own commit
  and recorded in the document's change log. Git keeps the old shape.
- **Answers in chat** are still governed by Rule 38: prose, not tables.
- **Machine files stay machine files.** A YAML registry, a JSONL ledger and a TOON tool output are not documents.

## How it is kept

- The skill **`bragi-documents`** (`.agents/skills/bragi-documents/SKILL.md`) is the working guide, with templates.
  An agent writing a document reads it first.
- A ward that refuses a new TOON block in a Markdown document under `docs/`, `plans/`, `RULES/` and `README.md` files
  is owed (see the fix note of 2026-11-11). Until it exists, the reviewer refuses the PR.

## Sources

- Diátaxis, the four kinds of documentation: <https://diataxis.fr/> · Canonical's adoption: <https://ubuntu.com/blog/diataxis-a-new-foundation-for-canonical-documentation>
- Google developer documentation style guide, tables and lists: <https://developers.google.com/style/tables> · <https://developers.google.com/tech-writing/one/lists-and-tables>
- GitHub renders Mermaid natively: <https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/creating-diagrams>
- GitHub alerts (callouts): <https://www.freecodecamp.org/news/github-flavored-markdown-syntax-examples/>
- The C4 model with Mermaid: <https://dev.to/surgbc/using-github-and-mermaidjs-to-document-software-architecture-using-c4-model-57fn>
- Diagrams as code, and when to use which tool: <https://dev.to/levi_liu/diagrams-as-code-in-2026-mermaid-plantuml-d2-excalidraw-when-to-use-what-4mo9>
- Federal plain language guidelines (sentence length, active voice, headings): <https://webarchive.library.unt.edu/web/20120915090932/http:/www.plainlanguage.gov/howto/guidelines/FederalPLGuidelines/TOC.cfm>

## CHANGE LOG

- **2026-11-11** — Written at the Allfather's word: documents are for people — tables, Mermaid and callouts, never TOON.
