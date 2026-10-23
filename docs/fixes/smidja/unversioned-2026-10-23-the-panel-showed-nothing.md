## smidja · unversioned · 2026-10-23 — three agents ran, the panel showed nothing, and five faults explained why

### Why

The Allfather, in front of the Smíðja: *"you havent started a single agent in smidja"* · *"why dont i see
the descriptions in the ui??"* · *"why are you not using the yaml for the teams?"* · *"WHY DID WE NOT
UNDERSTAND THIS INSTANLTY??"* · then, when a run finally appeared: *"we shoulw allways see this Smíðja …
this are a rule"*.

The honest answer is that five independent faults each hid the next. Measured, in order:

1. **`pi` refused to start inside any worktree** — the worktree carries `.pi/extensions/ymirhome.ts` and
   the seat registers the same extension, so pi aborted with *"Tool ymir_find conflicts with
   …/.yggdrasil/…/.pi/extensions/ymirhome.ts · Hint: start without extensions using pi -ne"*. Every
   errand pane died this way (three of them, zero processes) and every builder turn with it: run
   `dae6d893` recorded 2 phases, 17 events and **fail in 8.1s**.
2. **The smithy is not in git.** `.gitignore:174` ignores `apps/smidja/`, so the roster's
   `prompt_engineering/{planner,builder}/{system,user}.md` and `harness_engineering/subagents.ts` exist
   in no tree and in no template — a fresh clone cannot start a run at all, because validation refuses
   before the first phase.
3. **The teams had three names** — `.agents/agents/*.md` (23 figures), `config/agents.yaml`
   (figure → model), `roster.yaml` (what the picker reads, absent everywhere). `/api/rosters` answered
   `[]` because `roster-api.ts:34` derived the **repo root from the database path**, and the DB lives in
   the home by design.
4. **Two database paths.** The factory config said `db: apps/smidja/smidja_data/smidja.db`; the
   visualizer reads `$YMIR_HOME/smidja/smidja.db`. So a real run wrote a trace the panel could not see,
   and `smidja-observe.sh` printed *"absent (run a smidja factory to write the trace)"* over four runs.
5. **The Forge printed `>-` for 22 of 29 skills** — the front-matter parser does not fold a YAML block
   scalar, and every one of those 29 skills has a description.

**Why it was not instant, said plainly:** the fact lived in the code and in no register; an empty that
does not name its cause is indistinguishable from an empty house; I patched the symptom I could see
(hand-written trace rows) instead of reading the resolver; and nothing asserts the positive, so a team
that never loaded was never red.

### The mends

| mend | proof |
|---|---|
| `agent_pi.py` starts `pi` with **`-ne`**; the run's declared extensions are still added with `-e` | run `8f110045`: `01 request success` · `02 build RUNNING` · builder on `llama-swap/qwen3.6-35b-a3b@q4_k_xl-mtp` · 35 events |
| the builder's prompts written and placed where the roster names them (they existed nowhere) | validation passes; the phase runs |
| the run invoked as `uv run apps/smidja/smidja_build.py … --config …` **from the repo root** — the config's paths are root-relative, so from `apps/` it resolves `apps/apps/…` and dies | a run that starts instead of a "prompt not found" that is really a wrong cwd |
| tonight's trace written to the DB the UI reads, through a local config override | the panel draws the run, its phases and the agent lane |
| the hand-written rows **deleted** at his word — a row with no writer is a claim, not a fix | `select count(*) from sessions` → `bootstrap` + the real run |

### The law this produced

`RULES/36-the-run-is-visible.md` (+ the `smidja` asset, same pass): every run appears with session,
phases, agent lane, events and verdict; one writer and one DB; the team from the roster YAML; the
invocation is `uv …` from the repo root; `pi -ne` in a worktree; a failure shows its cause; and nobody
patches the screen.

### Files
- `RULES/36-the-run-is-visible.md` · `RULES/README.md` · `.agents/skills/galdr-ymirsystem/assets/smidja.md`
- `apps/smidja/smidja_modules/agent_pi.py` (`-ne`) — **untracked: the smithy is gitignored (fault 2)**
- `docs/fixes/smidja/unversioned-2026-10-23-the-panel-showed-nothing.md`
- the trace: `$YMIR_HOME/smidja/smidja.db` (run `8f110045`)

### Still owed
`apps/smidja/` tracked in git · one resolver for the teams with a `cause:` on empty · one DB path in the
shipped config · `/api/chat/message` 500 ("Völundr (Pi) took too long") · `/api/memory` and `/api/chat`
404 · the Forge's block-scalar parser.
