## install · unversioned · 2026-09-25 — installation stands the local model up

## Why
A fresh seat installed with **no local brain**: `step_models` detected runtimes
and wrote a placeholder (“Brokk: search the web and record the exact flags”) and
stopped. The Allfather's law (plan 57): installation must install llama.cpp,
choose the best model for **the user's** hardware, download it, run the
model-testing bench for tuning, wire pi, and register the model with Ymir — so a
seat comes up whole, not with a research note.

## What
- **`bin/llama-ensure.sh`** — ADOPTS a standing CUDA `llama-server` (proves
  `CUDA0` via `--list-devices`), and only builds with `GGML_CUDA=ON` when none
  exists. A CPU-only build is a loud refusal unless `YMIR_LLAMA_CUDA=off`.
- **`bin/model-fit.sh`** — chooses the largest candidate in the hoard model
  catalog that fits the **probed** GPU/VRAM/RAM/disk. Never this box: hardware is
  read at run time, and `--profile FILE` takes a synthetic profile so two machines
  provably choose two models with the tree untouched.
- **`bin/model-fetch.sh`** — resumable (`curl -C -`), checksum-verified,
  consent-first download into the hoard models dir. A missing checksum is a loud
  refusal (`YMIR_ALLOW_UNVERIFIED=1` is the explicit override).
- **`bin/pi-model-wire.sh`** — installs pi when absent, writes the chosen model
  (exact served id, including its `@quant`) into `~/.pi/agent/models.json` with the
  provider key held in `~/.pi/agent/auth.json` (a reference, never a tree value),
  and proves it with a one-shot `pi -p --model … "reply OK"`.
- **`bin/model-register.sh`** — writes the SAME model into the hoard
  `config/agents.<host>.yaml` overlay (`default_model` + `providers:`), so Ymir and
  Smíðja share ONE model road resolved by `bin/agents-config.sh`. The operator's
  annotated base `agents.yaml` is never rewritten.
- **`bin/model-tune.sh`** — drives the modeltesting skill's `bench-one.sh` /
  `bench-ctx.sh` on the host and REPLACES the placeholder in
  `data/local-models.md` with measured settings.
- **`bin/ymir-install.sh`** — a new `step_local_model` after `models`,
  consent-aware and idempotent: adopt-first, nothing downloaded when a local rail
  already serves models, `--skip-engines`/`YMIR_SKIP_LOCAL_MODEL` honored, loud
  refusals for no CUDA / unknown hardware / no disk / bad checksum. A
  `local-model` row is added to `bin/ymir-plan.sh`.
- **`--omarchy-first`** — a new installer option that raises the Omarchy layer
  (`step_omarchy`) **before** the core, for a user who does not have Omarchy yet.
  It does not install the Omarchy OS (upstream); it runs `bin/omarchy-install.sh`
  first, then the core. Without the flag the layer runs last. Documented on the
  homepage (`README.md`) and in the planning/installation doc
  (`galdr-ymirsystem/assets/installation.md`) and the Omarchy owning asset
  (`ymir-host/assets/omarchy.md`).
- **`config/model-catalog.yaml.example`** — the tracked template (seeded into the
  hoard as `config/model-catalog.yaml`); the runtime reads the hoard copy.
- Assets updated: Galdr `installation.md` (steps table + counts) and
  `local-models.md` (§7 the install road).

## One model road
Plans **56 and 57** ride one change: 56 built the single resolver road (models,
env, fallbacks from the hoard — `docs/fixes/smidja/002-hoard-driven-models.md`),
and 57 builds the install step ON that road. No second translation table.

## Proof (on this host)
- `bin/llama-ensure.sh status` → adopts `/usr/local/bin/llama-server`, CUDA0.
- `bin/model-fit.sh` → `large-moe-35b` for the A5000; `--profile` small/big →
  `small-4b` / `xl-70b` (genericity).
- `bin/ymir-install.sh --check` → `local-model OK "rail serves models — would
  register llama-swap/qwen3.6-35b-a3b@q4_k_xl-mtp"`.
- `bin/ymir-plan.sh --phase 4` → `local-model SKIP "a CUDA llama-server stands"`.

### Files
- `bin/llama-ensure.sh`, `bin/model-fit.sh`, `bin/model-fetch.sh` — new.
- `bin/pi-model-wire.sh`, `bin/model-register.sh`, `bin/model-tune.sh` — new.
- `bin/ymir-install.sh` — `step_local_model`, wired after `step_models`; and the
  `--omarchy-first` option (raise the Omarchy layer before the core).
- `bin/ymir-plan.sh` — a `local-model` row.
- `README.md` — the homepage: `--omarchy-first` for a user without Omarchy.
- `config/model-catalog.yaml.example` — the tracked catalog template.
- `.agents/skills/galdr-ymirsystem/assets/installation.md` — usage, the
  `--omarchy-first` subsection, the steps note.
- `.agents/skills/galdr-ymirsystem/assets/local-models.md` — §7 the install road.
- `.agents/skills/ymir-host/assets/omarchy.md` — the layer-first note.
- `docs/fixes/smidja/002-hoard-driven-models.md` — the plan-56 road this builds on.
