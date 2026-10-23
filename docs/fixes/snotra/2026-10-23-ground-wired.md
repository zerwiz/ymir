## snotra · 2026-10-23 — ground wired into the answer path (and what is still not green)

### Files
- `bin/assistant/skirnir.py` — `ground_answer()` called **before** the refusal, in the last-resort branch
- `bin/assistant/ground.py` — the readers (see the note of the same name)

### What now answers, that refused an hour ago
```
"did we email Reygan?"            → Reygan Assareh — 2026-10-22: letter draft, 3 cards filed on the board;
                                    2026-10-20: not recorded. (read from the meeting records, 2026-10-23.)
"which meetings was Reygan in?"   → the same reader, per meeting
"are you free tomorrow?"          → "He is busy over the next day, per the calendar reader
                                    (calendar-ask.sh, read 2026-10-23 22:37; the window is the reader's own.)"
"what did we decide about X?"     → the record items matching, with DEC/ACT/OQ ids and status
"which projects do we have?"      → the registry, house · posture · plans
```
Every answer names its door and the date it read it (Rule 37). A reader that throws returns `None`, so the honest
refusal stands — the patch widens the assistant, it never makes it guess.

### The names are not in the tree
A first version carried a list of people's first names inside `skirnir.py`; `public-guard` refused it and was
right (Rule 04). The name is now resolved **from `collaborators.yaml`** at answer time — the register is the only
place people live.

### What is still NOT green — stated, not hidden
`walls-test` reports **9 failures with the digest properly loaded**, and **at least one predates this change**: a
question about the vault is answered from a *feature fact* (`intent=fact:feature-the-vault-s-edit-door…`) instead
of refusing. The suite could not be proven green in this session, so this change is **not** claimed production
ready: it is reviewable, it is reversible (one function and one branch), and the next session's first task is the
suite, then the three remaining items — identity per turn, `mouth → ear → answer`, and the knowledge application.
