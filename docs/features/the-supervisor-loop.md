# The supervisor with a mind

Ymir watches the machine in two halves. The first half is Sýn's standing arm: it knows
whether the session is alive and raises the line that needs you. The second half is this
one — the **supervisor loop** — and it exists because a watch that can only report cannot
fix anything.

> [!IMPORTANT]
> The loop acts only while the arm is held. With nobody at the helm it measures and says
> so; it never acts on its own authority.

## What it is

Five steps, every pass:

1. **measure** — memory, swap and load from `/proc`; restart and state counts from the
   registry; the registry's own audit; one line per surface the registry names for this
   machine.
2. **judge** — a model turn. It is handed the measurement, the runbook library's
   situation table and the list of verbs the house allows, and answers with **one verb**
   and the reason.
3. **act** — one verb, and only while the arm is held (`bin/voice/rodd-arm.sh who`).
4. **prove** — the same measurement runs again. A surface still down is recorded as
   failed, in the same line, never quietly.
5. **record** — one line in the machine's `fixes.md` and one rune.

A fault whose cure is yours — a credential, money, a unit marked `criticality: always`,
another hand's service — is **escalated in one message** instead of retried. That message
is a `check:` line in the durable wake queue, which the arm hands to the helm.

## What you need

- The machine's registry at `$YMIR_HOME/hodd/identity/services.yaml`, with `host:` naming
  the machine and one row per service. A container the registry does not name is never
  touched.
- A model this machine can serve. The judge asks `bin/model/agent-model.sh` for the model
  and `bin/model/model-allow.sh` whether it may run; a model the catalogue does not list is
  refused by name.
- An arm held by a session that can speak. `bin/voice/rodd-arm.sh who` answers.

## The commands

```sh
bin/pi/syn-supervisor.sh --once          # one pass of the whole loop
bin/pi/syn-supervisor.sh --every 60      # the standing loop
bin/pi/syn-supervisor.sh --once --toon   # the pass as agent-facing rows
bin/pi/syn-supervisor.sh --once --dry-run   # measure and judge, act on nothing
```

Probe flags, for a test or a second machine: `--registry PATH`, `--host NAME`,
`--judge PATH`, `--runbook-index PATH`, `--fixes PATH`, `--any-host`.

The engine behind the door answers the same verb:

```sh
bin/engine/ymir-engine.sh supervise --once
```

## The verbs it may run

| verb | runs | allowed when |
|---|---|---|
| `none` | nothing | nothing this loop owns is faulted |
| `start-container` | `docker start <container>` | criticality is `wanted` or `dormant` |
| `restart-container` | `docker restart <container>` | the same |
| `start-unit` | `systemctl --user start <unit>` | a unit named in this machine's registry |
| `restart-unit` | `systemctl --user restart <unit>` | the same |
| `escalate` | one message to the helm | the cure needs you |

A verb outside that table is refused; a target the measurement does not name is refused;
a `*-unit` verb pointed at a container is refused.

## Limits

- One verb per pass, and one pass at a time: the loop is a supervisor, not a swarm.
- It only touches surfaces its own registry names for its own host. A registry for
  another machine names nothing here, and the loop says so.
- A state it cannot read is `unknown`, not a fault. It never acts on a guess.
- The judge is read-only by construction: no tools, no MCP, no extensions, no session.
- It never writes into the code tree. `fixes.md` and the rune ledger live in the home.

## If it does not work

`refused: no arm is held` means exactly that — raise a session, or leave the loop idle.
`refused: the judge door …` means the model could not be resolved or was not allowed; the
reason names the row and the catalogue. `refused: the judge named the verb …` means the
model invented a verb and the house's vocabulary won. A `FAILED` line in `fixes.md` means
the act ran and the fault survived: read the line, it carries both measurements.

## Where the rest of it is written

The machine-side page is `hodd/docs/runbooks/the-supervisor.md` in the home, and the loop's
own record is `hodd/machines/<machine>/fixes.md`.

## CHANGE LOG

- **2026-11-17** — the page was written (plan 004): the supervisor loop — measure, judge with an agent, act under the arm, prove, record — and what it refuses.
