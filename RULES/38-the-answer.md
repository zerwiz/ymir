# 38 — The answer is prose, and a decision is a button

**Appended 2026-10-23** at the Allfather's word: *"can we update ymirs formatting rules.
your answers like this are very hard to read. and we also answering over telegram
sometimes and then the allfather should be able to click buttons."*

## The law

An answer to the Allfather is **written to be read by him, not parsed by a machine**.
Short paragraphs, one idea each, plain sentences, a blank line between them. A literal
fact — a pid, a port, a path, an error string — sits inside the sentence, quoted
exactly, once.

What is banned from his reading: TOON blocks, code fences around ordinary answers,
tables with columns, and long runs of bolded datum where a sentence would serve. Those
belong in files, ledgers, fix notes, and agent-facing output (`tasks-cli`, the plan
ledger, the gate API). A table in a chat reply is a datasheet handed to a man asking
for a sentence.

When it truly is a list, it is a plain list, one line each. Never a table to save
vertical space — he reads on a phone as often as on the seat.

## Why

Measured on 2026-10-23: three consecutive answers used TOON-style fences and bolded
key/value tables to report one evening's work. Every number was true; the shape made
them unreadable, and he said so. The house's own canon already said where that shape
belongs — `toon-tasks-cli` is *agent-facing* output — but no rule said where it must
not go. A canon with no prohibition is a habit.

## The button

On a **Telegram** turn, an answer that leaves him a decision is not finished as prose.
It carries **2 to 6 buttons**, under the `telegram_button` contract: a column-zero
triple-backtick fence for rows inside the answer, or an action comment for the footer.
Each label is `emoji + space + text`, chosen by the action's meaning and kept
consistent. Each click carries a **self-contained prompt** that does the thing —
approve the merge, open the PR, raise the service, show the log, dismiss the finding.

```
buttons[4]{rule}:
  "no prose-only decisions","a question he must answer gets a button; never 'reply 1 or 2' or 'say yes'"
  "no decorative buttons","every button advances, inspects, clarifies, recovers, navigates or supervises — a control that restates the sentence above it is noise"
  "labels are readable","emoji + text, short and distinct; the emoji carries the verb's meaning, never the colour"
  "a click grants nothing","it queues an ordinary request under the same authority as typed text; destructive or privileged acts still confirm"
```

Two skills own the detail and must be read before building a surface:
`generated-control-surface` (admission, labels, layout, safety) and `telegram-bridge`
(transport syntax: fences, footers, CGM/JSON encodings).

## Scope

This binds every reply to the Allfather in every harness — the Pi TUI, Telegram, the
seat. It does **not** bind agent-facing output: a TOON block in a plan, a fix note, a
runes row or a tool answer is correct and stays exactly as it is.

Enforced by reading, not by a ward — the ward is that he says "this is hard to read",
and the next answer is prose.


## Appended 2026-11-04 — a table that IS the answer must be readable

His word, after reading a card catalogue built from dense `cards[16]{…}` rows: *"make the tables human readable"*.
The law above bans **column tables in his reading** — that ban stands, and an answer is still prose before it is
anything else. This amendment settles the other half, which was never written down:

```
human_tables[4]{rule,why}:
  "a document is not a reply","in a file — a register, a catalogue, a plan — a table is often the right shape; the ban above is about the reply, not the shelf",
  "when a table is the answer, it is Markdown","pipe tables with a header row and a heading above them, one fact per column; never a dense one-line TOON row a human has to parse",
  "machine shapes stay machine-facing","a `key[n]{a,b,c}:` block is for an agent or a gate to read; if a person will read it, render the same data as a table with words in the headers",
  "the test is one glance","if the Allfather must decode a schema to find a price, the table is wrong — the same data, same honesty, plainly laid out"
```

The doctrine behind it: **the shape follows the reader.** A machine reads columns because they are unambiguous; a
person reads a table with headings and units because the eye can find the row it wants. Writing a person's document as
a machine block is not rigour — it is a second language in the wrong room.


### And a diagram is Mermaid

His word, the same night: *"and also add to use mermaids for humans."* When a document must show a **shape** — how the
fleet fits together, how data moves, which machine holds what — it is drawn in **Mermaid**, never in ASCII art and
never as prose that the reader has to hold in their head. A Mermaid block renders on GitHub, in the editor, and in any
viewer the house reads; it is text in the file, a picture on the page. The same test applies as for tables: if the
reader must trace the words to see the shape, the drawing is wrong.


#### Correction — a diagram is a diagram; Mermaid is one tool that draws many

His word, correcting the paragraph above: *"diagrams are not mermaids. diagrams are diagrams. mermaid is Mermaid.
Mermaid can be used for a lot of things."* Both halves are true and the wording above blurred them.

- **The concept is the diagram.** When a document must show a shape — how the fleet fits together, how a request
  moves, what state a thing is in — it is *drawn*. That requirement stands whether or not Mermaid exists.
- **Mermaid is the house's tool for drawing it**, not a synonym for the drawing. One syntax, many diagram kinds:
  flowchart for a flow, sequence for a conversation between parts, state for a lifecycle, class and ER for data,
  gantt and timeline for a schedule, mindmap for a structure, quadrant for a comparison.
- **So the rule is:** draw what must be seen; draw it in Mermaid when a diagram is what is needed; never ASCII art, and
  never prose the reader has to trace to find the shape.

---

## Appended 2026-11-11 — the clause that sent TOON into documents is withdrawn

**What this rule said:** TOON blocks, tables and code fences are banned from answers, and *"those belong in files,
ledgers, fix notes, and agent-facing output"*. The Scope section said *"a TOON block in a plan, a fix note … is correct
and stays exactly as it is."*

**What was wrong:** agents read that as permission, then as instruction, to write every document in TOON. On
2026-11-11 the Allfather said of a day's architecture pages and plans: *"i cant read what is says in simple ways."*

**What holds now:** answers stay as this rule says. **Documents a person reads are governed by Rule 52**
(`52-documents-are-for-people.md`). They use headings, short paragraphs, Markdown tables, Mermaid diagrams and
callouts, and never TOON. TOON stays only where only a machine reads: tool output, a parsed registry, a ledger row.

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
