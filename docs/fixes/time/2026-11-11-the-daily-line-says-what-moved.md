# time · 2026-11-11 — the daily line says what moved, and may run several times a day

## Files
- `bin/time/daily_moved.py` (new) · `bin/time/daily-line.sh` (third section; no entry when nothing is new) ·
  `docs/features/the-daily-log.md` (new) · catalogue entry 02-110.

## Why
The operator: *"make so Ymir home always is updating the daily log."* The day's log held seven typed lines after a full
day of work: `daily-line.sh` was not in the home's cron, and it read only worker handoffs and Plane cards.

## What changed
A third section reads the record — home commits, project commits on this seat, mail sent, meetings recorded — and keeps
a per-day seen-ledger in the state dir, so repeated runs add only what is new. A run with no handoffs, no cards and
nothing new writes nothing. The home resolves through `bin/vault/hoard-lib.sh` (RULES/07).

## Proof
`python3 bin/time/daily_moved.py --self-test` → ok. `bin/time/daily-line.sh --dry-run` on the operator's home listed
the day's home commits (91), the Ymir and project commits, and the meetings recorded.

## CHANGE LOG

- **2026-11-11** — written with the change (nidavellir, plan 252).

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: a dev machine. The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).
