# The arms and the crown — who may act on this machine, and for how long

> **The short version.** One session per machine holds the **arm**: the right to spawn workers,
> steer them, merge and drain. A project does not take that arm for itself — it takes a **lease**
> from it: *"you may have two hands until an hour from now"*, renewed while it works and reclaimed
> by the machine when it goes quiet. Nothing may be spawned under no authority at all.

## What it is

A machine has one arm. That was fine while one desk did all the work, and it broke the moment the
Allfather opened a project: the desk's arm and the project's need for hands were the same token, so
either the desk went silent while he worked, or his project could not raise a worker.

So there are three ranks, one lock each, and a lease between them:

- **the machine arm** — one per machine. The right to act *on this machine*: spawn, steer, merge,
  drain. It owns the desk, the mail, the wakes and the room, and never does project work. **Only a
  session that can speak may hold it** — a live model heartbeat, not a watcher process.
- **a project orchestrator** — one per active project. It holds **no arm**: it holds a **lease** from
  its machine arm, renewed by heartbeat. The lease is what stops a project from being a second
  sovereign, and what lets the desk keep answering while a project runs.
- **the crown** — one for the fleet, the orchestrator of orchestrators. This release reads its rank
  and its row; its own service is a later plan.

A spawn now says which authority it used, and a tell to another machine carries a deadline, so a
question that is never answered escalates instead of waiting for ever.

## What you need

Nothing beyond what a seat already has. The lease table lives in the state the arm already uses
(`<state>/.arm.leases`), beside the arm's own lease, and every command below is in `bin/`.

## The commands

Who holds what, and which rank you hold:

```bash
bin/voice/arm-lease.sh ranks          # every holder's row + this seat's rank, in one line
bin/voice/arm-lease.sh who            # where the table and the journal are
bin/voice/rodd-arm.sh who             # the machine arm: pid, seat, heartbeat
```

Hold the arm yourself (only a session that can speak can):

```bash
bin/voice/rodd-arm.sh hold            # refuses a holder without a live model heartbeat
bin/voice/rodd-arm.sh speaks          # why it would, or would not, take you
```

A project's lease:

```bash
bin/voice/arm-lease.sh grant ymir --holder the-foringi     # 2 hands, 1 hour, by default
bin/voice/arm-lease.sh renew 3                             # still working: beat again
bin/voice/arm-lease.sh list                                # live and dead, with the verdict
bin/voice/arm-lease.sh reclaim 3                           # the machine takes a DEAD lease back
```

A spawn names its authority before it creates anything:

```bash
bin/voice/arm-lease.sh authority                           # what a spawn here may use, and why
bin/seat/herdr-run.sh eindri my-errand --role sindri -- "the task"
bin/agents/einherjar-spawn.sh my-errand ~/ymir --mode local-only
```

A tell to another machine's arm holder, with a deadline:

```bash
bin/fleet/arm-send.sh heimdall "is the desk up?"           # stamped, ledgered, deadline 30 min
bin/fleet/arm-send.sh --pending                            # still inside their deadline
bin/fleet/arm-send.sh --expired                            # ESCALATE: past the deadline, unanswered
bin/fleet/arm-send.sh --ack t1794918317-f06e               # the receiver closes it
```

## Limits, and the numbers that are his to set

- **Hands and duration are the Allfather's to decide** (plan 310 §7.2). Until he does, a lease grants
  **two hands** for **one hour** (`YMIR_ARM_LEASE_HANDS`, `YMIR_ARM_LEASE_TTL`), and a lease whose
  heartbeat has been silent for **five minutes** is reclaimable (`YMIR_ARM_LEASE_STALE`). A tell
  stands **thirty minutes** before it escalates (`YMIR_TELL_DEADLINE`).
- **A reclaim of a live lease is refused.** A dead heartbeat is the permission; a living claim is
  somebody's work.
- **A watcher is not a speaker.** A session with no model behind it cannot take the arm, and an arm
  held by one grants a spawn nothing unless another harness on that machine is genuinely speaking —
  and then the refusal/authority row says the hand is *borrowed*.
- **The names are not sealed yet.** The plan proposes **Gná** for the machine arm, **the foringi** (or
  a figure per project) for an orchestrator, and **Týr** for the crown. Only the Allfather seals them;
  the code uses the names it already had and says `the machine arm`, `a project lease`, `the crown`.
- **A read-only seat can still ask.** A seat with no rank may always ask the arm holder for work:
  `bin/seat/lock-ask.sh ask "<question>"`. A refusal that also silenced the asking would be wrong.

## If it does not work

`bin/voice/arm-lease.sh ranks --line` is the first read: it names this seat's rank and why it has it.

- *“read-only — … the machine arm's hand cannot speak”* — the arm is held by a process with no model
  behind it. That is the fault the plan exists to close: a session that can speak should take the arm
  with `bin/voice/rodd-arm.sh hold`.
- *“refused: no live lease for scope … and no machine arm is held here”* — nobody has the right to act.
  Take the arm (`hold`), or have the holder grant a lease (`arm-lease.sh grant <scope>`).
- *“there is no lease N on this machine”* — the lease was reclaimed, or it belongs to another machine.
  A lease never travels.

The tests are the judge: `bin/voice/tests/test_arm_speaks.sh`, `test_arm_lease.sh`,
`test_arm_authority.sh`, `bin/fleet/tests/test_arm_send.sh`, `bin/time/tests/test_saga_rank.sh`.
