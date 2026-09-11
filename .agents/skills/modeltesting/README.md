# Model Testing — backend test docs

Per-backend testing guides for the aizerwiz LLM backend bench. Each
subfolder's `TESTING.md` is grounded in the single source of truth,
[`backends-benchmark.md`](./backends-benchmark.md) (methodology §3, MoE §9,
matrix §10, on-demand services §12).

- Machine: **zerwiz** (RTX A5000 **16 GB VRAM**, 16 cores / 122 GiB RAM)
- Date: 2026-09-04

## The five primary backends (on-demand load/unload candidates)

| Folder | Engine / role | On this box | Serving cents | Primary testing focus |
|---|---|---|---|---|
| [`llamacpp/`](./llamacpp/TESTING.md) | raw llama.cpp, **CUDA build**, native **router mode** | source clone `/home/zerwiz/llama.cpp`, CUDA build done `6703d78`; served via `model-host`/`llama-menu` (`:8125` + `:8081–8084`) | reference standard + fastest; the §9 MoE strategy lives here | build CUDA engine, router-mode INI, `--n-cpu-moe` sweep, §10 matrix, `TESTING.md` §10 model-host registration |

**llamacpp companion docs:** [`qwen36-35b-moe-coding-context.md`](./llamacpp/qwen36-35b-moe-coding-context.md)
(pure-GPU 80–130K recipe) · [`moe-offload-research-2026-09-05.md`](./llamacpp/moe-offload-research-2026-09-05.md)
(why `--cpu-moe` is a 5× trap, `--n-cpu-moe N` sweep tuning, `--parallel 1`, 155,904 cliff)
| [`lmstudio/`](./lmstudio/TESTING.md) | bundled llama.cpp, **JIT + Auto-Evict** | `:1234` running, all 4 targets present | **interim default** upstream | bundled-engine lag (§11.1), 139K CPU-spill, JIT swap |
| [`ollama/`](./ollama/TESTING.md) | llama.cpp wrapper | `qwen3.5:9b-highctx-262k/196k` Modelfiles | high-ctx path | **Context Trap** (`ollama ps`), explicit `num_ctx`, Modelfiles truth |
| [`colibri/`](./colibri/TESTING.md) | **disk-streamed MoE** (pure-C) | clone `/home/zerwiz/colebri/colibri` | CPU-big / long-ctx alternative | build `qwen36` engine, streaming decode, RAM/disk-bound |
| [`unsloth/`](./unsloth/TESTING.md) | GGUF **host** + **train→export producer** | CLI v2026.8.19, `~/Models/unsloth/` catalog | host on `:8888` + feeds GGUFs to all | `studio run` serve, `train`→`export`→GGUF, chat-template/EOS caveat |

## The three secondary services (research / conditional)

| Folder | Service | Fit | Re-open trigger |
|---|---|---|---|
| [`llamaswap/`](./llamaswap/TESTING.md) | external per-model orchestrator (Go) | GGUF, per-model isolation | only if router mode's isolation model fails |
| [`vllm/`](./vllm/TESTING.md) | production serving | **NOT fit** (HF fp8 not GGUF; big footprint; single-user) | only if we abandon GGUF or go multi-user |
| [`tabbyapi-yals/`](./tabbyapi-yals/TESTING.md) | ExLlama (TabbyAPI) + GGUF twin (YALS) | TabbyAPI blocked by GGUF; YALS secondary | TabbyAPI: on GGUF-abandon; YALS: if router-mode scripting loses |

## The four bench models (same GGUFs across every folder)

| # | Model | Arch | Fit 16 GB | On-disk quant file |
|---|---|---|---|---|
| A | `qwen3.5-9b` | dense | yes | `Qwen3.5-9B-Q4_K_S.gguf` (+mmproj-F32) |
| B | `qwen3.6-35b-a3b` | **MoE** | Q4 no; Q2/iq3 mostly | `-UD-Q2_K_XL` / `-UD-Q4_K_S` / `iq3_s` |
| C | `qwen3.8-27b` | hybrid-attn (dense-fit) | yes | `Qwen3.8-27B-UD-Q3_K_XL.gguf` (+mmproj-F16) |
| D | `gemma-4-26b-a4b` | **MoE** (A4B) | Q5 no; IQ4/IQ3 yes | `gemma-4-26B-A4B-it-UD-Q5_K_XL.gguf` (+mmproj-F32) |

## On-disk GGUF catalog (`~/Models/` = LM Studio `custom` symlink, 2026-09-04)

> `~/.lmstudio/models/custom` → `/home/zerwiz/Models`, so every GGUF below is
> also the LM Studio model set. `~/.lmstudio/models/` also contains empty
> stub dirs: `Qwen`, `lmstudio-community`, `TheBloke`, `tensorblock`,
> `mradermacher`, `TeichAI`. Unsloth is the source of the A–D bench GGUFs.

**Dense:**

| GGUF (in `~/Models/…`) | Size | Purpose |
|---|---|---|
| `unsloth/Qwen3.5-4B-GGUF/Qwen3.5-4B-Q4_K_S.gguf` | 2.4 GB | small dense, bench A-class |
| `unsloth/Qwen3.5-9B-GGUF/Qwen3.5-9B-Q4_K_S.gguf` (+mmproj-F32 1.7 GB) | 5.0 GB | **bench A** |
| `HauhauCS/Qwen3.5-9B-Uncensored-HauhauCS-Aggressive/Qwen3.5-9B-Uncensored-HauhauCS-Aggressive-Q4_K_M.gguf` (+mmproj-BF16 0.9 GB) | 5.2 GB | uncensored 9b variant |
| `Jackrong/Qwopus3.5-9B-Coder-GGUF/Qwopus3.5-9B-coder-Exp-Q8_0.gguf` (+mmproj-F32 0.9 GB) | 8.9 GB | coder 9b, Q8 |
| `unsloth/Qwen3.8-27B-GGUF/Qwen3.8-27B-UD-Q3_K_XL.gguf` (+mmproj-F16 0.9 GB) | 12.2 GB | **bench C**, hybrid-attn dense-fit |
| `unsloth/gemma-4-12b-it-GGUF/gemma-4-12b-it-Q3_K_S.gguf` | 4.8 GB | gemma 12b Q3 |
| `unsloth/gemma-4-12b-it-GGUF/gemma-4-12b-it-Q4_K_M.gguf` (+mmproj-F32 0.2 GB) | 6.6 GB | gemma 12b Q4 |
| `HauhauCS/Gemma4-12B-QAT-Uncensored-HauhauCS-Balanced/…-Q4_K_M.gguf` (+mmproj-BF16 0.2 GB) | 6.9 GB | gemma 12b QAT (pi default) |
| `stefans71/frontend-design-expert-8b/frontend-design-expert-Q4_K_M.gguf` (+mmproj-F16 1.1 GB) | 4.7 GB | frontend-design 8b |
| `ewinregirgojr/MiniCPM5-1B-Agentic-Tooluse-GGUF/minicpm5-1b-agentic-tooluse.Q8_0.gguf` | 1.1 GB | 1b agentic, Q8 |
| `nomic-ai/nomic-embed-text-v1.5.Q4_K_M.gguf` | 0.1 GB | embeddings |

**MoE:**

| GGUF (in `~/Models/…`) | Size | Fit 16 GB | Strategy |
|---|---|---|---|
| `unsloth/Qwen3.6-35B-A3B-GGUF/Qwen3.6-35B-A3B-UD-Q2_K_XL.gguf` | 11.4 GB | yes | **bench B** Q2 |
| `unsloth/Qwen3.6-35B-A3B-GGUF/qwen3.6-35b-a3b-iq3_s.gguf` | 12.7 GB | mostly | **bench B** iq3_s |
| `unsloth/Qwen3.6-35B-A3B-GGUF/Qwen3.6-35B-A3B-UD-Q4_K_S.gguf` | 19.5 GB | no (spill) | **bench B** Q4 → `--n-cpu-moe` |
| `unsloth/Qwen3.6-35B-A3B-GGUF/Qwen3.6-35B-A3B-UD-Q5_K_M.gguf` | 24.6 GB | no | B Q5 (high ctx spill) |
| `unsloth/gemma-4-26B-A4B-it-GGUF/gemma-4-26B-A4B-it-UD-Q5_K_XL.gguf` (+mmproj-F32 2.1 GB) | 19.8 GB | no (Q5) | **bench D** → IQ4/IQ3 or MoE spill |

> All mmproj F16/F32/BF16 files are vision-projector weights for the matching
> VL model — not standalone chat models.

## Shared benchmark rules (apply in every folder)

> **Reusable scripts live in [`scripts/`](./scripts/)** — `bench-one.sh
> <model-id>` (full end-to-end bench), `stop-all.sh` (unload everything →
> 26 MiB baseline), `gpu-sample.sh 2 10 -- <cmd>` (parallel GPU sampling to catch
> CPU-spill). See each script's header + `SKILL.md`.

1. **Unload everything between runs** — never trust cross-session numbers.
2. **Lock GPU clocks** prior: `sudo nvidia-smi -lgc 1900,1900` (+`-lmc`).
3. **Warmup** (discard first load), **same seed** (`--seed 42`), `--temp 0`.
4. **Capture GPU during prefill** (`nvidia-smi` in parallel) — catch CPU spill.
5. Record into the §10.5 table of `backends-benchmark.md` (gen t/s, prefill
   t/s, **TTFT on a big 2–16k prompt**, VRAM, GPU/CPU%).
6. **Always update `~/.pi/agent/models.json` after tests** — set the model's
   `contextWindow` to the verified value (e.g. the `ollama ps` CONTEXT) and
   reflect processor/VRAM findings, so pi's registry is never stale.

## Ollama models currently installed & tested (2026-09-04)

| Model | Modelfile | Context | VRAM | Processor | Status |
|---|---|---|---|---|---|
| `qwen3.5:9b-highctx-262k` | Modelfile.qwen35-9b-highctx-262k | 262,144 | 14,802 MiB | 100% GPU | ✅ fits 16 GB |
| `qwen3.5:9b-highctx-196k` | Modelfile.qwen35-9b-highctx-196k | 196,608 | 12,690 MiB | 100% GPU | ✅ fits 16 GB |
| `qwen3.5:9b-32k` | Modelfile.qwen35-9b-32k | 32,768 | 7,538 MiB | 100% GPU | ✅ fits |
| `qwen3.5:9b` (base) | — | 4,096 (trap) | 6,486 MiB | 100% GPU | ⚠️ Context Trap |
| `qwen3.5:9b-highctx-100k` | API `num_ctx:100000` | 100,000 | ~10,156 MiB | 100% GPU | ✅ base at explicit ctx |
| `qwen3-vl:8b-highctx-196k` | Modelfile.qwen3-vl-8b-highctx-196k | 196,608 | 37 GB | 61/39 CPU/GPU | ❌ spills hard |
| `qwen3-vl:8b-highctx-100k` | Modelfile.qwen3-vl-8b-highctx-100k | 100,000 | ~15,256 MiB | 36/64 CPU/GPU | ⚠️ spills |
| `qwen3-vl:8b` (base) | — | 4,096 (trap) | 7,172 MiB | 100% GPU | ⚠️ Context Trap |
| `gemma4:e4b-highctx-131k` | Modelfile.gemma4-e4b-highctx-131k | 131,072 | 8,624 MiB | 100% GPU | ✅ max (clamps at 131K) |
| `gemma4:e4b` (base) | — | 4,096 (trap) | 4,684 MiB | 100% GPU | ⚠️ Context Trap; fastest |
| `qwen3.8:27b-highctx-80k` | Modelfile.qwen3.8-27b-highctx-80k | 81,920 | 20 GB | 50/50 CPU/GPU | ⚠️ spills (dense hybrid) |
| `qwen3.8:27b-highctx-32k` | Modelfile.qwen3.8-27b-highctx-32k | 32,768 | 20 GB | 50/50 CPU/GPU | ⚠️ spills |
| `qwen3.8:27b` (base) | — | 4,096 (trap) | 18 GB | 25/75 CPU/GPU | ⚠️ spills at default |
| `nomic-embed-text` | — | n/a | — | — | embedding |
| `mxbai-embed-large` | — | n/a | — | — | embedding |

**Key Ollama findings:**
- **Context Trap:** plain models load at 4,096 unless Modelfile sets `num_ctx`
- **gemma4:e4b caps at 131,072** — 196K Modelfile silently clamps
- **qwen3-vl:8b spills at high ctx** — VL projector + KV > 16 GB
- **qwen3.8:27b is dense hybrid, NOT MoE** — all 27B params active; spills on 16 GB
- **Renderer/parser must be arch token** (`qwen3vl`, `gemma4`) not model id
- **Ollama hides `--n-cpu-moe`** — cannot control MoE expert offload; use raw llama.cpp for MoE

## Results

Fill the tables in `backends-benchmark.md` §10.5 after each clean run. The
bench's verdict (§12.3) picks the backend that does on-demand model switching
**and** hits the speed targets — the §12.5 ranking to validate is:
**native llama.cpp router mode → LM Studio JIT → Ollama → llama-swap** (with
Colibri as the CPU-big alternative and Unsloth as the host/train producer).