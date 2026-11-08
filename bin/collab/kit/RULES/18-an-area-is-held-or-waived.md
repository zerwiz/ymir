# 18 — An area is held, waived or never (an area is never silently nobody's)

**The law.** A project's work is divided into areas (the eighteen in `areas/canon.yaml`). Every area
is answered in exactly one of four ways, in its own file under `areas/`:

- **held** — a named keeper, and at least one piece of evidence that closes it
- **waived** — a named person waived it, with a reason and an end date
- **na** — it does not apply to this project, with a reason
- **unheld** — nobody has taken it. Honest, legal in the file, and refused the moment a change
  touches the area's `may_write`.

**Why.** An area nobody held looks exactly like an area that was finished. This is the cheapest lie
in software: nobody owns multi-tenancy, so nobody says it was never asked. The declaration makes the
silence visible, and the gate makes it cost something.

**What it refuses.** A push that changes a path claimed by an area that is `unheld`, or whose
declaration cannot be read. It names the area and the file — never the author — and it prints the one
command that fixes it.

**What it does not do.** It does not judge the quality of the evidence, decide what a project's areas
are beyond the canon, or require every area to be held. A repository that has not adopted the shelf
prints a clean skip; a skip is a pass, and a silent green is a lie.

**A waiver is a decision, not a silence.** `waived_by`, `why` and `until` are all required. A waiver
with no name is a disappearance.

**Correction, never erasure.** An area that stops being held is set back to `unheld` with a dated
line saying why, or waived with its end date. The file is the record of what the project answered
and when — so it is appended to, not rewritten into whatever is convenient today.

## CHANGE LOG

- **2026-11-08** — written on the branch that carried it; this section was added when the
  consolidated pull request asked for it (RULES/06). Appended, never a rewrite.
