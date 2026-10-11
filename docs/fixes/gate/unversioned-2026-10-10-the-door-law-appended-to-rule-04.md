## gate · unversioned · 2026-10-10 — the door law, appended to Rule 04

### What

Two follow-ups to `cron-guard` (PR #309), after the Allfather asked *"are all
needed scripts coming from the ymir repo — the door users get? the home is
personal."*

- **`RULES/04-hoard.md`** — a new entry, appended under Law 06: the repo is the
  **door** users install and must ship every script the runtime needs; `$YMIR_HOME`
  is **data**, not a delivery channel; Nornir runs jobs from the **repo root**, so a
  cron `bin/…` must resolve to a shipped script (schedules may differ per user and
  seat, commands may not); secrets stay in the hoard (`secret-guard --all` is clean).
- **`bin/gates/guards/cron-guard.sh`** — the header and the failure help now say *why*:
  jobs run from the repo root, so a home-only `bin/…` can never resolve.

### Verified

- `cron-guard check` → `"none"`, exit 0.
- `RULES/04-hoard.md` appended, never rewritten.

### Files

- `RULES/04-hoard.md`
- `bin/gates/guards/cron-guard.sh`
