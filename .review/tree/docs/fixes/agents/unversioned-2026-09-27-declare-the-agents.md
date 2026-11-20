## agents · unversioned · 2026-09-27 — declare the agents: the wiring is data, the model is the hoard's

### Why

Plan 58, Phase 4 — DECLARE THE AGENTS. The model half landed in PR #203: 20
figure cards lost their pinned `model:`, and dispatch resolves each figure's
model from the hoard (`config/agents.yaml`, with the per-host overlay) by figure
name. What remained undeclared was the rest of the shape the plan's folder tree
names: **role → figure → tools** was still a heredoc inside
`bin/eindri-role.sh`, and two cards (`brokk`, `galdr`) carried no `role`/tool
frontmatter at all. A decision table belongs in data, not in a script.

### The change

1. **`.agents/roles.yaml` is the decision table.** One row per role —
   `figure`, `craft`, `dispatch`, `keywords`, `tools` (and `skills` where the
   figure owns one) — for all 21 figures. It names the file that declares the
   model (`model_from: hoard`) and pins no model itself.
2. **`bin/eindri-role.sh` reads it** (1.0.0 → 1.1.0): `list`, `choose` and `for`
   are unchanged in shape and, for the nine dispatch roles, **byte-identical in
   output** — the table was moved, not retuned. `for` now also accepts a role
   key as well as a figure short name. The bare `list` count is now the table's
   own length (it had hardcoded `8` for nine rows).
3. **`bin/agents-config.sh` gains `roster`** (1.0.0 → 1.1.0): it joins
   `roles.yaml` to the hoard and prints
   `role → figure → harness → model → tools`. Two hoard YAMLs yield two rosters;
   the tracked tree never moves. `show`/`apply`/`get`/`resolve` are untouched.
4. **Every card carries role and tool refs, and no model.**
   `brokk.md` and `galdr.md` gained `role`, `norse_name`, `descriptor`,
   `capabilities`, `ymir_tools` (and `workspace_patterns`/`security` for brokk,
   `skills` for galdr), matching the 19 cards that already had them.
   `galdr.md` is the agent mirror of its skill, so the same block is added to
   `.agents/skills/galdr-ymirsystem/SKILL.md` — the two stay byte-identical (the
   `surfaces` gate now PASSes). `elder.md` was **malformed**: its frontmatter had
   no closing `---` and no prose body, so PyYAML and the Pi subagent scanner both
   failed to resolve it. The delimiter and a short body are restored, and its
   five harness symlinks (`.pi`/`.opencode`/`.claude`/`.codex`/`.cursor`
   `agents/elder.md`) are bound so all 21 figures load. No card carries `model:` or
   any concrete model token, in frontmatter or prose.

### Honesty — what this PR covers, and what it does not

- **Retiring apply-writes was already done in #203.** `bin/agents-config.sh
  apply` writes the harness's *own* config (`opencode.json`, untracked) and the
  state cache; it has **no code path that writes `.agents/agents/*.md`** (verified
  by grep and by the tree-untouched proof below). This PR adds the resolver
  (`roster`) and the data (`roles.yaml`) that make the declaration complete, and
  documents the invariant; it does **not** rewrite `apply`, so the roster
  produces identical output by construction.
- **`roles.yaml` is read, not enforced.** It is deliberately not a JSON-Schema
  gate — that is Phase 7 (SCHEMA THE CONFIG). A missing roles file makes
  `bin/eindri-role.sh` and `bin/agents-config.sh roster` refuse loudly; a bad one
  is caught by the YAML parse check, not yet by a schema.
- The `herder` token in the cards' `ymir_tools` (vs the engine's `herdr`) is
  mirrored verbatim, not renamed — a rename is its own change.

### Proof (run live on this seat)

```
# two synthetic hoard YAMLs -> two rosters, tree untouched
YMIR_AGENTS_YAML=/tmp/hoard-a.yaml bin/agents-config.sh roster  -> "...llama-swap/model-a" x21
YMIR_AGENTS_YAML=/tmp/hoard-b.yaml bin/agents-config.sh roster  -> "...llama-swap/model-b" x21
git status --porcelain .agents/agents        -> only the authored card edits, never a roster write
bin/agents-config.sh apply                   -> cards before == cards after (apply writes no card)

# the chooser is unchanged for the same input
old vs new bin/eindri-role.sh choose "<task>" -> identical row for 13 task strings

# the loader still binds, and the harness registry resolves figures
bin/valknut-load.sh --all                    -> pi-local bound (21 links); .opencode/.claude/.codex/.cursor bound (21)
ls -l .pi/agents/sindri-developer.md         -> ../../.agents/agents/sindri-developer.md
ls -l .opencode/agents/sindri.md             -> ../../.agents/agents/sindri-developer.md
subagent list                                -> 21 figures, all with name+description
bash .agents/skills/galdr-ymirsystem/scripts/compliance-check.sh -> 15/15 PASS
bash bin/npm-pretest.sh (NPM_PRETEST_SKIP_REMOTE=1) -> PRETEST PASS
```

`bin/pr-pretest.sh` itself hangs on its `local` sub-leg in this seat's sandbox
(a pre-existing quirk, unrelated to this change); the underlying
`bash bin/npm-pretest.sh` with the remote leg skipped reaches `PRETEST PASS`,
which is the local truth the gate exists to prove.

### Files

- `.agents/roles.yaml` (new)
- `bin/eindri-role.sh`
- `bin/agents-config.sh`
- `.agents/agents/brokk.md`, `.agents/agents/galdr.md`, `.agents/agents/elder.md`
- `.agents/skills/galdr-ymirsystem/SKILL.md` (the galdr agent's mirror)
- `.pi/agents/elder.md`, `.opencode/agents/elder.md`, `.claude/agents/elder.md`,
  `.codex/agents/elder.md`, `.cursor/agents/elder.md` (the 21st binding)
- `.agents/skills/galdr-ymirsystem/assets/installation.md`
- `.agents/skills/galdr-ymirsystem/assets/harness-integration/README.md`

galdr-reread: `installation.md` (the declared-agents surface: `roles.yaml`, the
`roster` verb, and the no-model-in-the-tree invariant), `harness-integration/README.md` §14.
