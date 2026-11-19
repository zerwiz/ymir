# smidja starter recipes. Stamped by install.py, then yours to edit.
#
# Deliberately small. These are the handful you need on day one: run something,
# watch it, and open the trace. Add your own as your chains grow, and see the
# example branch for the fuller set (orchestrator agents, kill, rosters, ipi).

# `.env` reaches every smidja through this, so keys work without exporting them.
set dotenv-load
set positional-arguments

# 2026-11-19 (the split): every recipe goes through `scripts/smidja`, the smithy's one command, which
# finds the engine wherever it is (this tree, or the installed smithy's own) and the one trace the viewer
# reads. `SMIDJA_CONFIG=other.yaml just sdlc "..."` still swaps the whole roster for one run (the command
# honours SMIDJA_CONFIG). Runs are launched DETACHED, as the books ask; watch them with `just sessions`.

# list every recipe
default:
    @just --list

# ── first run ───────────────────────────────────────────────────────────────

# Proves the whole path works: config validated, session minted, agent ran,
# envelope parsed, gates checked, trace written. Costs a few cents and changes
# nothing in your repo, because both workflows are read-only.
#
# (`just --list` shows only the LAST comment line, so that one is the summary.)

# start here: two cheap read-only runs, end to end
demo:
    @echo "1/2  smidja_prompt: one agent, one prompt"
    scripts/smidja run prompt --no-done-check "reply with a one-line summary of this repo"
    @echo "\n2/2  smidja_scout: read-only recon"
    scripts/smidja run scout --no-done-check "list the top-level directories in this repo and what each is for. change nothing."
    @echo "\nboth done. now run:  just sessions    (or: just obs)"

# ── run a workflow ──────────────────────────────────────────────────────────
# Args pass straight through: "<prompt or path/to/prompt.md>" [--smidja-id X]

# one agent, one prompt: just prompt "summarize this repo"
prompt *ARGS:
    scripts/smidja run prompt --no-done-check "$@"

# read-only recon: just scout "where is auth handled"
scout *ARGS:
    scripts/smidja run scout --no-done-check "$@"

# plan only: just plan "add a /health endpoint"
plan *ARGS:
    scripts/smidja run plan --no-done-check "$@"

# planner, builder, commit: just plan-build "add a /health endpoint"
plan-build *ARGS:
    scripts/smidja run plan-build --no-done-check "$@"

# plan, build, test, commit: just sdlc "add a /health endpoint"
sdlc *ARGS:
    scripts/smidja run plan-build-test --no-done-check "$@"

# the full chain, plus review and docs: just simple-sdlc "add a /health endpoint"
simple-sdlc *ARGS:
    scripts/smidja run simple-sdlc --no-done-check "$@"

# continue a run at its last green phase: just resume <smidja_id> [--from-phase <name>]
# Refuses rather than guesses: no such run · nothing green to resume from ·
# the roster changed since this run. Add --dry-run to see the plan and launch nothing.
resume *ARGS:
    scripts/smidja resume "$@"

# the run as ONE record — phases, steps, state, and where it stopped
# just record <smidja_id> [--json]; the same shape resume reads.
record *ARGS:
    scripts/smidja record "$@"

# record a person's decision on an `approval` phase: approve | decline | cancel
# An approval phase never runs its block without one; silence is not a yes.
decide *ARGS:
    scripts/smidja decide "$@"

# ── watch it ────────────────────────────────────────────────────────────────
# Reads never block a running workflow, the db is WAL. Poll as hard as you like.

# the last 10 runs
sessions:
    @scripts/smidja sessions

# phase status in sequence: just phases <smidja_id>
phases smidja_id:
    @scripts/smidja phases {{smidja_id}}

# the live event tail: just tail <smidja_id>
tail smidja_id:
    @scripts/smidja tail {{smidja_id}}

# what a run has alive right now, with pids: just procs <smidja_id>
procs smidja_id:
    @scripts/smidja procs {{smidja_id}}

# ── observability UI ────────────────────────────────────────────────────────

# Needs bun. The db path is passed explicitly because the server runs from the
# app dir and would otherwise look for a trace db sitting next to itself.

# boot the trace UI, http://localhost:8438 (api on :8437)
obs:
    scripts/smidja up   # the viewer, API + UI, on :8437 (the built UI; the old :8438 vite dev server is `bunx vite` in the smithy's apps/visualizer)
