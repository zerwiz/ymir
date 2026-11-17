# The Smíðja's agents in panes — a run you can watch

**What it is.** The Smíðja can seat each agent of a run in its **own terminal pane** instead of
running it as a hidden child process. You see the agent think, call tools and answer, live — and the
board shows the whole team while it works: who is seated, on which model, in which pane, in which
tree, and what each one has done.

**What you need.** A herdr session on the machine (you are inside herdr when `HERDR_ENV=1`), the
Smíðja's own code, and a roster. Nothing else: no key, no account, no extra service.

## Put a team in panes

In your project's `smidja/smidja_smidja_config/smidja.config.yaml`, name the surface per agent:

```yaml
defaults:
  coding_agent: herdr            # pi | opencode | herdr
  model: opencode-go/deepseek-v4.1-flash

agents:
  - name: planner
    purpose: Turn a request into a plan the builder can implement without asking questions.
    prompt_engineering:
      system: smidja/smidja_data/prompt_engineering/planner/system.md
      user: smidja/smidja_data/prompt_engineering/planner/user.md
  - name: builder
    coding_agent: pi             # one agent may keep the headless surface
    # …
```

Then run the chain as you always do, **from the project root**:

```bash
uv run smidja/smidja_plan_build.py requests/health.md
```

## Check the roster before you run it

```bash
bin/desktop/smidja-doctor.sh --repo .
```

It answers three questions in one read: does every agent resolve (prompts on disk, model in the
catalog, surface available here), can this machine carry the team, and which agents get a pane. It
exits `0` when the roster would run and `1` when it would be refused, printing the reasons.

## What you see

Two strips, both live:

- **under the topbar, on every page** — every seat on the machine: name, pane, state, tree, and a
  `look` button that brings the pane to the front.
- **on a run's own page** — that run's team: each member's runtime (`pi` · `opencode` · `herdr`), its
  model, how full its context window got, and — for a herdr member — the pane it is working in and
  its live state.

## Limits worth knowing

- A herdr agent needs a herdr session. On a machine with none, `smidja doctor` and the run both
  refuse it **by name** before the first phase, rather than raising panes that never appear.
- A run closes the panes it opened when it finishes. To keep them standing for a look, start the run
  with `SMIDJA_HERDR_KEEP=1`.
- A team bigger than the machine is refused before a pane is raised, with the arithmetic printed:
  seats × 400 MB, plus one resident local model, against RAM minus the estate's declared ceilings
  minus a desk reserve. Override the terms with `SMIDJA_SEAT_FLOOR_MB`, `SMIDJA_DESK_RESERVE_MB`,
  `SMIDJA_LOCAL_MODEL_MB`.
- A herdr seat carries the agent's `system.md` as its system prompt and loads **no** house context
  files: a factory agent gets its own instruction, not the counsellor's contract.

## If it does not work

- `error: herdr-run.sh refused the seat` — read the exit line it prints; the usual causes are a
  model the allow-list does not carry, or a local model already resident on the rail.
- `the prompt never landed in wN:p7` — the pane was up but the agent's own record shows no new turn.
  Read the pane (`herdr agent read wN:p7`) and look at what it printed.
- A member shows `pane closed` in the team strip: the run finished and closed its seats. That is the
  run being tidy, not a fault.
