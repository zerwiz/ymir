# plans/tickets/ — the units of work under a validated plan

A **plan** (`plans/<PREFIX>-NNN-*.md`) says what is built and why, and is validated by its area owner before any
implementation. A **ticket** is one unit of work under a validated plan. **Tickets are not validated plans**, and
there can be several tickets on one plan (`RULES/19`).

```
plans/tickets/
  README.md                          this file
  TEMPLATE.md                        the shape of a ticket
  <PREFIX>-<plan>-T<nn>-<slug>.md    one file per ticket
```

`<PREFIX>` is the project's own plan prefix — the one its plans already use, or the line in `plans/.prefix`.

## Naming

`<PREFIX>-<plan>-T<nn>-<slug>.md`, for example `ACME-028-T03-composite-foreign-keys.md`: the plan number, a
two-digit ticket number counted within that plan, and a short slug.

## Header

`ticket`, `plan`, `title`, `status`, `assignee`, `priority`, `created`, `updated`, `pr_url`.

Ticket status: `Open → In Progress → In Review → Done`, plus `Blocked` and `Cancelled`.

## The rule that governs a ticket

**A ticket's plan must be Validated (or later) before the ticket moves past Open.** Until then the ticket is
only proposed, as a row under `## Proposed tickets` in the plan itself. No ticket file is created for a plan that
is not Validated. A pull request that changes code names its ticket in its description.

## Checking

```bash
python3 scripts/status.py tickets
python3 scripts/status.py tickets --plan <PREFIX>-028
python3 scripts/status.py --check
```

The report shows the ticket count and `validated_by` for every plan, and flags any ticket past Open whose plan is
not Validated or later.

## References

- `RULES/19-plan-validate-execute.md` · `docs/headers.md` · `scripts/status.py`

## CHANGE LOG

- **2026-11-11** — written by the errand that shipped it; CHANGE LOG section added when the branch was merged for one PR.
