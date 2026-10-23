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
