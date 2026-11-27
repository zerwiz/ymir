# 57 — A broken function is reported in the same breath
# Rule 57 — A broken function is reported in the same breath

> Renumbered from `50` when this rule was gathered on 2026-11-18: main had taken `50` for
> *the home is pulled before and pushed after*. The law is unchanged; only its number is new, and
> `RULES/README.md` carries the row.

**Added 2026-11-09** at the Allfather's word: *"make a rule for allways report broken functions. so we
can make improvements."*

## The law

```
law[5]{rule,why}:
  "WHOEVER FINDS A BROKEN FUNCTION REPORTS IT IN THE SAME PASS — not later, not in a note to self, not as a workaround that quietly succeeds.","a broken thing that is worked around becomes invisible, and invisible faults are the only ones that recur for weeks (the pane door: built 2026-11-08, never called, silent until 2026-11-09)"
  "A REPORT NAMES THE FUNCTION, THE COMMAND THAT SHOWS IT BROKEN, AND ITS OUTPUT — never an adjective.","'the mail is flaky' cannot be fixed; `bin/notify/mail.sh --check` exiting 1 with `no account row` can"
  "A WORKAROUND IS A REPORT WITH A DEBT: it is allowed only if the report is made first, and the debt names what closes it.","otherwise the workaround becomes the system and the fault becomes folklore"
  "A BROKEN FUNCTION IS AN INCIDENT WHEN IT CARRIED SOMETHING THAT MATTERED.","a door that drops a message is not a cosmetic bug; it is the same class as a dropped payment"
  "THE REPORT GOES WHERE IT IS COUNTED — the broken-function register — so a repeat is visible as a count, not a memory.","three recurrences of one class of fault is what earns a RULE; without a count nobody can see the third"
```

## The register

`hodd/state/broken.md` (home, private) — append-only, one line per finding:

```
broken[5]{date,function,command that shows it,state,closes when}:
  "2026-11-09","bin/agents/eindri-notify.sh","--status printed pane: NOT FOUND","mended (d428511f)","the same command prints a pane, and a line arrives"
  "2026-11-09","review-seat.service","systemctl --user status → 3/Bad file descriptor","PR open (#614)","the unit is active and the refusal names its reason"
```

Three columns do the work: **the command** (so anyone can reproduce), **the state** (`open` · `mended
<sha>` · `declared` when it is deliberately absent), and **what closes it** (the proof, never a promise).

## Who must obey it

Every agent, every loop, every door-holder — and the loops especially, because they run unattended: the
update loop (plan 233 §10) reports the mends it could not make, the channels audit (plan 234 P4) reports
every RED row, and Eir reports every surface it refuses to mend. **Silence is only legal when the function
answered.**

## Enforcement

- A pass that found a broken function and did not report it is a violation of this rule, whatever else it
  achieved.
- `bin/seat/broken.sh add|list|close` is the door (the register is data; the door is how it is written).
- The weekly self-improvement pass (plan 235) reads the register: anything `open` with no owner is escalated
  to him, and a class that has recurred three times becomes a RULE.

## Why

This house lost a night to functions that were broken and silent: a door nobody called, a notify that could
not resolve a pane, a deploy script verifying a build nobody served, a poller that failed 507 times without
a voice, a judge answering from a stale base. None of them were hard to fix. All of them were hard to SEE.
The rule is cheap; the silence was not.

## CHANGE LOG

- 2026-11-18 — gathered from the pane-door branch and renumbered from 50 (main took 50 for the home rule); the law is unchanged.
