## snotra · 2026-10-23 — no strays, whole letters, and the chair

### Files
- `bin/time/snotra/snotra-layout.{sh,py}` (new — the folder standard, enforced)
- `bin/time/snotra/snotra-letter.py` (the letter names only what exists; the draft carries it)
- `bin/time/snotra/snotra-agenda.py` (the chair is named, with the lead time)
- `bin/time/snotra/smoke.sh` (9 checks; honest skips)

### What was wrong
- **A meeting folder held four generations of the same letter** (`email.md`, `framework-email.md`,
  `feedback-email.md`, the engine's `followup-email.md`) and a `TEST-REPORT.md`. The Allfather's word:
  *"no strays"*. A folder that accepts a fifth hand-built letter has no standard.
- **The letters named attachments they did not carry.** Three drafts went out with `record.pdf`,
  `decisions.md`, `actions.md` promised and **nothing attached** — the same fault as a card that says it
  was filed when it was not.
- **The chair was nowhere in the record or the shape.** DEC-04 says the agenda is sent 1–2 days ahead; who
  sends it was undeclared.

### What now stands
- `snotra-layout.sh check|apply` — the top level holds only the source, the rendered set, the shelves
  (`briefs/ letters/ evidence/`), the manifest (`README.md`, `PROVENANCE.md`) and the named state;
  everything else is a **stray**, and `apply` retires it to `evidence/hand-built/` with a note in
  `PROVENANCE.md` — never deletes (Rule 11). Measured: the 20 October folder went 7 strays → **0**.
- **The letter now names only what exists and the draft attaches exactly those files** — measured:
  `attachments:5` per draft (`record.pdf · decisions.md · actions.md · minutes.md · questions.md`).
- **`chair: Reygan Assareh`** is recorded in both meetings' records and in the place profile; the agenda
  card reads *"Chair: **Reygan Assareh** — sent 2 days ahead"*.
- The 20 October meeting now carries the same standard as the newest one: **35 cards** projected and
  verified, four letters rendered, an agenda card filed, a README and a PROVENANCE naming its source
  (a third-party recorder export — no microphone of ours ever heard it).
- `smoke.sh`: the 22 Oct folder **9 pass · 0 skip · 0 fail**; the 20 Oct folder **6 pass · 2 skip · 0 fail**
  (the skips name the reason: no Meet link, so no bot recording can exist).
