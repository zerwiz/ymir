## seat · 2026-11-11 — the finished agent is what no one closes

### The fault

Measured on heimdall, 2026-11-11 21:20: 117 errand records stand in `state/`, 111 of
them carry a terminal last line (done · failed · needs-decision · paused), 33 herdr
panes still stand, 21 of them hold live agents — and `seat-reap --sweep` closed zero.
The digest said `seat-reap[1]{closed,kept,refused}: 0,19,0`, a count with no reason, and
the hall filled with finished Eindri seats all night.

The chain is six links, each verifiable:

1. the arm's close hand calls `seat-reap.sh <id>` on a terminal status;
2. the sweep tests for an agent FIRST — `agent_in_workspace → keep`, with the words
   `a live agent stands here — never touched`;
3. a finished worker is still a live agent: a pi or claude TUI that finished sits at an
   idle prompt, its process alive, so it reads as busy;
4. nothing distinguishes working from finished — `agent_status: idle` exists and is
   unread by a close hand that asks only `is there an agent`;
5. nothing ever exits a finished agent — `seats.sh close` refuses a live agent,
   `ymir_close_dead` closes only owners that are gone;
6. the refusal is swallowed — `eindri-arm.sh` and `eindri-dispatch.sh` both write the
   close hand's answer to `>/dev/null 2>&1`, so the arm is never told it was refused.

The fault is a refusal written to protect real work, in a place that could not tell real
work from a finished seat.

### The fix

`bin/seat/seat-reap.sh` now asks the discriminator for a named verdict instead of a
blanket keep, reading the agent's STATE through the one reader (`bin/seat/herdr-agents.py`),
never re-parsed:

- **working** — the agent reports `working` → KEEP, never touched, the reason says so,
  and a working sample resets the idle grace;
- **finished** — the record is TERMINAL and the agent has reported `idle` continuously
  for `SEAT_REAP_IDLE_GRACE` (default 600 s, stamped in `state/<id>.idle-since`) → RETIRE;
- **undecided** — no record, a fresh record, a `needs-decision` record, or a flapping
  state → KEEP with the reason named. `needs-decision` is deliberately NOT terminal for
  this purpose: a seat waiting on the Allfather survives a sweep whatever its age.

The retire verb (S2) is the missing hand — end the agent, THEN close the seat, escalating
in order and never starting with a kill: (a) the harness's own exit (`/quit` for pi and
codex, `/exit` for claude · opencode · cursor · grok · kimi · muse, per
`.agents/skills/hamr-adapters/`); (b) a bounded wait (default 20 s) for the pane to become
agentless; (c) the existing close doors (`seats.sh close`, `herdr workspace close`) behind
the dirty/unpushed worktree guard; (d) only then a TERM to the agent's own pid, recorded.
One runes line per retirement: id, pane, verdict, reason, escalation step.

The reason travels (S3): the arm and dispatch no longer swallow the close hand — a refusal
prints one line, and a seat kept three sweeps running raises a `check:` line into the wake
queue. The digest prints the verdict breakdown (`closed · retired · kept`, with
`finished-idle` and `working` sub-counts) instead of a bare count.

The orphan panes (S4) — bare shells that are not errands, the Allfather's own working
directories — are named in their own `orphans[]` row by `seats.sh brief`, and
`seat-reap.sh --close-pane <id>` is the ONLY door that closes one. A sweep never touches
them.

### Verified

```
$ bash bin/seat/tests/test_seat_reap.sh
seat reap: 70 ok / 0 fail
```

The five discriminator cases are green: working kept, finished retired (workspace closed,
idle stamp cleared), needs-decision kept, dirty worktree refused, grace-not-yet-elapsed
kept. The live acceptance run on heimdall retired the finished-idle backlog and left the
working seats standing — including the worker building this change, which was never
touched while it worked.

## CHANGE LOG

- **2026-11-11** — Carved: the discriminator (working / finished / undecided) and the retire verb land in
  `bin/seat/seat-reap.sh`; the arm and dispatch stop swallowing the close hand; the digest prints the
  verdict breakdown; orphan panes are named and closable only by `--close-pane`; the seatreap surface
  joins Eir; five discriminator cases green (70 assertions).
