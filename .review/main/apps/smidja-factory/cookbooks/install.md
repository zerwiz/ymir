# Install

`/smidja install` — stamp the entire smidja out of the skill and into the current working directory.

## Run it

```bash
uv run .claude/skills/smidja/scripts/install.py
```

Run from the **target repo root** — the cwd is where everything lands. If the skill lives in your user scope, the path is `~/.claude/skills/smidja/scripts/install.py`.

## What gets stamped

`install.py` copies `templates/` into the cwd:

| Stamped | From | Tracked? |
|---|---|---|
| `smidja/smidja_smidja_config/smidja.config.yaml` | `templates/smidja.config.yaml` | yes — the agent roster |
| `.env.sample` | `templates/env.sample` | yes |
| `smidja/smidja_*.py` | `templates/smidja/` | yes — the twelve starter smidja |
| `smidja/smidja_modules/` | `templates/smidja/smidja_modules/` | yes — all low-level logic |
| `smidja/smidja_data/prompt_engineering/{planner,builder,scout,reviewer,documenter}/` | `templates/prompt_engineering/` | yes — **the user-owned home for prompts** |
| `smidja/smidja_data/harness_engineering/` | `templates/harness_engineering/` | yes — **the user-owned home for pi extensions** |
| `justfile` | `templates/justfile` | yes — starter recipes: `just demo`, the workflows, the trace reads, `just obs` |
| `smidja/smidja_data/sessions/`, `smidja/smidja_data/smidja.db` | created at runtime | no — gitignored |

The two `*_engineering` dirs mirror the two config keys of the same name: `prompt_engineering` is what an agent is told, `harness_engineering` is what its harness can do. Both are yours the moment they are stamped. Edit them in `smidja/smidja_data/`, never back inside the skill.

`harness_engineering/` ships with `subagents.ts` — the pi extension backing `subagent_create` / `_continue` / `_list` / `_remove`, wired to the planner and scout in the starter roster.

## Idempotency

Re-running is safe. `install.py` skips **every** file that already exists — your config, your prompts, and previously stamped code alike — and reports what it skipped, so a second run doubles as a drift check. To refresh stamped code (`smidja_modules/`, the starter `smidja_*.py`) to the skill's current version, run with `--force` — but know that `--force` overwrites ALL existing stamped files, including `smidja.config.yaml` and `prompt_engineering/`, so commit or back up user-owned edits first.

## Post-install checklist

1. **Env** — `cp .env.sample .env`, then set `OPENROUTER_API_KEY` in `.env`. (v1 runs Pi; `ANTHROPIC_API_KEY` / `CLAUDE_CODE_PATH` are only needed once Claude Code lands in v2.)
2. **Pi is installed and on PATH** — `pi --version`. Set `PI_PATH` in `.env` if it is not.
3. **The model resolves** — the config's default `gemini-3.6-flash` must be a registered id in `~/.pi/agent/models.json`. Check with `pi --list-models` or read the file directly; see `references/config.md` for model resolution.
4. **Gitignore** — `install.py` appends `smidja/smidja_data/sessions/`, `smidja/smidja_data/smidja.db*`, and `.env` for you; confirm they landed. All three are runtime or secrets and must never be committed.
5. **Git repo** — smidja that end in a commit phase call `git_helper.commit_all`, which raises if the cwd is not a git repository. Run `git init` and make a first commit before using `smidja_plan_build.py`, `smidja_plan_build_test.py`, or `smidja_simple_sdlc.py`. `smidja_document.py` needs one too: it measures the change with `git diff` against a base ref (`main` by default, `--base` to override).
6. **Smoke test** — `just demo` runs two cheap read-only workflows back to back, or run the smallest smidja directly:

```bash
just demo                                                    # both, end to end
uv run smidja/smidja_prompt.py "reply with a one-line summary of this repo"   # the raw form
```

Green means the whole path works: config validated, session minted, Pi ran, envelope parsed, events landed in `smidja/smidja_data/smidja.db`. Verify the trace exists before trusting anything larger:

```bash
sqlite3 smidja/smidja_data/smidja.db "select smidja_id, status from sessions order by started_at desc limit 1;"
```

If the smoke test fails, fix it before composing chains — every multi-agent smidja rides on this exact path.
