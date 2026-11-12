# The seats and the arm — where the work is, the whole house in one read, and who can be woken

## What it is

Three doors that answer three different questions, and none of them guesses.

**The seats** (`bin/seat/seats.sh`) — every pane that is open on this machine, in
either backend (herdr first, tmux if herdr is not running), with each pane's own
state: **working**, **idle**, **shell**, or **DEAD**. A dead shell is one whose
errand has ended and which will never answer again — it sits inside a disposable
`.yggdrasil/` worktree with no agent in it. That is the pane you close, and the door
refuses to close anything a live agent holds.

**The hall** (`bin/agents/hall.sh`) — the whole house in one read: which seat you
are, how many shell doors exist, whether anything is waiting to wake you, and the
last runes carved into the ledger. Read-only, and it writes nothing.

**The arm** (`bin/pi/arm.sh`) — whether this harness can actually be woken mid-run,
said honestly per harness. The watch *loop* is harness-agnostic (a systemd user
unit, `ymir-syn-watch.service`); the *session side* — how a wake gets into a live
session — belongs to a harness extension, and a harness with neither a hook nor an
extension cannot be armed. The door says so instead of pretending.

## What you need

- herdr or tmux for the seats (`herdr` is the ordinary road; tmux is the fallback
  and the door says which one answered).
- `python3` for the herdr pane rendering.
- For the arm: the `ymir-syn-watch` unit, run as your own user service.

## Do it

### Where the work is

```bash
bin/seat/seats.sh list
```

The first line names the backend, then one line per pane:

```
backend: herdr
pane      agent     state     dir                              title
w8:p1     pi        idle      ~                                π - <host>
w3:pJ     -         shell     ~/ymir                           you@<host>:~/ymir
wA:p1     -         DEAD      ~/ymir/.yggdrasil/<errand>       you@<host>:~/ymir/.yggdrasil/<errand>
wE:p1     pi        working   ~/ymir/.yggdrasil/<errand>       π - <errand>
```

Every state in that table is the **backend's own report**, not a claim of ours. A
pane holding an agent shows the agent and its status; a pane holding a bare shell in
an ordinary directory is `shell` — yours, and nobody's seat; a bare shell inside a
disposable worktree is `DEAD`.

Close a dead shell — and only a dead one:

```bash
bin/seat/seats.sh close wA:p1
```

Three real answers:

```
closed wA:p1 (no live agent held it; ~/ymir/.yggdrasil/<errand>)
refused: w3:pB holds a live agent (pi, done)
no such pane: no:such:0:0
```

The refusal is the feature. Closing a pane a live agent is working in destroys an
errand mid-word, so the door reads that pane's own record before it touches
anything, and refuses.

### The whole house in one read

```bash
bin/agents/hall.sh
bin/agents/hall.sh --runes 20
```

```
hall[4]{what,detail}:
  "seat","primary=<figure> host=<this-host>"
  "doors","612 shell doors listed in bin/README.md"
  "queue","0 pending wake(s)"
  "runes","<count> (last 5: <timestamp> <actor> · <timestamp> <actor> · …)"
```

Four facts, each from the door that owns it: the seat from the rendered seat file,
the door count from `bin/README.md` (the generated inventory), the queue from the
wake drain, the runes from the ledger tail. A door that cannot answer is reported as
unable, never as zero.

### The arm — which harness can be woken

```bash
bin/pi/arm.sh status
```

```
arm[3]{what,value,note}:
  "watch unit","active","the loop runs outside the session"
  "lock","none","the session that holds the helm"
  "arm","possible","the session side is an extension (Pi: gna-pi-watch; OpenCode: syn-watch-arm.js)"
```

Read it in that order. If the **watch unit** is not active, the arm is **not
possible** and the door says which service to start — there is no arming a loop
that is not running. If the unit is active, the session side decides the rest.

| harness | can it be armed mid-session? | what it needs |
|---|---|---|
| **Pi** | yes | the `gna-pi-watch` extension, already installed |
| **OpenCode** | yes | `.opencode/plugins/syn-watch-arm.js`, already installed |
| **Claude Code** | yes, via a hook | `bin/pi/arm.sh hook claude` prints the `SessionStart` hook line to add |
| **Hermes** | yes, via a hook | `bin/pi/arm.sh hook hermes` prints the same |
| **Codex, Cursor** | **no** | no session-hook surface; they can *read* the digest, but cannot be woken mid-run |

```bash
bin/pi/arm.sh hook claude
bin/pi/arm.sh hook codex
```

```
claude: add a SessionStart hook that runs: …/bin/time/saga-session-start.sh
codex: no session hook surface installed — it can read the digest by running …/bin/time/saga-session-start.sh, but cannot be armed mid-session (named, never faked)
```

The digest is the recovery input: whatever a harness can do, it can run
`bin/time/saga-session-start.sh` once at the start and know where the house stands.
Arming is the *additional* thing — a wake arriving while you are mid-turn.

## Notes & limits

- **Pi arms itself.** The extension re-arms at the end of each cycle; you do not run
  the arm script by hand, and a hand-run arm is how two cycles end up fighting. If a
  notification says the cycle is missing or unhealthy, that is when a repair runs.
- **Never run `bin/pi/syn-watch-arm.sh` directly.** It is the loop's own door; the
  harness extension owns it.
- `seats.sh list` shows what the backend knows. A pane whose agent process is alive
  but wedged still reads `working` — the door reports state, it does not diagnose
  health. If a working seat never moves, that is a recovery question, not a seats one.
- On tmux the state column carries the foreground command name; a bare `bash`,
  `zsh` or `sh` is `shell` (or `DEAD` inside a worktree), and anything else is
  reported by its own name and refused on `close`.
- `seats.sh` is read-only except for `close`, and `close` is the one destructive
  action on this page.
- Where there is no session bus (a cron job, a container, a boot script),
  `arm.sh status` reports the unit as `unknown (no session bus in this context)` —
  unknown is not absent, and a wrong claim would close a question that is still open.
- `hall.sh` reads the seat file and the generated inventory; if either is stale the
  hall reports the stale number. Regenerate with `bin/gates/inventory.sh` and
  `bin/seat/seat-surface.sh` rather than editing.

## If it does not work

**`no pane backend is running (herdr and tmux both silent)`** — neither backend
answers from this shell. Start herdr, or check that `herdr pane list` answers on its
own. Herdr must be running as your user, in the same session you are asking from.

**`bin/seat/seats.sh close` says `no such pane`** — the id must be the backend's own
(pane ids look like `w3:pB` in herdr, `session:window.pane` in tmux). Copy it from
`seats.sh list`; a pane that has already been closed cannot be closed again.

**`arm` says `not possible — the watch loop is not running`** — raise the unit:

```bash
systemctl --user start ymir-syn-watch.service
systemctl --user status ymir-syn-watch.service
```

Then re-run `bin/pi/arm.sh status`. If the unit refuses to start, read its journal —
a watch loop that dies on start will not be fixed by arming harder.

**`arm` says `unknown (no session bus in this context)`** — you are not in a login
session that owns a user bus. Run the door from your own shell — the same shell you
would type `systemctl --user` in — and it will read the unit properly.

**The hall prints a door count of zero** — the count comes from the generated
inventory, not from a directory listing. Run `bin/gates/inventory.sh` to regenerate
`bin/README.md`; a zero over a full shelf is a stale generated file, and it is worth
one look because this number has lied before.

## Proven on this machine, 2026-11-04

```
bin/seat/seats.sh list          → backend: herdr, 18 panes, 4 named DEAD
bin/seat/seats.sh close w3:pB   → refused: w3:pB holds a live agent (pi, done)
bin/seat/seats.sh close no:…    → no such pane: no:such:0:0
bin/agents/hall.sh              → the seat (figure + host) · 612 doors · 0 pending wakes,
                                   the rune count and the last 5 dated (`--runes 3` narrows it)
bin/pi/arm.sh status            → watch unit active · lock none · arm possible
bin/pi/arm.sh hook claude       → the SessionStart hook line
bin/pi/arm.sh hook codex        → "cannot be armed mid-session (named, never faked)"
```

The live-seat refusal was tested on a real working pane and made no change to it;
the dead-shell close was **not** run in this pass — closing another errand's shell is
not this door's debt to pay. The 4 `DEAD` panes this run reported are real and are
the operator's to close.

## The sweep — a finished seat closes itself (2026-11-10)

`bin/seat/seat-reap.sh` is the fourth door: the one that CLOSES a finished seat
instead of describing it.

```sh
bin/seat/seat-reap.sh --list        # what a sweep would close — closes nothing
bin/seat/seat-reap.sh --sweep       # close every agentless eindri-* workspace whose errand is over
bin/seat/seat-reap.sh <errand-id>   # close that one seat, by the id recorded in state/<id>.meta
bin/seat/seat-reap.sh --shell <worktree>   # close the bare shell standing in a worktree
bin/seat/seat-reap.sh --install     # seat the sweep on every harness on this host
bin/seat/seat-reap.sh --check       # is it seated? exit 1 when a present harness is not
bin/seat/seat-reap.sh --verify      # the two structural faults, reported and not mended
```

**It is automatic, by law.** Taking the arm sweeps the hall: the Sága digest has a
`SEATS` section, and the arm road (`bin/pi/syn-watch-arm.sh`) sweeps as it takes the
helm. The errand's own close also closes its seat — `bin/agents/eindri-dispatch.sh
close`, a terminal review verdict, and the arm's retirement all call the same door.

**What it will not do.** It never closes a workspace a live agent stands in: it asks
`bin/seat/herdr-agents.py` (the one reader of `herdr agent list`), asks again
immediately before the irreversible step, and the pane close itself refuses a live
agent. A review verdict of `return` keeps the seat, because the work went back to the
worker.

**And the worktree follows.** `bin/forge/housekeeping.sh` now asks whether an AGENT
stands in a tree, not whether a process does. An idle shell is no longer `keep:in-use`,
so the tree is judged by whether any of its work is missing from the remote — and a
bare shell is closed (through `seat-reap.sh --shell`, which refuses a live agent)
before anything is reclaimed. `keep:dirty` and `keep:unpushed` are untouched, as
always.

**If it does not work.** `bin/seat/seat-reap.sh --check` names the harness it cannot
seat; `--verify` names a `.ymir-root` that records a worktree, or a worktree that still
reports its extensions deleted — `bin/engine/ymir-migrate.sh apply` mends both.

## The discriminator — a finished agent is no longer "a live agent" (2026-11-11)

The 2026-11-10 sweep closed only *agentless* seats. A finished worker is still a live
process at an idle prompt, so the old `agent_in_workspace → keep` kept it forever. The
sweep now asks the one reader for the agent's STATE and names one of three verdicts:

- **working** — the agent reports `working` → kept, never touched, and a working
  sample resets the idle grace;
- **finished** — the record is terminal (done · failed · accepted · returned · closed)
  and the agent has reported `idle` continuously for `SEAT_REAP_IDLE_GRACE`
  (default 600 seconds, stamped in `state/<id>.idle-since`) → retired;
- **undecided** — no record, a fresh record, a `needs-decision` record, or a flapping
  state → kept, with the reason named. A `needs-decision` seat waits on you and is
  never reaped, whatever its age.

The retire verb ends the agent, THEN closes the seat, escalating in order and never
starting with a kill: the harness's own exit (`/quit` for pi and codex, `/exit` for
claude · opencode · cursor · grok · kimi · muse), a bounded wait (default 20 seconds),
the close doors behind the dirty/unpushed worktree guard, and only then a TERM to the
agent's own pid. One runes line records each retirement.

The digest's `SEATS` section now prints the verdict breakdown —
`closed 0 · retired 0 · kept 19 (18 finished-idle, 1 working)` — instead of a bare
count, and a seat kept three sweeps running raises a `check:` line into the wake
queue.

**Orphan panes.** `seats.sh brief` names the bare shells that are NOT errands — your
own working directories — in their own `orphans[]` row. A sweep never touches them;
`bin/seat/seat-reap.sh --close-pane <pane-id>` is the ONLY door that closes one.

```bash
bin/seat/seats.sh brief                     # … then the orphans[] row
bin/seat/seat-reap.sh --close-pane w21:p1   # close that one bare shell, his word, never a sweep
bin/agents/eir-doctor.sh check              # the seatreap surface fails if a seat has
                                            # been kept finished-idle past a day
```

The five cases are proven in `bin/seat/tests/test_seat_reap.sh`: working kept,
finished retired, needs-decision kept, dirty worktree refused, grace-not-yet-elapsed
kept — 70 assertions, all green.

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
