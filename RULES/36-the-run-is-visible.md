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
