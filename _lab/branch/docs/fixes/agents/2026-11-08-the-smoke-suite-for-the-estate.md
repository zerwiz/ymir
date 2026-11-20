# The smoke suite for the estate and the inbox

**2026-11-08 · component: agents · plan 219**

## What was missing

Every door of the estate was proved once, by hand, on the day it was forged — the canon, the estate
door, the gate, the card, the brief, the injection into the arm holder's chat. None of it was
re-runnable, so a later change could have broken any of the six and nothing would have said so. A
capability with no smoke test is a capability with one good afternoon behind it.

## What was forged

`bin/gates/tests/test_areas_and_injection.sh` — nineteen cases, all local, ~40 seconds:

- **the canon** answers eighteen areas.
- **this tree's estate** answers a project and six numbers, and `check` finds no fault in a legal one.
- **the brief** carries the ground a keeper may write *and* reads the real declaration — the seam
  fault of 2026-11-08, now a case rather than a memory.
- **a scratch guest repository**, with its own git: `init` writes eighteen, a fresh shelf passes
  (all unheld is legal), a scoped-but-unheld ground is recorded, the gate **REFUSES** a change there
  and names the area, and it **passes** once a keeper claims it with evidence.
- **the card** is generated from the shelf, validates, invents no address, and carries a2a 1.0's
  required fields plus a grant scheme.
- **the inbox**: `report.sh` writes its shelf *and* the line is injected into the arm holder's pane;
  with no pane the door names the broken link instead of pretending.

It touches a temp directory and one throwaway report id, and deletes the report. It never touches a
real repository's history.

## Two faults in the test itself, found by running it

`ROOT` was computed one directory short — `bin/gates/tests` is three deep, not two — so every
`bin/agents/...` case failed while the temporary-repository cases passed, which looked like the doors
were broken. And the estate row was counted as six fields when it carries the project name as well.

## Verified

```
bash bin/gates/tests/test_areas_and_injection.sh
  → 19 passed · 0 failed
  → every case passed — the estate answers, the gate refuses, the card is true, and the line reaches the chat
```

## CHANGE LOG

- **2026-11-08** — Opened with the suite, nineteen cases green, and the two test faults recorded.
