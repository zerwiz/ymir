## agents · unversioned · 2026-11-14 — every brief carries its bearings, and a worker sits in its own project's folder (plan 291 parts 2 and 3)

### Why

At the Allfather's word: *"we need to update the endri system so they are allways using and updateing this
when getting send out"* and *"when we sending workers for diffrent projects the need to be send from the
project foldeers they are going to work in so they dont do the updates in ymirs repo"*.

Two faults, both measured on 2026-11-14:

1. **A brief was exactly what the helm remembered to type.** Nothing told a worker where its project's
   decisions, handoff, schedule, plans, meetings, seat and boards live, and nothing asked it to update them.
   The "fixed core" every worker carried was a hand-kept file in the helm's scratchpad — not part of the
   system, and invisible to any other seat.
2. **An errand for another project was seated in Ymir's repository.** Measured at 13:08 CET:
   `eindri-start.sh --project <a registered project's clone>` still made its worktree inside
   Ymir's own tree, so an errand for Foreman would have committed into Ymir's tree.
   The helm stopped it before it wrote anything, and both trees were clean.

### The fix

**Bearings, in every brief, on every road.** `bin/agents/eindri-bearings.sh` prints one generated section:

| Part | Carried from |
|---|---|
| (a) the fixed core | the shipped, agnostic `.agents/assets/agents/eindri-core.md`, then the home's overlay `$YMIR_HOME/config/eindri-core.md` |
| (b) the project's records | the row's new `records:` block in `$YMIR_HOME/hodd/identity/projects.yaml`, through `bin/agents/project-target.sh` |
| (c) the home's document map | `.ymir-layout.yaml`, `hodd/docs/INDEX.md`, the atlas, `svartalfaheim/*/projects/*/plans/README.md`, `state/eindri-reports/` |

It is prepended by `eindri-start.sh` on both roads and for every harness, and by the engine in
`_prompt_for` for an errand seated through `einherjar-spawn.sh`. Both skip it when the brief already
carries the marker (`<!-- eindri-bearings:v1 … -->`), so a brief is never doubled. A project with no
`records:` block gets a plain statement and the row to add — **never an invented path**.

**A worker for another project starts in that project's folder.** `bin/agents/project-target.sh` resolves
a path, an id or an alias through the registry to *this machine's* clone, then makes the worktree in
**that repository** by that project's own declared convention (`worktree: {command, path, branch}`, each
with `{id}`); with no block the default is `git worktree add -b eindri/<id> <clone>/.yggdrasil/<id>`.
`eindri-start.sh` cds there and passes `--main` to `herdr-run.sh` so no second worktree is nested. A row
with no clone on this machine is refused, with the row named. Ymir's own row is `kind=ymir` and this door
makes no worktree for it — the engine and `bin/forge/yggdrasil.sh` own those.

**The packet and the report carry it too.** `bin/forge/handoff-packet.py write` gains
`--record "<path>|<what>"` (or `--record "none|<why>"`); `schemas/handoff-packet.toon` documents the block
and rule 7; `check` refuses a packet with no `records[]`, an empty one, or a `none` with no weighable
reason. The brief template in `bin/agents/erindi-brief.sh` tells every worker to write the same line.

**The launcher waits for the agent, not for `start`.** `herdr agent start` returns when the pane HOLDS
an agent, which is not when the harness can take input — measured the same day, two hand-seated workers
sat idle until their prompt was sent again. `bin/seat/agent-state-lib.sh` reads herdr's own
`interactive_ready` and `agent_status`; `bin/seat/herdr-run.sh` now waits for readiness (bounded, 20 s)
before it speaks, then confirms the agent moved (`working`/`done`) and retries the prompt **once** if it
did not. `idle` with `interactive_ready: false` is *not* ready; `working` and `done` are past needing
input. A harness herdr cannot detect as interactive is not made to wait for ever, and a blind reader
(no herdr) says `unknown`, never `ready`.

**The schema, in the open.** `registry/projects.yaml.example` documents `records:` and `worktree:`, and
`.agents/skills/jord-projects/SKILL.md` says `project add` asks for both.

### The agnostic law

The shipped core carries no machine, no pane, no person and no private path; this fleet's names, panes,
machines and standing words live only in `$YMIR_HOME/config/eindri-core.md`. The test asserts the shipped
template matches none of `/home/`, `/Users/`, a machine name or a pane id.

### Proof

`bin/agents/tests/test_eindri_bearings.sh` — 17 passed, 0 failed on a PLANTED home: the shipped core, the
home's overlay (a sentinel no shipped file may carry), a project's records with the duty, and the "no
records" message that names the row and invents no path.

`bin/agents/tests/test_project_target.sh` — 20 passed, 0 failed on planted repositories: id, alias and
path all resolve to this machine's clone; the project's own convention gives `.yggdrasil/probe` on
`agent/probe` (and `git worktree list` agrees); the default gives `eindri/probe`; a clone-less row is
refused and named; this tree is `kind=ymir` and makes nothing; the Ymir tree's `git status --porcelain` is
byte-identical before and after.

`bin/seat/tests/test_agent_state.sh` — 9 passed, 0 failed against a stub `herdr`: ready when the field
says so, **not** ready when the box is not drawn, past ready when working or done, `unknown` (never a
claim) when herdr cannot be read or is absent.

`bin/gates/tests/test_handoff_packet.sh` — 20 passed, 0 failed, with four new cases: a write with no
`--record`, a bare `none`, an empty `records[]` block at check, and the records count in the printed row.

`bin/agents/eindri-start.sh "…" --project <a registered project> --id x --dry-run` prints
`worktree=<that project's clone>/.yggdrasil/x`, `branch=agent/x` (the convention its registry row
declares), `road=a worktree in the project's own repository`, and `bearings.core_carried=yes`.

**The runbook.** `docs/runbooks/send-an-eindri.md` is new: the seat road, *a worker for another project*,
*bearings — what every brief carries*, what the worker owes back, and the symptoms seen that day. It is
on the shelf in `docs/runbooks/README.md`.

### Not done, and named

- The real Foreman errand is not re-sent here: the branch carries the road, and the helm sends it through
  the new road once merged.
- `python3 -m unittest discover` in `src/ymir_runtime/tests` fails on six pre-existing tests that name
  `bin/runes-append.sh` (moved to `bin/records/`), untouched by this change; `test_seat.py` is 32/32 green.
