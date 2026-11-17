## smidja · unversioned · 2026-11-17 — the smithy seats an agent in a pane, and a team is seen as a session

### Why

The Smíðja could run an agent as a child process and read its stdout (`agent_pi`), or through
OpenCode's event stream (`agent_opencode`). Both are invisible while they work: the run happens
somewhere behind a pipe, and the only evidence a person gets is the trace, afterwards.

The Allfather asked for the other thing, in three sentences: *"its importatn thet the ui gets seen
for the agents so the users can see it running"*, *"the teams should be ssen as session"*, and
*"we also have agent runtimes in the smidja it self"*. A factory whose agents cannot be watched is
a batch job with a nicer name.

There was also a fault he found by using the board — *"i cant delete the sessions in the ui when
pressing x"* — and one the first proof run found by running: **every agent phase in this tree
crashed at its last line** with `'Run' object has no attribute 'context_by_phase'`.

### The mends

| mend | where |
|---|---|
| a third surface: an agent **seated in a herdr pane**, raised through the one spawn path, spoken to with `eindri-send.sh`, read with `herdr agent read` | `apps/smidja/smidja_modules/agent_herdr.py` (new) |
| the envelope parsed exactly as the pi surface parses it — from the agent's own session record first (byte-exact), the pane as fallback, one road named in the trace | `agent_herdr.run`, `agents._event_forwarder` (`herdr_seat` event) |
| `coding_agent: herdr` in the schema of record, with `opencode` too — the literal refused a config the validator accepted | `data_types.CodingAgent`, `cookbooks/create_config.md` |
| the pane and the session id recorded in `agent_map.json` beside the model | `agents._agent_map_entry` |
| a seat starts **in the run's own tree**, with the agent's `system.md` as its system prompt and no house context files (`-nc`) | `bin/seat/herdr-run.sh` (`--seat-cwd`, `--system-prompt-file`), `agent_herdr.raise_seat` |
| a prompt that lands while pi is still booting is **confirmed** (a new user turn in the agent's own record), not assumed from an exit code | `agent_herdr.send_confirmed` |
| the panes a run opened are **closed when it finishes** — the 27-shells lesson | `runner.Run.finish` → `agent_herdr.close_seats` |
| a team bigger than the machine is **refused with the arithmetic** (seats × floor + one resident local model, against RAM − the estate's ceilings − the desk's reserve) | `smidja_modules/budget.py` (new), `agents.validate`, `bin/desktop/smidja-doctor.sh` (new) |
| the board shows the **seats live** (name · pane · state · tree · `look`) and the **team per run** (runtime · model · window · pane) | `server/herdr-api.ts` (new), `src/components/HerdrSeats.vue`, `src/components/TeamStrip.vue` |
| the × on a session card **works**: the list asks for the review list, and the archived view restores | `api.fetchSessions(scope)`, `SessionsList.vue`, `SessionCard.vue` |
| `Run.context_by_phase` declared — the write that killed every agent phase | `runner.Run.__init__` |
| the shipped prompts' Report examples no longer carry **copyable placeholders** (`<smidja_id>`, `<context_handoff_dir>`), which agents copied verbatim into `artifacts` and the gates then refused | `apps/smidja-factory/templates/prompt_engineering/{planner,reviewer,scout,documenter}/user.md` |

### Proof

A three-agent roster with `coding_agent: herdr`, in a throwaway repo, run from the repo root:

```bash
smidja_plan_build.py requests/health.md --smidja-id proof1     # 4/4 phases, success
smidja_build_review.py requests/health.md --smidja-id proof1   # 3/3 phases, review approved 8/8
```

- every agent in its own pane (`smj-proof1-planner` wN:p9, `…-builder` wN:pB, `…-reviewer` wN:pC),
  each seated in `/tmp/smidja-proof` — the run's own tree;
- every envelope parsed (road `session`), every gate green (`diff_matches_claims`,
  `artifacts_exist`, `files_non_empty`, `verdict_consistent`);
- `agent_map.json` carries `pane`, `tab`, `name`, `surface`, `session_id` per agent;
- **every pane closed** at the end (`closed 2 herdr pane(s)` then `closed 3 herdr pane(s)`);
- a second run (`live1`) watched in the Electron window through DevTools while it worked: the team
  strip read `2 AGENTS · herdr×2 · builder HERDR … wN:pD done …/tmp/smidja-proof` and the seats
  strip read `6 SEATED · 1 WORKING`.

The bound, refused by name:

```
"refused","- this team needs 3 seats: 1200 MB of harness floor (3 × 400 MB) = 1200 MB, and this
machine leaves 0 MB for agents (127999 MB RAM − 4768 MB declared by 19 service(s) − 126500 MB for
the desk) — at most 0 seat(s). Remove members, or raise the machine's line."
```
`bin/desktop/smidja-doctor.sh` exits 1 on that roster and 0 on a roster that fits.

### Not in this change

`roster.yaml` with `stacks:` — the team-as-a-unit the books describe — does not exist in this tree,
and this change did not invent one: a second shape is a second copy of the truth (plan 315 §6.1).
The bound is therefore enforced on the one shape that exists (a config's `agents:`), which is also
the list a run actually seats.
