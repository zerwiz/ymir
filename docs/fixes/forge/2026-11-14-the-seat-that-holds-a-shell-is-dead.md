# Fix — the seat that holds a shell

**Component.** `forge` — the reviewer's seat (`bin/forge/review-seat.sh`), its keeper timer, and the
one reader of herdr's JSON (`bin/seat/herdr-agents.py`).

**What was wrong.** Four faults, measured on the heart on 2026-11-14, and one of them was old.

1. **The refusal had no voice left.** `refuse()` printed to file descriptor 3, which nothing in the
   script or in the unit that runs it ever opens. Under the keeper timer the journal recorded
   `line 60: 3: Bad file descriptor` five times a minute instead of the reason it refused. The exit
   code stayed 3, so the shape of the refusal survived and its cause did not. This was fixed on
   `main` on 2026-11-09 (one character, `>&3` → `>&2`); it is fenced by a test now so it cannot
   come back.
2. **A pane was counted as the seat.** `seat_pane()` matched `herdr agent list` rows on the
   directory alone. When pi died at start, the pane fell back to a bare shell — and a herdr still
   reports that pane, with an empty kind and the state `unknown`. So the keeper saw "the seat is
   standing" forever: nothing re-raised it, and the review watch prompted a shell every ten minutes.
3. **The helm refused the whole seat.** `ensure --primary` exited 3 whenever a live primary held the
   lock. `--primary` exists for a machine whose lock names a dead pid; on a machine with a live
   primary it refused *every* run, so the machine ended up with **no reviewer at all**. Only the
   helm may be refused, never the seat.
4. **"agent start failed" hid the reason.** When pi died at startup — the measured cause is two
   extension sets registering the same tool names (`RULES/13`) — the keeper said only that the agent
   start failed. The pane was holding the actual line, and the keeper never read it.

**What was done.**

- **Presence is two questions, not one.** `seat_candidates()` asks *where the panes are*
  (`herdr pane list`, every pane with or without an agent, falling back to `agent list` on a herdr
  that reports no pane list). `pane_verdict()` then asks *whether an agent is standing there*:
  `live`, `dead`, or `unsure`. Only `dead` may close a pane, and `dead` is never a guess — it is
  herdr answering `agent_not_found` plainly, or reporting an agent with no kind and no state.
- **`ensure` reaps a dead seat and says so.** A pane whose cwd is the review clone and which holds
  no agent is closed, one line is printed naming the pane, and a fresh agent is raised in the same
  pass. The pane is left alone when herdr places it in **another** workspace: that pane is somebody
  else's, and the house does not close what it did not open (`RULES/41`).
- **`--primary` refuses the helm only.** With a live primary holding the lock the seat is raised as
  a plain seat, with its own machine state, and the decision is printed:
  `helm[2]{owner,decision}` names the pid and says the helm was not taken. With no live owner it
  takes the helm exactly as before.
- **The keeper reports the pane's own line.** `herdr agent start`'s stderr is captured and its first
  non-empty line is named. If the agent starts and then dies, the pane is read
  (`herdr pane read --lines 80`) and its first line that looks like an error is reported; failing
  that, its last non-empty line. `agent start failed` is gone: the seat now says what went wrong.
- **`status` stops calling a shell a seat.** A pane at the clone with no agent is reported as
  `not the seat — that pane holds no agent`, with the pane named.

**One reader, not six.** The five new JSON questions would have been five more inline parsers of the
same herdr shapes in a script that already had three. `bin/seat/herdr-agents.py` — the house's ONE
reader of herdr's JSON, which exists because a second parser is how a pane came to be read as an
agent — gained the faces this needs: `--panes [--cwd P]`, `--verdict --pane P` (the verdict and
herdr's own state, from one call), `--room --label L`, and `--pane-room --pane P`. Every existing
face is unchanged. One measurement is written into that reader because it fooled a first draft:
`herdr agent get` answers a pane with no agent on **stderr** with exit 1, and a live agent on stdout
with exit 0, so a reader watching only stdout calls every empty pane `unsure` and never reaps a
seat.

**How it is proved.** `bin/forge/tests/test_review_seat_keeper.sh`, twenty-seven assertions, run in
CI as the gate `review-seat-keeper`. It is hermetic by construction: `herdr` is a temp file the test
writes, the home and the state are a throwaway under `$TMPDIR`, and the machine lock is read under
its own `XDG_STATE_HOME`, so the real herdr server, home, lock and every live workspace are
untouched. It plants:

- a refusal with **fd 3 closed**, which must still reach stderr and still exit 3, and must never say
  `Bad file descriptor`;
- an agentless pane in the `review` room, which must be **closed**, said out loud, and replaced by a
  fresh agent — and the same through `agent list` alone, for an older herdr with no pane list;
- a live primary holding the lock, where `ensure --primary` must exit **0**, raise the seat with a
  private state, and name the pid that keeps the helm — with the dead-lock control case still taking
  the helm and carrying no private state;
- `agent start` failing with its own stderr line, and an agent that starts and then dies with
  `Tool "todo" conflicts with an existing tool` in the pane: both must be reported, and neither may
  say `agent start failed`;
- a live seat, which must be reported and **not** touched: no pane closed, no second agent raised.

The test was run against the old door and **fails 13 of its assertions there**, so it judges the
behaviour and not the wiring. The neighbouring suites stay green:
`bin/seat/tests/test_seat_reap.sh` (70 ok), `bin/gates/tests/test_review_seat_verdict.sh` (6),
`bin/gates/tests/test_review_seats.sh` (14), `tests/test_eindri_liveness_grace.sh` (4).

**What this does not touch.** The keeper unit is the register's (`config/units.yaml`), and a
machine's own units are changed by that machine's holder (`RULES/41`, `RULES/55`) — this is the repo
half only. Nothing was removed to get a green: every existing face of the reader, and every existing
path of the seat door, still answers as it did.

## Change log

- **2026-11-14** — written, with plan 293 part 10.
