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
