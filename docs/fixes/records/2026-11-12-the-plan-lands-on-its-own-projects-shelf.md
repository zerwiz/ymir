# The plan lands on its own project's shelf

**Component:** records (`bin/records/plan.sh`, the `ymir_plan` MCP door) · **Date:** 2026-11-12

## What was wrong

`plan.sh` resolved the project's shelf at the top of the script, from the default realm and project, before it read
`--realm` and `--project`. So `plan.sh new <slug> --title T --realm R --project P` filed the plan in the default
project's ledger, numbered after its plans. Three plans for three other projects landed as 280–282 of another
project's ledger. The MCP door passes the same flags, so it filed them wrongly too.

The same top-level resolution exited when the home had no project of the default name. That is every user's home but
one, so the tool failed even for company and personal plans.

## The fix

- The shelf is resolved after the arguments are read, in `resolve_project_ledger`.
- A project is found by its folder in any realm (`projects/` or `workspace/`). A name in two realms is refused with
  both named; a realm given with `--realm` is a fact and is never searched past; an unknown project is refused.
- A project folder with no `plans/` is refused unless `--new-shelf` opens it, with its index.
- `plan.sh shelves` lists every realm and project folder and whether it has a shelf.
- `ymir_plan` (MCP) gains `shelves` and `new_shelf`, passes realm and project for every action, and no longer
  defaults the project to one name.

## Proof

`tests/test_plan_finds_the_shelf.sh` — 14 cases in a throwaway home, registered in `tests/run.sh`.

## CHANGE LOG

- 2026-11-12 — review-mend: added missing heading for #717
