# The handoff has a door — the link the documentation design named broken

**Date:** 2026-11-01 · **Component:** agents · **Status:** door landed; the shelf has its first real report

## The fault

The documentation design (2026-11-01) counted every kind of page the house keeps and found exactly one
link in the chain empty: **handoffs — 0 files**, where the design says one file per errand. The errand brief
already carried the shelf (`$STATE/eindri-reports/<id>.md`); nothing wrote it. A contract with no door is a
hope, and the cost is that every session re-derives what the last one knew.

## What landed

`bin/agents/report.sh` — the **one** handoff door:

```
report.sh write <id> --state done|blocked|needs-decision \
        --changed "<files/systems>" --verified "<command → result>" \
        --not-verified "<what and why>" --next "<one imperative sentence>" \
        [--pointers "plan:147 · card:INV-3 · docs/fixes/…"] [--actor <name>]
report.sh show <id> · list · missing <id>… · check <id>
```

- **The seven fields are required, not suggested.** `--changed`, `--verified` and `--next` refuse to be
  empty, and the state must be one of three. "Tested" is not a value: `--verified` takes the command and
  what it printed.
- **Append-only** (Rule 06): a second write adds a dated section, it never edits the first.
- **`check <id>`** fails when a field is missing, and **`missing <id>…`** answers the question the daily
  line and the wake sweep both need: which errands stopped without a handoff.

`bin/agents/erindi-brief.sh` now carries the exact command in the brief it scaffolds, so the worker is told
the door rather than the path.

## Proof

```
$ bin/agents/report.sh write ses-2026-11-01 --state done --changed "…" --verified "…" --next "…"
report[1]{id,file,state}:
  "ses-2026-11-01","/home/heimdall/.local/state/ymir/eindri-reports/ses-2026-11-01.md","done"

$ bin/agents/report.sh check ses-2026-11-01
report: ses-2026-11-01 complete
```

The first report on the shelf is the day's own: what changed, what was verified with the numbers, what was
**not** verified (the browser-kill fix is unproven until a signed death; the outbound-gate suite is still
red with eight failures), and the next step.

## Owed

- **The daily line** is the other broken link: `bin/records/daily-log.sh add` exists, but nothing writes the
  day from the cards and the reports. That is the next door.
- A gate that refuses to close an errand (seat or card) whose handoff is missing — the door exists now, so
  the check can be enforced instead of hoped for.
