# 19 — Plan, validate, then execute

**Added 2026-11-11** at the operator's word: *"plan, validate plan, then execute. no implementations before
validations are proven"* and *"tickets are not validated plans. there can be several tickets on one plan."*

## The rule

```
law[5]{rule,why}:
  "**a plan states what is built, why, the acceptance criteria and the proof**","a plan that cannot say how it will be proven is a wish, and a wish cannot be validated"
  "**a plan is validated before any implementation**: accepted by the area owner and recorded in its header as `validated_by` and `validated_on`","building before the owner has agreed is how the wrong thing gets built well"
  "**the validator is the area owner named in the project's `AGENTS.md`**; when a plan crosses two areas, both owners validate it","the person accountable for the outcome is the one who accepts the plan; if `AGENTS.md` names no owner for the area, the plan cannot be validated until it does"
  "**a ticket is one unit of work under a validated plan, never a plan itself**; a plan has one or more tickets","a ticket is how the work is divided and tracked; it carries no decision that a plan has not already had accepted"
  "**no implementation before validation**: no code change for a plan that is not `Validated` or later, and a pull request that changes code names its ticket, whose plan must be Validated","the cheapest place to find a wrong design is before it is code"
```

## The lifecycle of a plan

`Proposed → In Review → Validated → In Progress → Done`, plus `Rejected` and `Superseded`.

- **Proposed** — written, nobody has been asked yet.
- **In Review** — the area owner has been asked and is reading it.
- **Validated** — accepted. `validated_by` and `validated_on` are filled in the plan's header. Only now may
  tickets move past Open and code change.
- **In Progress** — at least one ticket is being worked.
- **Done** — every ticket is Done and the acceptance criteria are proven.
- **Rejected** / **Superseded** — kept, never deleted; a superseded plan names its successor.

`Backlog`, the status a project may have used before adopting this rule, is still read but is reported as a
warning.

## What it allows

**Documentation and planning are allowed at any time**: documents, plans, and *proposed* tickets (a list inside
the plan, under `## Proposed tickets`) need no validation. Only code, configuration and migrations wait.

## What it refuses

- a pull request that changes code or configuration and names no ticket;
- a pull request whose ticket's plan is not Validated or later;
- a ticket file created, or moved past Open, while its plan is not Validated.

## How it is checked

```bash
python3 scripts/status.py tickets          # every ticket, and a "plan not validated" flag
python3 scripts/status.py --check          # fails on a malformed header, or on an unvalidated plan with working tickets
python3 scripts/status.py plans --plan <PREFIX>-028
```

`scripts/status.py` reads the plans' own prefix from `plans/.prefix` (or from the plan file names), so it
needs no edit per project. It is the check today; reading a pull request body for its ticket is a guard a
project may add. **A green status report is not validation** — validation is a named person's acceptance,
recorded in the header.

## CHANGE LOG

- **2026-11-11** — Written for any project, with the tickets shelf (`plans/tickets/`) it governs.

## References

- `RULES/15-commits-leave-by-pull-request.md`, `RULES/18-an-area-is-held-or-waived.md`
- `plans/tickets/README.md`, `scripts/status.py`, `docs/headers.md`
- the project's `AGENTS.md` — where the area owners are named
