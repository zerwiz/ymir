## docs · 2026-10-21 — the front door is long on purpose, and now it is long with the right things

### Why
The Allfather asked why a dated day-summary ("What was wrought — 2026-09-14") sat in the README, then
told me what the front door is actually for: *"the readme is for users and clients. it should tell them
how to use and set up the system. they have no access to the plans, and should not have dates like
this."* Then, when I proposed cutting 1,308 lines down to 350, he said the decisive thing: **"IT
SHOULD BE LONG."**

Both are true at once, and that is the design: **long, and about the reader.** A client wants the whole
of it — install on every platform, what each figure does, what the promise about their data is, what
leaves the machine and what never does. A client does not want the plan ledger, the dates, the agent
runbooks, or a duplicate of the same section in two registers.

### Fix
- **The day-summary moved out** — verbatim — to `docs/fixes/docs/2026-09-14-one-day-one-loom.md`,
  under Rule 11 (move, never delete), and replaced by a five-line "Read more" that says where history
  lives.
- **A contents block** at the top: a 1,370-line document without one is a swamp.
- **The duplicated sections are labelled, not deleted.** "Agents", "Skills" and "System Map" became
  *the same ground as reference* — a table next to the prose — so a reader can choose to read or to
  look, and two registers stop contradicting each other.
- **The fleet chapter is for a user with two machines.** Its title lost its date and became "Running
  Ymir on more than one machine"; its opening now says plainly that a single box is a fleet of one and
  needs no network, and the plan reference is gone.
- **A glossary** — thirty-five names, one line each — because every part of Ymir is named for the figure
  whose job it does, and a client should not have to reverse-engineer a pantheon to read a README.

### What still has to leave, and is named rather than hidden
The operation runbook inside the README (roles · topology · MCP by role · crons by role · models ·
workers · version) is genuinely useful and genuinely not a client's business; it belongs in
`docs/operations/`. The next pass moves it and leaves a pointer.

### Verified
`docs-claims-guard` → every claim resolves across 124 pages. Lines: 1,308 → 1,370 (longer, as asked).

### Files
- `README.md`
- `docs/fixes/docs/2026-09-14-one-day-one-loom.md` (new — the moved day-summary)
