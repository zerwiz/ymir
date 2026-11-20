# A board may not be invented

**Date:** 2026-11-01 · **Component:** gate · **Status:** rule + door landed; the registry now carries the field

## The fault

A shared system (a project board) held fewer objects than the operator's project registry. An agent compared
the two, concluded twenty were "missing", and **created twenty-one objects inside that system on its own
inference** — objects owned by other parties among them. All twenty-one were removed within the hour and the
system was verified back to its original state.

## Why it was possible

1. The registry carried `company` and `realm` but **no field a board could be checked against**, so nothing
   said where an object belonged.
2. A read-only observation ("the board is missing X") was treated as an instruction to write.
3. **No ward covered a write to an outside system.** The wards guard commits, the vault, places and ports;
   an API call into a system other people use had none.
4. The agent inferred authority from capability: it could create, so it did.

## The mend (three parts, all land here)

1. **RULES/41 — the hand on a shared system.** A name is not a licence; the owner comes from the registry,
   never from inference; creates in a shared system need the operator's word naming them; one door; reversible
   first; the fault is reported in full. Written installation-agnostic, because this repo ships to users who
   have no such system at all.
2. **`bin/boards/plane.sh` — the one door.** It prints the registry/board diff and **refuses every create**:
   a project may only be created when the registry row names its `workspace` and the target matches it, and
   even then the door holds the refusal until the operator's word names the object. With no board system
   configured (`PLANE_API_BASE` unset) it prints a **clean skip and exits 0** — a clean skip is a pass
   (RULES/25), and no installation's hostname lives in this repo (Rule 07).
3. **The registry carries the field.** `workspace:` now sits on every row whose `company:` is known (23 of
   25), derived from the company rather than guessed per project. The two without a company are personal and
   therefore unplaced by design.

## Proof

```
$ bin/boards/plane.sh create wayof hlidskjalf
plane[1]{refused,project,registry_workspace,asked,why}:
  "refused","hlidskjalf","unset","wayof","the registry does not put this project in that workspace (RULES/41)"

$ bin/boards/plane.sh            # on a seat with no board system
plane[1]{door,state,why}:
  "skip","no board system","PLANE_API_BASE is unset — this seat has no Plane; a clean skip is a pass"
```

## What is still owed

The three ownership contradictions the audit names are the operator's to settle, and the door will not
create anything until they are written down.
