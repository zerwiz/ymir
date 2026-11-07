# The advantage gate — every claim carries its evidence, or it does not go out

**What it is.** A small tool for a hard rule: a claim about what we are better at is deleted,
never softened, when its evidence line is empty. `bin/collab/kit/scripts/advantage-audit.sh` walks a
document of claims, finds the `**Evidence:**` line inside every section, and refuses the
page when that line is missing, a placeholder, or too thin to check.

**Who it is for.** Whoever writes a "why us" page, a proposal, or a positioning statement —
and whoever reviews it. It also settles an argument in ten seconds: the tool names the line,
so the discussion is about a fact rather than a feeling.

**What you need.** A markdown document where each claim is a `##` or `###` section, and each
one carries a line like:

```markdown
### 1. We run a real business on the software we build

**Evidence:** the operator's first full month, closed in the client-visible environment
on 2026-12-01, acceptance record linked here — not a demo, a month.
```

**The commands.**

```bash
bin/collab/kit/scripts/advantage-audit.sh <doc.md>               # every section that declares evidence
bin/collab/kit/scripts/advantage-audit.sh --strict <page.md>     # every section is a claim (a client page)
bin/collab/kit/scripts/advantage-audit.sh --check [--strict] …   # exit 1 if anything is unsupported
bin/collab/kit/scripts/advantage-audit.sh --json <doc.md>        # for a board or a report
bin/collab/kit/scripts/advantage-audit.sh --skip "Title" <doc.md> # a section that is not a claim
```

In a repository that has the collaboration kit installed, the kit's own copy is
`bin/collab/kit/scripts/advantage-audit.sh` — the kit installs that same file into the project it standardises.

**What counts as evidence.** A date, a number, a link to a record, a signed acceptance, or a
named person who will defend it. What does not: ⟨…⟩, <…>, TBD, TODO, `____`, "to be
measured", "n/a". Those are reported as `PLACEHOLDER`, which fails.

**The three verdicts.** `OK` — checkable. `NO-EVIDENCE` — no line at all. `PLACEHOLDER` or
`THIN` — a line that says nothing yet. `--check` exits 1 on any of the last three.

**Limits, stated plainly.**

- It judges the **presence and shape** of evidence, not its truth. A page can carry a date
  that is wrong; the tool will pass it and a person must catch it.
- It reads markdown sections, not prose paragraphs. A claim buried mid-paragraph is invisible
  to it.
- It is not a spell-checker for positioning. It does not know whether the advantage is
  actually rare — that is the VRIO screen in `bin/collab/kit/docs/advantage.md`.

**If it does not work.**

- *"claims: 0"* — every section was skipped as framing, or your claims are paragraphs rather
  than headings. Give each claim its own `##`/`###` heading.
- *"PLACEHOLDER" on a line you are sure is filled* — the angle brackets or `TBD` are still in
  the text, usually where a second number was meant to go.
- *Wrong section audited* — add `--skip "The exact heading"`.

**The method behind it.** `bin/collab/kit/docs/advantage.md` — the VRIO screen, the competitive set taken
from won and lost deals, the one-page teardown with every fact dated, and the cadence. The
skill that loads it is `bragi-marketing`, `assets/competitive-advantage.md`.

## CHANGE LOG

- **2026-11-06** — the page opened with the gate (plan 207).
