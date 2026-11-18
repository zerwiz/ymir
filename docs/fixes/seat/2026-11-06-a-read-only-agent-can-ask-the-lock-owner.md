# A read-only agent can ask the lock owner — `bin/seat/lock-ask.sh`

**Date:** 2026-11-06 · **Plan:** 206 §11 · **Law:** `RULES/44-no-agent-is-brokk.md`, `RULES/08-delivery-gate.md`

## What was wrong

A judge is read-only by charter (`edit: deny`, `write: deny`) — that stays. What it lacked was a **mouth**:
no door let it say "may I take this task" to the one live primary on the machine, and none let the owner
answer. `bin/seat/seat-wire.sh` speaks into a *peer seat's* pane and refuses self-speech; the room file is a
record, not a messenger. So a read-only agent was silent by construction, and silence reads as consent to
whoever is waiting.

## What was built

`bin/seat/lock-ask.sh` — `who · ask · list · inbox · answer · close`, on the house's own ground:

- the **lock** (`brokk.lock`, one live primary per machine) and the **arm lease** (`.arm.lease`, whose
  `state=` names the queue the arm actually drains);
- the **ask** as a file (`state/asks/<id>.jsonl`, append-only) and the **answer** in the asker's inbox;
- the **wake**: one line into the owner's queue, which the arm injects into the session between turns.

## The four laws it holds

1. **An ask is not a grant** — the answer is the owner's word, never the Allfather's; a merge still needs
   `RULES/08`.
2. **One answer per ask** — a second is refused by name, never written over the first.
3. **The owner answers, nobody else** — `answer` proves the caller descends from the live lock owner's
   process tree.
4. **A refusal names the road** — no lock, a dead owner, or a lock and arm that disagree are each reported
   as what they are.

## Verified

`bin/seat/tests/test_lock_ask.sh` — **9 ok / 0 fail**: the ask lands in the owner's queue with an id; the
owner answers and the asker reads it; a second answer is refused (exit 3); a process outside the owner's tree
is refused (`setsid --fork`); closing marks it read; a dead owner, no lock, and a disagreeing lease are each
refused with the reason. A live end-to-end pass on nidavellir wrote `ask-20261106T204447Z-0639`, the owner
answered it, and `inbox forseti` showed the answer.

## CHANGE LOG

- **2026-11-06** — written with the doors it describes (plan 206): the review loop joined to the
  spine, the read-only agent's mouth, the resolver that replaced five hardcoded model ids, and the
  operator-only mail door.

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: a dev machine. The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).
