## smidja · unversioned · 2026-09-25 — every model and env comes from the hoard (the fallback clause)

**Problem.** The public tree pinned concrete model IDs in the smidja roster, the
factory template, agent profile front-matter, and the seat scripts' fallbacks —
`llama-cpp/qwen3.6-35b-a3b@iq3_s`, `google/gemini-3.6-flash`, `flash-next/qwen3.8-flash-next`,
`fireworks/…/kimi-k3`, `openai/gpt-5.6-*`, and `${VAR:-<concrete id>}` chains.
The Allfather's law, with the fallback clause appended: **all models and env come from
the hoard, YAML-driven per user; no `${VAR:-<concrete model id>}` anywhere; the fallback
chain resolves from the hoard `agents.yaml` (with the per-host overlay) then the
environment; a missing model at the end is a LOUD refusal naming the key and the file.**

## 56 — the single resolver road

1. **`.agents/agents/*.md` (20 figures)** — dropped the `model:` front-matter. The
   dispatch road resolves each figure's model from the hoard by figure name via
   `bin/agents-config.sh get <figure> model`.
2. **`bin/agents-config.sh`** — `apply` no longer rewrites tracked `.agents/agents/*.md`;
   added a `default [--provider|--model|--harness]` verb; `get` now ignores a stale
   resolved cache (cache mtime must beat the hoard YAML) so an old model cannot be served.
3. **`apps/smidja/smidja_smidja_config/smidja.config.yaml`** +
   **`apps/smidja-factory/templates/smidja.config.yaml`** — every `model:` is an empty
   env placeholder (`${SMIDJA_LOCAL_MODEL:-}`, `${SMIDJA_<ROLE>_MODEL:-${SMIDJA_LOCAL_MODEL:-}}`).
   The template ships placeholders only.
4. **`apps/smidja/smidja_modules/agents.py`** (+ the factory template copy) — `load_config`
   now fills empty roster models from the hoard: env first (expansion), then the hoard
   `default_model` / `smidja_roles:` via `bin/agents-config.sh default`, then a loud
   refusal in `validate` naming `SMIDJA_LOCAL_MODEL` and the hoard `agents.yaml`.
5. **`bin/research-round.sh`** — the last-resort literal became a loud refusal; the chain
   is `--model` → `agents-config.sh get <figure> model` → refuse.
6. **`bin/snotra-transcribe.sh`** — `RAIL_MODEL` default emptied; added a loud refusal
   naming the key.
7. **`bin/pi-agent.sh` / `bin/pi-local.sh` / `bin/pi-seat.sh`** — provider and model
   resolve from the hoard (the figure's own model, else `default_model`); the
   `PI_LOCAL_PROVIDER:-llama-cpp` literal is gone.
8. **Docstrings/AGENTS.md examples** (`agents.py`, `apps/smidja-factory/AGENTS.md`) —
   updated to the empty-placeholder convention.

## 57 — installation stands the local model up (see `docs/fixes/runtime/`)

Built on that road: `bin/llama-ensure.sh` (adopt-or-install a CUDA `llama-server`,
`CUDA0` proved), `bin/model-fit.sh` (best model for the probed hardware, generic),
`bin/model-fetch.sh` (resumable, checksummed, consent-first), pi wiring
(`~/.pi/agent/models.json` + one-shot proof), ymir registration (the same model into
the hoard `agents.yaml`), and `bin/model-tune.sh` (the modelfesting bench writes the
tuned row).

## Proof

```
# (a) no `${VAR:-<concrete model id>}` remains in the model/env road:
$ grep -rn ':-[A-Za-z0-9._/-]*\(qwen\|gemini\|gpt-\|kimi\|deepseek\|llama-\|fireworks\|openai\|claude\|@q[0-9]\)' \
    --include='*.sh' --include='*.yaml' --include='*.py' --include='*.ts' \
    bin/ apps/smidja apps/smidja-factory/templates
(no output — NONE)

# (b) two synthetic user YAMLs yield two rosters, tree untouched:
$ YMIR_AGENTS_YAML=/tmp/userA.yaml ... load_config → planner: llama-swap/model-A-7b@q4_k_m
$ YMIR_AGENTS_YAML=/tmp/userB.yaml ... load_config → planner: llama-swap/model-B-70b@q8_0

# (c) the Allfather's own hoard resolves live:
$ bin/agents-config.sh default
llama-swap/qwen3.6-35b-a3b@q4_k_xl-mtp
```

Concrete model strings left in the tree are only docstring/UI examples
(`apps/hlidskjalf/server/index.ts` pricing, the visualizer's model catalog, docstring
examples in `agent_pi.py`/`model-resolve.sh`) — documentation and UI data, never the
model/env road, never a fallback.

**Files changed:** `.agents/agents/*.md` (20) · `bin/agents-config.sh` ·
`bin/research-round.sh` · `bin/snotra-transcribe.sh` · `bin/pi-agent.sh` ·
`bin/pi-local.sh` · `bin/pi-seat.sh` ·
`apps/smidja/smidja_smidja_config/smidja.config.yaml` ·
`apps/smidja-factory/templates/smidja.config.yaml` ·
`apps/smidja/smidja_modules/{agents,data_types}.py` ·
`apps/smidja-factory/templates/smidja/smidja_modules/{agents,data_types}.py` ·
`apps/smidja-factory/AGENTS.md` · `.agents/skills/galdr-ymirsystem/assets/smidja.md`.

### Files
- `.agents/agents/*.md` (20) — dropped the pinned `model:` front-matter.
- `bin/agents-config.sh` — `default`/`provider-url` verbs; `apply` no longer rewrites
  tracked agent files; `get` ignores a stale resolved cache.
- `bin/research-round.sh`, `bin/snotra-transcribe.sh`, `bin/pi-agent.sh`,
  `bin/pi-local.sh`, `bin/pi-seat.sh` — fallbacks emptied; resolve from the hoard or
  refuse loudly.
- `apps/smidja/smidja_smidja_config/smidja.config.yaml`,
  `apps/smidja-factory/templates/smidja.config.yaml` — empty env placeholders.
- `apps/smidja/smidja_modules/{agents,data_types}.py` and the factory template
  copies — hoard resolution + empty defaults + loud refusal.
- `apps/smidja-factory/AGENTS.md` — placeholder convention.
- `.agents/skills/galdr-ymirsystem/assets/smidja.md` — the roster/models section.
