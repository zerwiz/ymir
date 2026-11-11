# 52 — No agent runs unowned

**Added 2026-11-09** at the Allfather's word: *"we cannot have any rogue agents running around"* — and, the
same night: *"the gna hold must always check and know how many agents are running on the machine."*

## The law

```
law[5]{rule,why}:
  "EVERY RUNNING AGENT IS A SEAT THE ROSTER NAMES. A process that reasons, dispatches or writes — an errand in a worktree, a reviewer, a voice, a cron-spawned worker — is accounted for by name and pane, or it is a finding.","an agent nobody counted is an agent nobody can stop, and it acts with the machine's full authority"
  "THE ARM COUNTS ON EVERY CYCLE, ALWAYS. Not on request, not when something looks wrong: the count is the first act of the cycle, and the number goes into the arm's own state.","the question 'how many agents are running' must never be answerable only by asking — a fleet that cannot count itself cannot say it is well"
  "A SEAT WHOSE ERRAND IS OVER IS CLOSED, BY NAME, WITH ITS REASON. An idle pane is a loaded hand: it can be spoken to, and it can act.","three idle seats outlived their errands on the heart in one night, and one of them read as a second reviewer"
  "ONE ROLE, ONE LIVE SEAT — unless a second is declared with its reason. A duplicate role is worse than a wrong verdict: it is an unaccountable one, because a name that fits two panes answers for neither.","'why do you have 2 reviewers' is the question this rule exists to make impossible"
  "AN AGENT THAT CANNOT NAME ITS OWNER STOPS. A process with no errand, no seat and no record halts and reports; it never continues 'just to finish'.","a rogue agent is usually not malicious — it is a leftover with full permissions"
```

## What counts as an agent

Anything that can act without a human keystroke: an errand in a worktree, the reviewer, a voice seat (Rödd),
an assistant (Skírnir, Hermes), a cron-spawned worker, a supervision loop that dispatches. A server that only
serves is a SERVICE (Rule 24, the register) and is judged by plan 235's hosting duty — not by this rule.

## The door

`bin/seat/roster.sh` — one row per seat: `pane · role · state · worktree · branch · errand · age`, and one
line the arm can say without thinking:

```
roster: 11 seats · 1 primary · 1 reviewer · 5 building · 3 idle · 1 stale (repair-556, 2 days)
```

It reads herdr (what the harness knows) and `ps` (what the kernel knows), and a disagreement between the two is
a finding with both sides printed.

## Enforcement

- `bin/seat/roster.sh --check` exits non-zero on: a seat with no errand and no terminal status, a role with two
  live seats, a process that is an agent and not a seat, or a roster file older than the arm's last cycle.
- The arm runs it first in every cycle (plan 233 §12a) and opens an incident for an UNOWNED agent.
- A closure is a Rune: who closed which seat, why, and what it had done.
