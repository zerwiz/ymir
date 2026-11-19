## smidja · unversioned · 2026-11-19 — the runner returns, and every harness can drive the smithy

### Why
The smithy's books (9 cookbooks, 9 skills) teach one front door, `scripts/smidja`, with about 30 verbs. That launcher, with `roster.yaml`, `START_SMIDJA.md` and its helper scripts, was lost in an earlier port: it is not on heimdall, not in Ymir's history, not in the old `zerwiz/smidja` repo and not in the legacy archive. Agents could reach the smithy only by hand-running `uv run …` or `just …` (and `just` is not installed). The Allfather, 2026-11-18/19: *"rebuild it. every computer and users have different environments … if user have ssh it should be functional to run smidjas from different computers"*, *"i wanna the smidja to work with all my tools. claude. codex. pi. hermes. opencode"*, *"they need to be connected to the mcp so i can run the smidja from them"*, and *"only pi harness inside the smidja … other harnesses are able to run the smidja"*.

The first real run through the new door then exposed three faults that would have stopped any run on any machine, so they are mended in the same change.

### What was built
- **One library, three doors** — `apps/smidja-factory/runner/smidja_runner/` (stdlib only): `paths` (where the engine, config, trace and viewer are, probed), `trace` (the viewer's own reads and signals, without needing the viewer), `verbs` (every verb the books teach), `remote` (`--on <host>` over ssh, and the viewer through an ssh tunnel), `cli` and `mcp_server`. The doors are `scripts/smidja` and `scripts/smidja-mcp` in the factory, and `scripts/smidja` in Ymir's root as a pointer.
- **The MCP** — 18 tools; every one is a command line handed to the same `cli.execute`, and every one takes `on`.
- **The doors installer** — `apps/smidja-factory/scripts/install-doors.py`: links `smidja`/`smidja-mcp` into `~/.local/bin`, names `smidja` in pi's MCP set, and runs the house's seating door so Claude Code, Codex, OpenCode, Cursor and Hermes carry it. `step_smidja` in `bin/engine/ymir-install.sh` runs it from the pin.
- **Only pi inside** — `doctor` and `rosters` name any agent whose `coding_agent` is not pi.

### Faults found and mended
1. **Every agent phase died** on `'Run' object has no attribute 'context_by_phase'`. Commit `13b58d605` added the context receipts to `agents.py`, `runner.py` and `data_types.py`; a later rewrite of `runner.py` and `data_types.py` dropped their half and kept `agents.py`'s. Restored exactly as `13b58d605` wrote them (the receipt, `context-pressed`, and `finish()` settling db, banner and exit code together), plus `PiResult.last_usage` / `last_finish`, which `agent_opencode` and `agents._execute` both write.
2. **The engine had drifted from the templates the installer stamps** (six modules differ, `context.py` and `smidja_trace.py` only in the engine), so the first install after the split would have dropped that work. Folded back: `templates/smidja` is now byte-identical to `apps/smidja` (`test_resume.ShippedCopyTest` is green).
3. **Two trace paths** — the config named `apps/smidja/smidja_data/smidja.db` while the viewer reads `$YMIR_HOME/smidja/smidja.db`, so a run was invisible. The config now reads `${SMIDJA_DB:-…}` and `${SMIDJA_DATA_DIR:-…}`, and the runner sets both to the viewer's trace.
4. **No prompts on a fresh tree** — the agents' prompt files live in the untracked `smidja_data/`, so no run could start on a new clone (the pin on heimdall had none either). `smidja up` stamps every MISSING file from the factory's templates and never overwrites one.

### Proof
- `apps/smidja-factory/runner/tests/test_runner.py` — 19 tests, every path fenced (SMIDJA_DB, HOME): the done-means refusal, the kill-switch, stop/pause/continue/steer/emergency-stop on real child processes, a recycled pid never signalled, the zero-tool-call flag, the MCP's list and call, and **every verb the books teach is a verb the runner answers**.
- `apps/smidja-factory/tests` — 31 passed; `tests/test_smidja_trace.py` — 12 passed.
- A real run on heimdall: `smidja run scout "…Done means: …" --model opencode-go/deepseek-v4.1-flash` → run `decd02dd`, `success`, 15 tool calls, gate `artifacts_exist` passed, findings filed. (The run before the mend, `bd78ed7a`, did the work and died on fault 1.)
- `install-doors.py` in a fenced HOME: `--check` names the drift, a seat adds `smidja` beside the existing servers, a second `--check` is clean; `mcp-config.sh harness claude|codex|opencode` then renders the `smidja` server for each.

### Not yet proven
- `--on <host>` against a second machine: this errand had no ssh. Owed before the smithy leaves Ymir.
- Seating the live harnesses: done by install/update from the pin once this lands (Hermes refuses a door that names a working tree, rightly).
