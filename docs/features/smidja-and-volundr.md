# Smíðja and Völundr — the agent factory

## What it is

**Smíðja** is the smithy: a repeatable **agent+code pipeline** — a roster of agents, a
sequence of bounded phases, typed envelopes between them, retries and acceptance, and a
full trace. **Völundr** is the master smith who runs it. It turns "an errand" into a
repeatable forge.

## What you need

- Ymir installed. The visualizer + database are provisioned on first use; the DB lives in
  the home (`$YMIR_HOME/smidja/smidja.db`), not a tree.

## Do it

**The board** (by one name, wherever the UI lives):

```bash
bin/desktop/smidja-board.sh build     # install deps and build the UI
bin/desktop/smidja-board.sh start     # raise the API + UI (:8437)
bin/desktop/smidja-board.sh status
bin/desktop/smidja-board.sh stop
```

**Bootstrap + observe:**

```bash
bin/desktop/smidja-bootstrap.sh       # create the DB from the tracer schema
bin/desktop/smidja-observe.sh         # watch a run
```

**Read a finished run, one row per phase:**

```bash
uv run apps/smidja/smidja_trace.py <smidja_id>     # or: just trace <smidja_id>
```

That prints the phase, the agent, the model it actually ran on, its thinking
level and tools, how many tokens stood in the window when it stopped, that
model's window, the percentage, and a verdict: `room to work`, `past the auto
threshold`, `near the window — compact now`, or `TRUNCATED`. Add `--json` for the
full receipt (`input`, `cache_read`, `output`, `window_source`).

**A full window is reported, not hidden.** A phase that ends at or above 75% of
its model's window is `context-pressed`: the banner, the session status and
`just phases` all say so, and the run exits non-zero. It is never counted as a
plain success.

The deep reference is the skill: `.agents/skills/smidja-factory/SKILL.md` — rosters,
phases, envelopes, the trace store, the visualizer.

## Notes and limits

- **Runs are traced.** Every phase leaves a record; a failure is visible, not a silent
  retry.
- **Bounded phases, typed envelopes.** A phase cannot wander — that is the point of the
  smithy.
- **The DB lives in the home**, never a tree; a packaged install and a clone share it.
- **The visualizer is `:8437`** — raised with the set (`scripts/start.sh`).

## Continue a run, read a run, and say yes to a run

A run that dies does not start again from the top. It continues at the last phase that
finished green, and the work it already paid for — the agents' reports, the test verdicts,
the commit — is handed forward instead of being bought twice.

```bash
just resume <run-id>                       # continue at the phase after the checkpoint
just resume <run-id> --from-phase build    # re-enter at a named phase instead
just resume <run-id> --dry-run             # print the plan, launch nothing
just record <run-id>                       # the run as one record: phases · state · where it stopped
just record <run-id> --as-steps            # every step of every phase
just record <run-id> --json                # the same record, whole, for a UI or a script
```

`just record` is the honest answer to "where is this run?" — every phase with its steps in
order, the checkpoint it stands on, and one sentence on where it stopped. It says
`waiting` when a run is waiting for you, and `interrupted` when the process is gone, which
is what a hard crash leaves behind.

**A phase can be made to wait for your word.** A smithy author marks a phase
`contract="approval"`, and its work does not happen until you decide:

```bash
just decide <run-id> signoff approve
just decide <run-id> signoff decline --note "not this week"
```

While it waits the run exits with code 3 and tells you the command it needs; a decline
exits 4 and the phase's work never runs. Silence is never a yes, and restarting the run
does not sneak past it.

## If it does not work

| What you see | What to do |
|---|---|
| The board is empty | `bin/desktop/smidja-bootstrap.sh` creates the DB. |
| `:8437` refuses | `bin/desktop/smidja-board.sh build`, then `start`. |
| A run stalls | `bin/desktop/smidja-observe.sh` shows the phase it stuck on. |

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.

## Choose the model Völundr's chat starts on

Völundr is the smithy's own chat — the voice in the visualizer's Chat page. It answers on a
model this machine's `pi` actually serves, and **you name which one**.

Smíðja takes it in this order: the `SMIDJA_CHAT_MODEL` environment variable, then your own
`config/smidja.env` in the home, then the generic default the repository ships.

Copy the template and set your value:

```bash
cp config/smidja.env.example "$YMIR_HOME/config/smidja.env"
$EDITOR "$YMIR_HOME/config/smidja.env"      # SMIDJA_CHAT_MODEL=provider/model
```

Ask the machine before you type an id — a model the catalogue does not list cannot answer:

```bash
bin/model/catalog.sh --has opencode-go/deepseek-v4.1-flash
```

The picker on the Chat page then opens with your model already selected. If the chat
fails, the error now names the model and quotes what the provider said, whole.

**If it does not work:** if the picker still says `default`, the file is not where Smíðja
looks — it must be `<your home>/config/smidja.env` — or the id you named is not in the
catalogue.

## CHANGE LOG

- **2026-11-14** — added: how to name the chat's model (the home's `config/smidja.env`).
