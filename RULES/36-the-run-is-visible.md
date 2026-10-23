# Rule 36 — the run is visible, or it did not happen

> Adopted 2026-10-23, at the Allfather's word while looking at a real run in the Smíðja:
> *"we shoulw allways see this Smíðja … this are a rule"*.

## The law

1. **Every agent run appears in the Smíðja** — a session, its **phases**, the **agent lane** it ran
   (agent · model · coding agent), its **events**, and its **verdict**. The trace is the record: a run
   that leaves no trace is a run nobody can see, and a *failure* that leaves no trace is worse than the
   failure.

2. **One writer, one database.** The trace lives in the home (`$YMIR_HOME/smidja/smidja.db`). The
   **factory or the spawn writes it**; the visualizer and every reader door read **that same file**.
   Hand-written rows are a claim with no writer — never a fix.

3. **The team comes from the roster YAML.** A factory run reads
   `apps/smidja/smidja_smidja_config/smidja.config.yaml`; the picker falls back to `config/agents.yaml`
   (the fleet's figure → model). A fourth format is not a team, it is another place to be out of date.

4. **The invocation is `uv`.** `uv run apps/smidja/smidja_*.py <prompt> --config <config>` **from the
   repo root** — the config's prompt and data paths are root-relative, so a run started from `apps/`
   resolves `apps/apps/…` and dies at validation. A run started any other way is not one the house can
   reproduce.

5. **pi starts with `-ne` inside a worktree**, and the extensions the run *declares* are added with
   `-e`. Measured 2026-10-23: a worktree carries its own `.pi/extensions/ymirhome.ts`, and pi refuses
   when it collides with the seat's registered copy (`Tool ymir_find conflicts with …`) — that refusal
   killed every builder turn (run `dae6d893`: 2 phases, 17 events, **fail in 8.1s**) and every errand
   before it.

6. **A failure shows its cause in the panel**, and an empty panel names its cause. `fail` alone is a
   mystery; `fail — pi refused: extension conflict` is a ticket.

7. **Nobody patches the screen.** A row written by hand to make the panel look right is the same fault
   as a mocked test: it proves the *display*, not the system.

## Why

Because the operator's only question in front of the Smíðja is *"what is happening?"* — and on
2026-10-23 the honest answer was "three agents are running, burning tokens, and the panel is empty".
The trace, the roster and the invocation are the three things that make the answer true; each of them
was broken, silently, and each broke the panel's honesty in a different way.

## Enforcement

| gate | refuses |
|---|---|
| `bin/desktop/smidja-observe.sh` | a trace it cannot read — and it must read the same DB as the visualizer |
| a run's own phases | a run that ends with no phase and no verdict |
| `bin/gates/guards.sh` | the tree faults that make a run invisible (extension collision, stale register) |
| this rule's own smoke (owed) | an empty `/api/rosters`, `/api/models` or `/api/memory` that names no cause |

---

## Appended 2026-10-23 (later that evening) — what the first real run taught this rule

The rule was written while a run was visible for the first time. Four things that made the *previous*
seven hours invisible are now part of the law, because each one is a way the panel can lie without a
single line of code being wrong.

### 1 · A factory that is not in git cannot ship, so it cannot run anywhere but here

```
.gitignore:174   apps/smidja/
```

The smithy — its config, its prompts, its modules — is **gitignored**. Measured: the roster names
`apps/smidja/smidja_data/prompt_engineering/{planner,builder}/{system,user}.md` and
`…/harness_engineering/subagents.ts`; **none of them exists in git, and the template ships none of
them either.** A fresh clone therefore cannot start a single run: validation refuses before the first
phase. This rule's §1 is unenforceable on any seat but this one until `apps/smidja/` is tracked
(`git add -f`, or the ignore removed with a dated reason).

### 2 · The teams had three names and the UI read the one that did not exist

`.agents/agents/*.md` (23 figures) · `config/agents.yaml` (figure → model) · `roster.yaml` (what the
picker reads — **absent everywhere**). And `/api/rosters` answered `[]` because the server derived the
**repo root from the database path** (`rosterRootOf(dbPath)`), while the DB lives in the home by
design. So the "Choose a team…" list was empty for a reason no one could see. Rule 36 §3 stands; the
mend is one resolver with a **stated fallback** to `config/agents.yaml` and a `cause:` in the payload.

### 3 · One database, or two doors describe two houses

The factory's config said `db: apps/smidja/smidja_data/smidja.db` while the visualizer read
`$YMIR_HOME/smidja/smidja.db` — so a real run wrote a trace **the panel could not see**, and
`smidja-observe.sh` said *"absent"* over four runs. Tonight the run used a local config override
(`smidja.local.yaml`, `db:` → the home) so the trace landed where the UI reads it. **That override is
the workaround, not the rule:** the shipped config must name the home's DB, and every reader must
resolve it through the same door.

### 4 · The chat door and the empty picker are part of this rule, not a separate fault

```
POST /api/chat/message → 500 {"error":"Völundr (Pi) took too long — try again"}
GET  /api/rosters      → []
GET  /api/models       → []
GET  /api/memory       → 404   ·   GET /api/chat → 404
```

A panel that cannot answer, cannot list a team and cannot say why is the same fault as a run that
leaves no trace: **the operator's question "what is happening?" has no honest answer.** Under this rule
each of these answers either a value or a `cause` — never a bare empty.

### 5 · What the fix proved, and how

```
pi -ne  (agent_pi.py)     run dae6d893: 2 phases · 17 events · fail in 8.1s   →  extension conflict
pi -ne  (same)            run 8f110045: 01 request success · 02 build RUNNING · builder on the rail
uv run apps/smidja/smidja_build.py … --config apps/smidja/smidja_smidja_config/smidja.local.yaml
                          invoked FROM THE REPO ROOT — from apps/ the config's root-relative paths
                          resolve apps/apps/… and validation refuses (§4 of this rule)
```

**The flag and the working directory were the whole difference between "no agent activity yet" and a
builder lane on the rail.** A rule that does not name its own invocation is a rule someone will get
wrong at 3am — so this rule names it, with the failure each way it can be got wrong.

---

## Correction, appended 2026-10-23 — I claimed the smithy was not in git. It is. I had not read its own docs.

The Allfather: *"what.. are the apps not getting pushed to git? have you even read this docs____??
apps/smidja-factory/cookbooks · apps/smidja-factory/skills"*. He was right on both counts.

**Measured after reading them:**

```
git ls-files apps/ | tracked files:  smidja 34 · smidja-factory 229 · hlidskjalf 175 · odrerir 37 · sessrumnir 395
ignored (by design):                 apps/smidja/smidja_data/  ·  apps/smidja.db*        (.gitignore:100-101)
```

So §1 of the earlier appendix was **wrong**: the smithy *is* tracked; only its **runtime data** is
ignored. The prompts live under `smidja_data/` because they are *run data*, not repo content — a
distinction the cookbooks state and I did not read before asserting otherwise.

**What the docs say, and what this seat actually has — four disagreements:**

| the docs (cookbooks/ + skills/) | this seat |
|---|---|
| `roster.yaml` is **the ONE config**: teams in `stacks:`, roles in `role_defaults:`, models in `tiers:` (`skills/create-new-teams`, `skills/smidja-start`) | `apps/smidja/smidja_smidja_config/` holds **only `smidja.config.yaml`** with an `agents:` list — **no `stacks:` at all**. There are no teams to choose, which is why the picker is empty — not only an API bug |
| `just rosters` · `just sdlc` · `just sessions` · `just obs` (`justfile` at the repo root) | **`just` is not installed** — none of the documented recipes can run |
| `START_SMIDJA.md` is the canonical playbook at the repo root (`skills/smidja-start`) | **absent** |
| `uv run smidja/<chain>.py …` from `~/Ymir` (`cookbooks/run_smidja.md`) | the chains live at `apps/smidja/`, and the config's paths are root-relative — so the invocation is `uv run apps/smidja/smidja_*.py …` from the repo root (§4 above), which the cookbook predates |

**What this changes in the law:** §3 of this rule stands and gets stronger — *the team comes from the
roster YAML* means the file the docs name, with a `stacks:` block. A `smidja.config.yaml` that carries
only `agents:` is a **roster with no teams**, and a picker over it can only be empty. Creating that file
is a decision the operator makes with the `create-new-teams` skill's questions — purpose, surface
(local/cloud/hybrid), the agents, and the model each agent runs — never a guess by the agent.

---

## Appended 2026-10-23 — the smithy's own books are load-bearing, and they are named here

The Allfather: *"append to the rule and the system — this are critical skills and cookbooks."* They are,
and this rule is where a hand is told so **before** it touches the Smíðja.

**Two shelves, both under `apps/smidja-factory/`, both read before any change to the smithy:**

```
cookbooks/ (9)                              skills/ (9)
  smidja_overview.md                          smidja-start/            the exact way to put agents to work
  run_smidja.md                               smidja-launcher/         raise it, watch it
  create_smidja.md                            smidja-instructions/     the operating instructions
  create_config.md                            how-to-run-agent-teams/  teams in practice
  update_config.md                            create-new-teams/        a team = a `stacks:` block (interview first)
  update_smidja.md                            create-new-agent/        one new role
  update_modules.md                           add-or-edit-ai-models/   models, prompts, injection
  install.md                                  git-ops/                 branch/commit/push discipline
  how_to_prompt_for_the_eng.md                volundr/                 the master craftsman
```

**The law that makes them load-bearing:**

1. **Read the book before the code.** A change to the Smíðja — a chain, a roster, a prompt, a module, an
   invocation — starts by reading the matching cookbook or skill. This rule's own correction exists
   because that step was skipped: I claimed the smithy was untracked without opening
   `cookbooks/install.md`.
2. **They are the authority on the smithy, in this order:** the skill (`skills/smidja-start`) for *how to
   run*, the cookbook (`cookbooks/run_smidja.md`) for *what to say*, the config (`roster.yaml`) for *who
   runs it*. A doc that disagrees with the tree is a **ticket**, not an excuse to improvise — four such
   disagreements were found and named on 2026-10-23.
3. **A team is not improvised.** `skills/create-new-teams` says it plainly: a team is a `stacks:` block
   in `roster.yaml`, made by **interviewing the operator** (purpose · local/cloud/hybrid · the agents ·
   the model each runs). An agent that guesses a team has made a roster nobody asked for.
4. **The orchestrator launches and observes; it never implements** (`cookbooks/run_smidja.md`). Stepping
   into the work is the failure this whole rule exists to make visible.
5. **When the books and the tree disagree, the books are the specification and the tree is the defect** —
   unless the book itself predates a move, which is also a ticket (the cookbook still says
   `uv run smidja/…`; the chains now live in `apps/smidja/`).

---

## Appended 2026-10-23 — the books are MANDATORY, and a missing book is a stop, not an improvisation

The Allfather: *"this can never happend that we are missing this for the smidja ever again… append to the
rules."* So it is a numbered clause of this rule, with a door and a ward behind it.

**§9 · Before any change to the smithy, the books are read — in this order:**

```
1  apps/smidja-factory/SKILL.md        the entry: what the smithy is, what loads when
2  apps/smidja-factory/AGENTS.md       the canonical doc: runtime, rosters, routing table, hard rules
3  apps/smidja-factory/cookbooks/      9 books: overview · run · create/update chain · config · modules · install · prompting
4  apps/smidja-factory/skills/         9 skills: start · launcher · instructions · agent-teams · new-teams · new-agent · models · git-ops · volundr
5  apps/smidja-factory/docs/ · references/   the deep specs (roster/model source of truth, handoff, observability)
```

**Ask, do not remember:** `bin/records/where.sh apps/smidja` prints the entry, the canonical doc, the
books, the doors **and what this tree is missing**. `bin/records/where.sh --check` proves every book the
map names exists.

**A missing book is a STOP, not an improvisation.** The map's `missing` cell names what the books promise
and this tree does not have (measured 2026-10-23: `scripts/smidja` — the launcher with <!-- stale-ok: named as MISSING by this rule; the launcher the cookbooks promise does not exist on this seat (ticket: the broken board) -->
`rosters|team|doctor` · `roster.yaml` with `stacks:` · `justfile` · `tests/local-models/`). The correct
move is a ticket and, if the work cannot wait, the smallest honest thing — **never** a hand-made stand-in
for the missing piece (the night of 2026-10-23 produced three: hand-written trace rows, hand-written agent
prompts, and an ad-hoc launcher invocation).

**The ward:** `bin/gates/guards/subsystem-docs-guard.sh` — in `bin/gates/guards.sh` — refuses a map row
that names a book which does not exist, and refuses a **governed path in AGENTS.md with no row in the
map**. A path with no book is how a night gets lost; a book that does not exist is worse than none.

**The map:** `.agents/assets/agents/subsystem-docs.md` — one row per subsystem: path · entry · canonical
doc · books · doors · missing. It is the only place a hand is told what to read, so it is checked, not
trusted.
