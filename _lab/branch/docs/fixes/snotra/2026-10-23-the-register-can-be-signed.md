## snotra · 2026-10-23 — the register can now be signed, and the agenda drives

### Files
- `bin/time/snotra/snotra-promote.{sh,py}` (new)
- `bin/time/snotra/snotra-agenda.{sh,py}` (new)
- `.agents/skills/snotra-meeting-outcomes/scripts/meeting-outcomes.py` (validator: the decision state machine)
- `bin/time/snotra/smoke.sh` (8 checks now)
- `docs/features/the-meeting-becomes-work.md`, `FEATURES.md`

### What was wrong
- **Nothing could promote a decision.** 14 decisions were `proposed` with `decided_by: null`; `snotra-approve.sh`
  locks a *letter's bytes*, not a decision, and `snotra-promote.sh` (plan 111 §5a) did not exist. So
  *"the meeting's decisions are the law"* meant law nobody had signed.
- **The record failed its own validator** — `INVALID — 14 error(s): decided_by must name one person` — because
  a decision reconstructed from a partially captured meeting honestly has no approver. Honesty read as a fault.
- **No agenda existed anywhere.** DEC-20261022-04 (grade A) says the agenda drives the meeting; nothing read or
  wrote one, so the Monday meeting had no spine.

### What now stands
- `snotra-promote.sh set <ID> accept|reject|hold --by "<name>"` — refuses without a person, validates first,
  appends to `promotions.jsonl`, reads the state back, and is idempotent (`noop` on a repeat). `--dry-run`
  shows the change without writing.
- the validator accepts `status: proposed` + `approver_pending: true` with no approver, and still refuses
  `approved`/`decided`/`rejected` without exactly one person. The record now validates:
  **VALID — 14 decisions, 3 actions, 0 warning(s)**.
- `snotra-agenda.sh` files the dated agenda card (`Agenda — 2026-10-26 09:00 · synteon/documentation`) into
  *Next Meeting Agenda*, in the room's order, every line citing its id; a second run says `already current`.
- `smoke.sh`: **8 pass · 0 skip · 0 fail**.

### What is still owed
The promotions themselves are a person's word — the door is built and dry-run proven; the 14 decisions stay
`proposed` until the Allfather (or a participant's confirmation) signs them.
