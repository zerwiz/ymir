---
name: modeltesting
description: "Benchmark and test LLM model backends on zerwiz (Ollama, LM Studio, llama.cpp, Colibri, Unsloth + secondary vllm/llamaswap/tabbyapi-yals). Load-verify-unload each model on a clean GPU, capture prefill/decode/VRAM, then record results into backends-benchmark.md §10.5, the per-backend TESTING.md, AND always update .pi/agent/models.json with the correct contextWindow/processor/VRAM findings. Use when the user wants to test a model, make/re-run a high-context Modelfile, benchmark a backend, or reconcile the pi/Ollama/LM Studio model registry. Test model configs (`ollama show`), build high-ctx Modelfiles (`num_ctx`), and never leave a model resident between runs."
version: "1.0"
allowed-tools: read, write, edit, bash, grep, glob
---

# modeltesting — structural benchmark of LLM backends on zerwiz

Ground truth is **`.agents/skills/modeltesting/backends-benchmark.md`** (this
folder). Every per-backend `TESTING.md` is a working guide grounded in it. This
skill packages the **always-do-these** rules so any run is clean, recorded, and
keeps the pi registry in sync.

> **This skill TESTS. It does not run the service.** It installs the stack
> ([`INSTALL.md`](./INSTALL.md)) and measures models against it
> ([`scripts/bench-one.sh`](./scripts/bench-one.sh) starts its own throwaway
> single-model server). Starting, stopping, or reconfiguring the serving stack
> is machine property, documented with the machine — never here.

## Where things live

| Path | What |
|---|---|
| `.agents/skills/modeltesting/backends-benchmark.md` | source of truth: §3 methodology, §9 MoE, §10 matrix + §10.5/§10.5.1/§10.5.2 results, §12 backends |
| `.agents/skills/modeltesting/<backend>/TESTING.md` | per-backend guide (llamacpp, lmstudio, ollama, colibri, unsloth, llamaswap, vllm, tabbyapi-yals) + its `§8 result` block |
| `.agents/skills/modeltesting/README.md` | index of backends, bench models, shared rules |
| `~/.pi/agent/models.json` | **pi model registry — MUST be updated with every accepted result** |
| `~/.local/share/llama-router/scripts/llama-models.yaml` | **the serving registry — lives ON THE MACHINE, never here** (see the boundary below) |
| [`INSTALL.md`](./INSTALL.md) | **how to install the stack on a machine** — prerequisites, the seat, the CUDA shim, the registry, autostart, verification checklist |
| [`HOST-RUNBOOK.md`](./HOST-RUNBOOK.md) | **what a tester must know about THIS host** — the GPU, the CUDA-vs-CPU trap, warm-up, the verified reference windows, the traps |
| [`DUAL-GPU.md`](./DUAL-GPU.md) | **running both GPUs at once** — the eGPU (CUDA) + internal AMD iGPU (Vulkan), measured solo vs concurrent, and the batch-size trap |

## Boundary — the router is machine property, not skill property

**This skill benchmarks and records. It does not own, host, or document the
serving system.** The router (`llama-router`), the launcher/engine
(`model-host.sh`), the TUI (`llama-menu`), the gateway (`swap-proxy`), the
registry (`llama-models.yaml`), the generated router INI, and their operating
docs live in the machine's own home **outside every git repo**
— here `~/.local/share/llama-router/`. A repo may not hold them.

Add, tune, or operate a model **there**, then record the bench result **here**:

```
boundary[3]{thing,where}:
  "code + registry + config","the machine: ~/.local/share/llama-router/scripts/llama-models.yaml, model-host.sh, llama-router, gen-llama-router-config.py"
  "operating docs","the machine: ~/.local/share/llama-router/docs/ (LLAMA_CPP_SERVER.md, SYSTEM.md, llama-menu.md, swap-proxy.md)"
  "bench method + results","this skill: backends-benchmark.md, <backend>/TESTING.md"
```

A model table kept inside a skill goes stale and forks the truth. Never carry
one here.

## The 8 shared rules — apply to EVERY run

1. **Unload everything between runs.** Never trust cross-session numbers. After
   a run, VRAM must return to the 26 MiB baseline. `ollama stop <model>`
   (needs the model name — `ollama stop` alone errors).
2. **Lock GPU clocks** before a timing run:
   `sudo nvidia-smi -lgc 1900,1900` and `-lmc 7000,7000`.
3. **Warmup** a load and discard it; then run the timed request.
4. **Same seed + temp 0:** `--seed 42`, `--temp 0` (Ollama: `options seed:42,
   temperature:0`).
5. **Verify REAL loaded context** with `ollama ps` (CONTEXT column) — the
   **Context Trap** (§"Ollama Context Trap" in `ollama/TESTING.md`): plain
   models load at **4096** unless the Modelfile sets `num_ctx`. Numbers that
   fail `ollama ps` verification are **discarded**.
6. **Capture GPU during prefill** (parallel `nvidia-smi`) to catch CPU spill
   (e.g. `qwen3-vl:8b-highctx-196k` = 61%/39% CPU/GPU, 37 GB).
7. **Observe the physical reality, don't assert it.** gemma4:e4b clamps at
   131,072 (its native cap) — a 196K Modelfile silently loads at 131,072, not
   196,608. Record what `ollama ps` shows, not what the Modelfile asked for.
8. **Record EVERY accepted result in two places:**
   - `backends-benchmark.md` §10.5 / §10.5.1 / §10.5.2 + the per-backend
     `TESTING.md` `§8` block.
   - **`~/.pi/agent/models.json`** — update the model's `contextWindow`
     (and processor/VRAM notes) to the verified value so pi shows the truth.

## How to run a model bench

Reusable scripts in **`scripts/`** (this folder):

| Script | What it does |
|---|---|
| `scripts/bench-one.sh <model-id> [prompt-json] [max-tokens]` | full end-to-end bench of one llama.cpp model: baseline → load → `/props` ctx verify → warmup → timed run with parallel GPU sampling → results → unload → baseline confirm. Prints the exact lines to record. |
| `scripts/stop-all.sh` | stop **everything** (model-host + Ollama + LM Studio backends), confirm the 26 MiB baseline. Use between runs. |
| `scripts/gpu-sample.sh 2 10 -- <cmd>` | sample GPU util/VRAM every N s while a command runs — catches CPU-spill (util dropping to ~30% while decoding). |

The manual Ollama pattern (same rules, no scripts):

```bash
ollama run <model> --verbose "$(python3 -c 'print(" ".join(["test"]*9800))')"
# then read ollama ps CONTEXT + timing footer
nvidia-smi --query-gpu=memory.used --format=csv,noheader   # before/after
ollama ps                                                    # verify loaded ctx
ollama stop <model>                                          # ALWAYS unload; back to 26 MiB
```

## Create / fix a high-context Modelfile

`ollama create <name> -f ~/Modelfile.<model>` from e.g.
`Modelfile.gemma4-e4b-highctx-131k` or `Modelfile.qwen3-vl-8b-highctx-100k`:

```
FROM <base>:<tag>
PARAMETER num_ctx <target>        # must be <= model native cap (ollama show)
TEMPLATE {{ .Prompt }}
RENDERER <arch>                   # EXACTLY the architecture name, e.g. gemma4, qwen3vl —
                                  # NOT the model id. 'qwen3-vl' as renderer = unknown-renderer 500.
PARSER <arch>
PARAMETER temperature 1
PARAMETER top_k 20
PARAMETER top_p 0.95
```

- Get the true arch: `ollama show <model>` → `architecture` (qwen35, qwen3vl, gemma4).
  **Renderer/parser must match the architecture token**, not the model id.
- After create: `ollama run <new> --verbose "hi"` then `ollama ps` — if CONTEXT
  ≠ what you asked (e.g. gemma4:e4b → 131072 cap), the model **cannot** reach
  that context; record the clamped value.

## Model cap reality on THIS box (as of 2026-09-04)

| Model | native cap | best verified ctx | processor | VRAM | note |
|---|---|---|---|---|---|
| `qwen3.5:9b-highctx-262k` | 262144 | 262,144 | 100% GPU | 14,802 MiB | fits 16 GB; prefill 1,645 t/s |
| `qwen3.5:9b-highctx-196k` | 262144 | 196,608 | 100% GPU | 12,690 MiB | fits; prefill ~1,600–1,635 t/s |
| `qwen3.5:9b-32k` | 262144 | 32,768 | 100% GPU | 7,538 MiB | fits |
| `gemma4:e4b-highctx-131k` | **131,072** | 131,072 | 100% GPU | 8,624 MiB | **cannot do 196K** — clamps at 131,072; fastest prefill 2,766 t/s |
| `qwen3-vl:8b-highctx-100k` | 262144 | 100,000 | **36%/64% CPU/GPU** | ~15,256 MiB | **spills** (VL + mmproj) |
| `qwen3-vl:8b-highctx-196k` | 262144 | 196,608 | **61%/39% CPU/GPU** | 37 GB | **spills hard** — VL model too big |

> Status: `gemma4:e4b-highctx-131k` recorded (fits, fastest). The VL high-ctx
> Modelfiles originally had an **unknown-renderer "qwen3-vl"** bug (renderer
> must be the arch token / inherit from `FROM`); **fixed** by omitting
> `RENDERER`/`PARSER` — they now generate, but **spill to CPU** at high
> context. `.pi/models.json` update for these is still pending.

## After every accepted test — update TWO record + the pi registry

1. `backends-benchmark.md` §10.5/§10.5.1/§10.5.2 row (gen t/s, prefill t/s,
   TTFT on a big 2–16k prompt, VRAM, GPU/CPU%).
2. The backend's `TESTING.md` `§8` block.
3. `~/.pi/agent/models.json` → `providers.<ollama|lmstudio|...>.models[]` —
   set the model's `contextWindow` to the verified `ollama ps` CONTEXT (not the
   Modelfile request), and reflect CPU-spill/processor findings. This keeps pi's
   registry correct — **always update it after tests, never leave it stale.**

## Anti-patterns (learned the hard way)

- **Context Trap:** plain `qwen3.5:9b` / `qwen3-vl:8b` / `gemma4:e4b` load at
  **4096** by default — the Modelfile MUST set `num_ctx`. Verify with `ollama ps`.
- **Wrong renderer/parser:** `RENDERER qwen3-vl` (model id) → `500 unknown
  renderer` on generate. Use the architecture token `qwen3vl`.
- **Asserted > observed:** gemma does NOT do 196K; it clamps to 131,072. Record
  the `ollama ps` truth.
- **`ollama stop` with no arg** errors — pass the model name.
- **curl "Argument list too long"** on huge inline prompts — cap prompt gen
  (~700 not 1200+ iterations) or write the prompt to a file.
- **Never leave a model resident** — 16 GB VRAM, one big KV is the whole card.

## Sibling skills

- `add-or-edit-ai-models` — tune models/prompts for a smidja **roster** file
  (different concern: roster, not backend bench).
- `smidja` — working conventions inside `~/Ymir`.
- `runfactory` / `smidja-launcher` — the software-smidja runtime (uses models;
  this skill benchmarks the backends those rosters point at).