## gates · unversioned · 2026-10-22 — the operator's setup never ships: tenant-guard, and the first slice

### What

- **`bin/gates/guards/tenant-guard.sh`** — a new ward in `guards.sh`. The operator's own terms (seat names,
  addresses, domains, houses, clients, people, private paths) are read from the **hoard**
  (`$YMIR_HOME/config/tenant-terms.txt`), never from the repo; the repo ships only a shape
  (`config/tenant-terms.example.txt`). A baseline (`.agents/tenant-baseline.json`) records how many hits each
  tracked file already carries, so the ward **refuses new leakage today** without demanding the backlog be paid
  at once: a file may keep its count, a file that gains one fails, a new file with one fails.
- **`bin/gates/guards/classification-guard.sh`** — Rule 29's structural ward: no suite space above class 2,
  the vault never projected, and the projecting code must name a person or a place.
- **`RULES/29-what-goes-where.md`** — five classes (public · team · client-confidential · NDA/contracted · the
  vault), the boundary law, and the test: *name who would see it tomorrow; if the answer is "whoever joins
  next", it is in the wrong place.*
- **First remediation slice** (plan 106, moves M1–M3): `apps/hlidskjalf/server/index.ts` no longer carries a
  `DEFAULT_SERVER_SEATS` naming two real servers and an ssh alias — it reads `YMIR_CRON_SERVER_SEATS` and
  SKIPs cleanly when unset; the Galdr assets `thing-assembly-hall.md` and `snotra-meeting-ear.md` name roles
  instead of the host, the public door and the plans path.

### Why

The Allfather: *"thing like this can never be published with ymir … this is my setup specific."* Measured in
the tracked tree: **287 files carried 738 hits** of the operator's identifiers before the terms were tightened.
The first count was itself wrong — `heimdall` is a figure of the house and `omarchy` a public operating system,
so both were removed from the terms; the true figure is **around 340 hits in ~150 files**.

### Verified

- `tenant-guard` passes on the current tree and **fails** on a deliberately added operator name.
- `classification-guard` passes; the shipped space map claims no ceiling above 2 and the vault is
  `never_projected`.
- the baseline is tracked (`.agents/tenant-baseline.json`) and fell **343 → 325** with this slice.
- `guards.sh` reports both new wards PASS.

### Not verified / not done

- **The backlog is not paid.** ~325 hits remain across ~148 files; the plan's phases 1–3 (scripts, docs, fleet)
  are not finished.
- **The fleet overlay is not built**: per-seat terms files (`tenant-terms.d/<seat>.txt`) and the pre-push
  wiring on every seat are planned, not shipped.
- **`AGENTS.md` still names hosts and houses** (8 hits) — the largest single document to generalise, and not
  attempted here.
