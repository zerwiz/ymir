## time · 2026-11-17 — the digest prints the ranks

### What was wrong

The session head named the lock and the helm, and never said which **rank** the seat it was briefing actually held. A seat that does not know whether it holds the machine arm, a project's lease, or nothing at all either overreaches or sits silent.

### What the door does now

The head's HELM section prints one more line, from the one door that owns the answer (`bin/voice/arm-lease.sh ranks --line`):

```
rank: this seat holds a PROJECT LEASE on heimdall — lease 3, scope ymir, 2 hand(s), 58m left · arm hand none
rank: this seat HOLDS THE MACHINE ARM on heimdall (pid 610674, transcript:cwd 0s) · leases: 1 · no crown row on this machine
rank: read-only — the machine arm's hand (pid 1407) cannot speak: … It may still ASK: bin/seat/lock-ask.sh ask "<question>"
```

Three ranks, one lock each: the machine arm (the right to act on this machine), a project orchestrator (a **lease**'s holder — hands, not sovereignty), and the crown (one for the fleet, whose row is read here and whose service is not built by this change).

A seat with **no** rank keeps its one door and the line says so: a read-only agent may always **ask** the arm holder for work. A read-only page prints the same line — a page is not a hand on the helm, but it is a reader that must know whose hand is on it.

### Files

- `bin/time/saga-session-start.sh` (`head_rank`, called from `SEC_LOCK` and from the page branch)
- `bin/time/tests/test_saga_rank.sh` (new)

## CHANGE LOG

- **2026-11-17** — Opened: the head prints the rank this seat holds, who holds what, and the asking door for a seat with none.
