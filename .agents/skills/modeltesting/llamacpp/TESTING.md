# llama.cpp Testing — on-demand model hosting for aizerwiz

Per-backend testing guide for the **raw llama.cpp** path. This is the reference
standard engine and the strongest candidate for "always-available, on-demand
load/unload" serving behind aizerwiz (native router mode). Numbered sections
map to [`../backends-benchmark.md`](../backends-benchmark.md), which is the
source of truth for benchmark methodology (§3), MoE procedure (§9), and the
test matrix (§10).

- Date: 2026-09-04
- Machine: zerwiz (RTX A5000 Laptop **16 GB VRAM**, 16 cores / 122 GiB RAM)
- Clone: `/home/zerwiz/llama.cpp` (HEAD `6703d78`) — **CUDA build MADE 2026-09-04**
  (`cmake -B build -DGGML_CUDA=ON -DGGML_CUDA_F16=ON -DGGML_CUDA_FA_ALL_QUANTS=ON
  -DGGML_CUDA_MMQ=ON -DGGML_NATIVE=ON`; `llama-server`/`llama-cli` at
  `build/bin/`, NVCC 12.4, driver 580.x — safe from the CUDA-13.2 gibberish bug)
- Status: **CUDA build done; bench D/B Q2 at 80K+130K recorded; A/C pending**

---

## 1. Why this folder matters to the bench

From `backends-benchmark.md`:

- Raw llama.cpp is the **reference standard** (§3, §10.4) — the most accurate
  self-reported numbers, no wrapper overhead.
- Published gap: **10–15% faster than Ollama**, LM Studio within ~2% (InventiveHQ,
  10.3% llama.cpp faster than Ollama; §3). A 10x gap is a setup problem, not an
  engine difference.
- **Native router mode** (§12.5) = the strongest single service for on-demand
  model load/unload without restarts: one server + one `models.ini` hosts all
  3 builds-per-model (CPU-big / mid / fast) as aliases from the **same GGUF**.
- **MoE strategy depends on it** (§9): `--n-cpu-moe` / `--n-cpu-moe N`,
  `--cache-type-k/v q4_0` to reclaim VRAM — the 9× prefill / 4.8× gen win that
  makes 100K+ fast viable on 16 GB. Ollama can't expose these; LM Studio's
  bundled engine lags HEAD (§11.1).

---

## 2. Current state on this box

| Item | State |
|---|---|
| Source clone | `/home/zerwiz/llama.cpp`, HEAD `6703d78` |
| Build dir | **none** — not configured with CMake yet |
| Only binary | CPU-only via `.unsloth/llama.cpp/llama-server` (no CUDA) |
| CUDA toolkit | NVCC **12.4** (`/usr/bin/nvcc`); driver 580.x (newer, fine) |
| Router mode | present in clone (`tools/server/server-models.cpp`, README §1653+) |

**Important:** the existing `.unsloth/llama.cpp/llama-server` is **CPU-only**
(no CUDA). Proven in §4: with no CUDA backend it runs prefill at ~100 tok/s (0%
GPU util, 41.8 s for the same prompt). A CUDA build is required for the fast lane.

---

## 3. Build the CUDA engine

```bash
cd /home/zerwiz/llama.cpp
cmake -B build -DGGML_CUDA=ON -DGGML_CUDA_F16=ON \
  -DGGML_CUDA_FA_ALL_QUANTS=ON -DGGML_CUDA_MMQ=ON -DGGML_NATIVE=ON
cmake --build build --config Release -j 16 --target llama-server llama-cli
```

Verify the CUDA backend compiled in:

```bash
./build/llama-server --help | grep -E "n-gpu-layers|cpu-moe|n-cpu-moe"
```

> CUDA-flags rationale (from §12.4): `GGML_CUDA_F16` (FP16 compute), 
> `GGML_CUDA_FA_ALL_QUANTS` (flash-attn over all quants), `GGML_CUDA_MMQ`
> (multi-quant matmul), `GGML_NATIVE` (native ISA). Fine for NVCC 12.4.

---

## 4. The four models to bench (from §10 matrix)

Drives these self-hosted GGUFs (already on disk, `~/Models/unsloth/`):

| # | Model served | On-disk GGUF | Size | Arch class | Fit 16 GB | Strategy |
|---|---|---|---|---|---|---|
| A | `qwen3.5-9b` | `Qwen3.5-9B-Q4_K_S.gguf` (+mmproj-F32) | 5.4 GB | dense | yes | pure GPU `-ngl 999` |
| B | `qwen3.6-35b-a3b` | `-UD-Q2_K_XL` (12.3G) / `-UD-Q4_K_S` (20.9G) / `iq3_s` (13.7G) | 12.3–20.9 GB | **MoE** | Q4 no; Q2/iq3 mostly | `--n-cpu-moe` sweep + KV-quant |
| C | `qwen3.8-27b` | `Qwen3.8-27B-UD-Q3_K_XL.gguf` (+mmproj-F16) | 13.1 GB | hybrid-attn (dense-fit) | yes | pure GPU `-ngl 999` |
| D | `gemma-4-26b-a4b` | `gemma-4-26B-A4B-it-UD-Q5_K_XL.gguf` (+mmproj-F32) | 21.2 GB (Q5) | **MoE** (A4B) | Q5 no; IQ4_XS/IQ3 yes | MoE strategy (§9) or lower quant |

> A, C can go pure GPU. B and D are MoE — the §9 procedure decides placement.
> `qwen3.8-27b` is **hybrid linear/full attention** (§9.6) — dense-fit, no
> `--n-cpu-moe` needed if it fits; verify with `nvidia-smi` before assuming.

---

## 5. Command shapes (§10.3)

```bash
# A + C (dense-fit): pure GPU, 100K context
llama-server -m <file> -ngl 999 --flash-attn on -c 100000 -b 4096 -ub 4096 -t 8 --jinja

# B (MoE) Q4 when it must spill — sweep --n-cpu-moe
llama-server -m Qwen3.6-35B-A3B-UD-Q4_K_S.gguf -ngl 999 --n-cpu-moe <sweep> \
  --flash-attn on --cache-type-k q4_0 --cache-type-v q4_0 -c 100000 -b 4096 -ub 4096 -t 8 --jinja

# B at low quant (iq3_s / Q2_K_XL) — likely full GPU
llama-server -m qwen3.6-35b-a3b-iq3_s.gguf -ngl 999 --flash-attn on \
  -c 100000 -b 4096 -ub 4096 -t 8 --jinja

# D (gemma-4-26b-a4b) MoE — Q5_K_XL (21.2 GB) won't fit alone:
#   option 1 — IQ4_XS/IQ3 quant (fits ~13-14 GB, pure GPU)
llama-server -m gemma-4-26B-A4B-it-UD-IQ4_XS.gguf -ngl 999 --flash-attn on \
  -c 100000 -b 4096 -ub 4096 -t 8 --jinja
#   option 2 — Q5_K_XL with expert spill
llama-server -m gemma-4-26B-A4B-it-UD-Q5_K_XL.gguf -ngl 999 --n-cpu-moe <sweep> \
  --flash-attn on --cache-type-k q4_0 --cache-type-v q4_0 -c 100000 -b 4096 -ub 4096 -t 8 --jinja
```

**MoE placement rules (§9.3, §11.4):**

1. Choose offload strategy per candidate — don't brute-force.
2. `--cpu-moe` (all routed experts → CPU) vs `--n-cpu-moe N` (dial, expert
   layers from the highest numbered). **Don't mix.**
3. **Verify placement** — read the load log: confirm attention on CUDA, experts
   on CPU. A non-matching regex silently offloads nothing → silent OOM.
4. Raise batch for CPU+GPU MoE: `-b 4096 -ub 4096`.
5. Shrink KV to buy expert VRAM: `--flash-attn on --cache-type-k q4_0
   --cache-type-v q4_0`. Known-good recipe (§9.4): `-ngl 999 --n-cpu-moe 999
   --flash-attn on --cache-type-k q4_0 --cache-type-v q4_0 -c 100000 -b 4096
   -ub 4096 -t 8 --jinja` ⇒ **1,041 prefill / 52 gen t/s, ~3.9 GB** (esonhjz,
   Qwen3.6 35B-A3B Q4_K_M, 16 GB).
6. **Measure prefill and decode SEPARATELY.** MoE expert-offload hurts prefill
   far more than decode. For long-context coding, **TTFT on a big prompt is the
   number that matters** (§9.3.6).
7. Watch **RAM bandwidth** (system memory) when experts live in RAM — it caps
   decode (§9.3.7).
8. **Partial expert offload is SLOW** (§11.4) — offload *all* experts
   (`--n-cpu-moe 999` or `-ot "exps=CPU -ngl 99"`), keep attention + KV on GPU.

---

## 6. Native router mode (the on-demand server — §12.5)

The planned serving mode for aizerwiz. One server hosts all builds-as-aliases,
swap on request without restart.

```bash
# Start with NO --model; use a preset file
llama-server --models-preset models.ini
```

`models.ini` — one alias per build (`models.autoload`/`models-max` toggles the
resident set):

```ini
; each [<alias>] = a model name + its per-instance args
[server_cpu_big]
model   = /home/zerwiz/Models/unsloth/Qwen3.5-9B-Q4_K_S.gguf
ctx-size = 200000
n-gpu-layers = 0
n-cpu-moe = 999

[server_mid]
model   = /home/zerwiz/Models/unsloth/Qwen3.5-9B-Q4_K_S.gguf
ctx-size = 100000
n-gpu-layers = 999

[server_fast]
model   = /home/zerwiz/Models/unsloth/Qwen3.5-9B-Q4_K_S.gguf
ctx-size = 32000
n-gpu-layers = 999
```

Key router flags (§12.5): `--models-dir`, `--models-max N`, `--models-autoload`.
Router forwards on the `"model"` JSON field / `?model=` query. Swap reload
latency 3–10 s. One resident per worker at a time; timed eviction
`--stop-timeout` (default 10 s). Config experimental — flags shift across
versions; verify with `--help`.

### Command line for a single-model server (per §10.3/§3)

```bash
./build/llama-server --model <file> --ctx-size <N> --n-gpu-layers 999999 \
  --flash-attn on --n-predict 5
```

---

## 7. Benchmark procedure (from §3 + §9.3)

Follow the canonical procedure from the parent doc — the critical steps:

1. **Unload everything** between runs (never trust cross-session numbers):
   ```bash
   ollama stop 2>/dev/null
   pkill -f "lm-studio"; pkill -f "llama-server"; sleep 5
   nvidia-smi --query-gpu=memory.used --format=csv,noheader   # must be baseline
   ```
2. **Lock GPU clocks**: `sudo nvidia-smi -lgc 1900,1900` + `-lmc 7000,7000`.
3. **Warmup** (discard first load): one cheap completion, drop it.
4. **Same seed** (`--seed 42`), `--temp 0`.
5. **Capture GPU during run** (parallel loop of `nvidia-smi`).
6. **Read self-reported timings** — `llama_print_timings()` gives prompt-eval
   and eval t/s directly (the most accurate engine numbers).
7. **Record** into §10.5 table of the parent doc.

Context sizes to hit: **80K, 100K** — and if it shows, 196K/262K for CPU spill
(acceptable, record RAM + cores used). Prefill t/s + TTFT at a big prompt
(~2–16k tokens) is the coding-critical metric.

---

## 8. Expected values to sanity-check (§10.4)

**Measured on this box (CUDA build `6703d78`, 2026-09-04)** — Qwen3.6-35B-A3B
`UD-Q2_K_XL` (11.4 GB), pure GPU, KV q8_0, b4096, temp 0 seed 42, 7,785-token
coding prompt. Full doc + recipe: [`qwen36-35b-moe-coding-context.md`](./qwen36-35b-moe-coding-context.md).
Offload strategy research (why `--cpu-moe` is a 5× trap, `--n-cpu-moe N` tuning,
`--parallel 1`): [`moe-offload-research-2026-09-05.md`](./moe-offload-research-2026-09-05.md).

**⚠️ `--n-cpu-moe 999` (all experts→CPU) is the SLOW regime** — community
measures 5× faster with attention+experts on GPU. Only use full offload when the
quant doesn't fit; for partial offload sweep `--n-cpu-moe 24→12` (see the
research doc §7). The 5× swing is mapped in
[`moe-offload-research-2026-09-05.md`](./moe-offload-research-2026-09-05.md) §1.

| Context | KV | VRAM | Prefill t/s | Decode t/s | GPU util | Note |
|---|---|---|---|---|---|---|
| 80,000 | q8_0 | 13,975 MiB | **1,848** | **65.2** | 100% | fits, ~2.4 GB headroom |
| 130,048 | q8_0 | 14,885 MiB | **1,866** | **64.5** | 100% | fits, ~1.5 GB headroom |
| 130,048 | f16 | — | **OOM** | — | — | compute buf (1.9 GB) fails, not KV — shrink `-b` or quant KV |

**Q4/Q5 MoE offload runs (KV q8_0, measured — full offload vs partial sweep):**

| Quant | Context | `--n-cpu-moe` | VRAM GPU | RAM RSS | Prefill t/s | Decode t/s | Verdict |
|---|---|---|---|---|---|---|---|
| Q4_K_S (19.5 GB) | 80,000 | 999 (all CPU) | 4,751 MiB | ~20.5 GB | 774 | 23.9 | all-experts-CPU regime |
| Q5_K_M (24.6 GB) | 32,768 | 999 (all CPU) | 4,009 MiB | ~24 GB | 654 | 17.5 | superseded below |
| Q5_K_M (24.6 GB) | 120,000 | 999 (all CPU) | 5,462 MiB | ~25.8 GB | 526 | 20.3 | slow regime; Q5 quality |
| Q5_K_M (24.6 GB) | 120,000 | 24 | 14,642 MiB | — | — | 29.7 | partial; fits, 1.4 GB headroom |
| **Q5_K_M (24.6 GB)** | **120,000** | **22** | **15,767 MiB** | ~14 GB | **628** | **30.4** | **BEST for Q5 @120K**; N=20 OOMs |
| **Q4_K_S (19.5 GB)** | **120,000** | **18** | **15,085 MiB** | ~10 GB | **723** | **37.6** | **BEST for Q4 @120K**; N=16 loads but crashes on real inference (runtime compute OOM) |
| **IQ3_S (12.7 GB)** | **100,000** | **0 (pure GPU)** | **15,680 MiB** | ~4 GB | **845** | **36.3** | **BEST for IQ3 @100K** — pure GPU, max offload; pure-GPU @120K crashes on compute |
| **Q2_K_XL (11.4 GB)** | **155,904** | **0 (pure GPU)** | **15,354 MiB** | ~3 GB | **875** | **45.7** | **BEST for Q2 — max ctx below 155,904 cliff + pure GPU**; decode 45.7 t/s; above cliff = 9 t/s (5× drop) |
| **IQ3_S (12.7 GB) orchestrator** | **100,000** | **999 (all CPU)** | **4,682 MiB** | ~9 GB | **885** | **26.1** | **orchestrator role on :8093** — experts→CPU, runs in PARALLEL with 9b workers (2 models = 15.6 GB total); prefill stays fast |
| **gemma-4-26b-a4b Q5_K_XL** (19.8 GB) | 80,000 | 999 | 6,174 MiB | ~20.5 GB | 715 | 11.9 | SWA; experts→CPU; superseded below |
| **gemma-4-26b-a4b Q5_K_XL** (19.8 GB) | **120,000** | **20** | **15,204 MiB** | ~7 GB | **1084** | **21.6** | **BEST for gemma 26B @120K** — partial offload +82% decode (11.9→21.6); N=18 OOMs; SWA limits per-token decode |

**Gemma 4 12B family (all pure GPU, 131,072 = gemma4 native cap, verified 2026-09-05):**

| Model | Quant | Context | VRAM GPU | Prefill t/s | Decode t/s | Verdict |
|---|---|---|---|---|---|---|
| `12b-q3` | Q3_K_S (12B) | 131,072 | 9,462 MiB | 1062 | 24.1 | pure GPU; fast; vision (mmproj) |
| `12b-q4` | Q4_K_M (12B) | 131,072 | 11,356 MiB | **1196** | **33.3** | pure GPU; **fastest decode of 12B family**; vision |
| `hauhau-gemma` | Q4_K_M QAT uncensored (12B) | 131,072 | 11,570 MiB | 1192 | 31.7 | pure GPU; uncensored; vision |

**Every other model (all pure GPU unless noted, verified 2026-09-05 via
`bench-one.sh` — true cold prefill, cache_n=0):**

| Model | Quant | Context | VRAM GPU | Prefill t/s | Decode t/s | Verdict |
|---|---|---|---|---|---|---|
| `9b` | Q4_K_S (9B) | 262,144 | 14,732 MiB | 1745 | 54.3 | **max ctx, pure GPU**; vision |
| `4b` | Q4_K_S (4B) | 262,144 | 12,062 MiB | 2602 | 82.0 | **fastest overall**; tiny |
| `9b-highctx` | Q4_K_S (9B) | 262,144 | 14,732 MiB | 1741 | 54.0 | same as 9b (duplicate role) |
| `hauhau-9b` | Q4_K_M uncensored (9B) | **262,144** | 14,094 MiB | 1700 | 51.3 | **max ctx** (native 262K); uncensored; vision |
| `qwopus` | Q8_0 coder (9B) | **131,072** | 13,614 MiB | 1789 | 36.4 | **max ctx** — Q8_0 too heavy for 262K; best quality 9B |
| `frontend` | Q4_K_M design (8B) | **65,536** | 12,530 MiB | 2027 | 50.6 | **65K native cap** — 262K request silently clamps (Context Trap); UI/UX design |
| `minicpm` | Q8_0 (1B) | 65,536 | 2,740 MiB | 147 | 197 | **tiny + fastest decode**; agentic tooluse |
| `embed` | Nomic Embed 1.5 | 8,192 | 484 MiB | — | — | **embeddings**: 768-dim, 0.1 s, dedicated :8100 |
| `27b-cpu` | Q3_K_XL (27B, pure CPU) | 120,000 | 1,346 MiB | 6.3 | 1.6 | **CPU-only**; no mmproj (crashes); batch/background only |
| `27b` | Q3_K_XL (27B dense, GPU) | 48,000 | 15,012 MiB | ~80 | 17.6 | **DENSE** — all 27B active/token; large-prompt prefill very slow (>90s @ 3.8K tok @ 48K ctx) |

> **Partial-offload sweep (2026-09-05):** lowering `--n-cpu-moe` from 999 → 24 →
> 22 lifts decode 20.3 → 29.7 → **30.4 t/s** (+50%) and prefill 526 → 628 t/s at
> the same 120K context. The edge for Q5_K_M @120K on 16 GB is **N=22**;
> N=20 fails loading (KV/`compute pp buffers` OOM). Sweep recipe + why
> `--cpu-moe` is a 5× trap: [`moe-offload-research-2026-09-05.md`](./moe-offload-research-2026-09-05.md).

> Hybrid linear-attn MoE ⇒ KV grows only ~20 KB/token (30/40 Gated DeltaNet
> layers hold fixed state). No `--n-cpu-moe` needed ≤130K at Q2. Offloading all
> experts to CPU costs ~2.4× decode and ~2.4× prefill vs pure-GPU Q2 — Q4/Q5
> only worth it for quality, at 3× latency. MTP/spec-decoding does NOT help
> this MoE (community consensus). `--reasoning off` verified ~3× wall-clock on
> coding QA (thinking trace eats the token budget).

Glukhov (RTX 4080, 16 GB, llama.cpp) — A5000 is **slower**, treat as upper bounds:

| Model | quant | expected gen t/s | VRAM |
|---|---|---|---|
| `Qwen3.6-35B-A3B-UD-IQ3_XXS` | IQ3_XXS | ~147 t/s (flat 19K→64K) | ~13.8 GB |
| IQ3_S | IQ3_S | ~136–138 t/s | fits **100K** no drop |
| `Qwen3.5-27B-UD-IQ3_XXS` (≈ qwen3.8-27b) | Dense | ~45 t/s @19-32K | ~13 GB |

---

## 9. What to record / outcomes

> **After every accepted test, always update `~/.pi/agent/models.json`:**
> set the model's `contextWindow` to the verified value and reflect the
> processor/VRAM findings, so pi's registry is never stale (§ shared rule 8).

- Fill rows A–D at 80K & 100K in §10.5 (gen t/s, prefill t/s, TTFT, VRAM GB,
  GPU/CPU%).
- Decision inputs for §12.3: does the **built CUDA llama.cpp** serve pi +
  programs over aizerwiz with on-demand load/unload at full speed (vs LM
  Studio's ~30–50% bundled lag)? Does router mode's one-resident-per-worker
  swap beat LM Studio's JIT?
- Record CPU-fallback rows when a model spills (gen t/s, TTFT, RAM GB, cores).

---

## 10. `model-host` + `llama-menu` — how to add a new model

The native CUDA servers are launched through two places, and a new model must
be added to BOTH:

| File | What it owns | How to add a model |
|---|---|---|
| `~/command/scripts/model-host.sh` | the actual launcher (GGUF path, ctx, port, MoE flag, VRAM pre-check) | add a case in `register()` + a line in every `for m in …` list + `list()` |
| `~/.local/bin/llama-menu` | the interactive number-menu on top | add a menu line + a `case` arm that calls `model-host start <name>` |

**Checklist when a new model/quant lands (e.g. a new quant, a new arch):**

1. **Bench it first** (this skill) — you must know ctx that fits, VRAM, and
   whether it needs `--n-cpu-moe` before you can register it honestly.
2. **Pick a free port** — don't collide with the existing ones:
   `8125` (qwen3.6 quants) `8081` `8082` `8083` `8084`. If it shares a port with
   another model, that's fine — `start` auto-stops the current owner.
3. **`register()`** — add a line `name) echo "Label|/abs/path/to/model.gguf|CTX|PORT|CPU_MOE"`.
   `CTX` = the *verified* context (not the file's max). `CPU_MOE` = `1` if it
   needs `--n-cpu-moe 999` (doesn't fit 16 GB pure GPU), else `0`.
4. **All model loops** — add the name to the `for m in q2 iq3 q4 q5 9b 4b 35b
   9b-highctx` lists in `start()` (port-freedom loop) and `stop()` and
   `status()`, plus the `case` in the VRAM pre-check if it needs a different
   `need_mib`.
5. **`list()`** — add the row so `model-host list` shows it.
6. **`llama-menu`** — add the menu line(s) and the `case` arm
   (`name) model-host start <name> ;;`). Keep the label short enough to fit the
   box.
7. **`~/.pi/agent/models.json`** — if pi should use it, add it under the
   `llamacpp` provider (`baseUrl` `http://127.0.0.1:PORT/v1`) with the verified
   `contextWindow`, `reasoning: false`, and the GGUF id. `_launch: true` lets
   pi start it via model-host.
8. **Verify** — `model-host list`, then `model-host start <name>`, confirm
   `✓ loaded`, `curl http://localhost:PORT/v1/models` → `200`, then
   `model-host stop` and confirm VRAM returns to ~26 MiB baseline.

> Keep `need_mib` honest in the VRAM pre-check: 16 GB total, so two big
> pure-GPU models (~14–15 GB each) can never run at once — the check refuses
> with a clear message instead of an opaque OOM.

---

## 11. Test record — swap-proxy + Qwen3.8 Flash Next (2026-09-07)

### 11.1 The auto-swap proxy (`~/command/scripts/swap-proxy.cjs`)

Built and verified end-to-end. Delivers "swap model in pi.dev/opencode →
stop the running model, start the one I chose."

Verified on zerwiz:

| Test | Result |
|---|---|
| Auto-start on request (nothing running) | ✅ minicpm auto-started on :8092, served |
| Same-port swap stops previous | ✅ 12b-q3 → 12b-q4 on :8088; old pid killed |
| Already-loaded fast path | ✅ no reload, immediate |
| opencode alias routing | ✅ `minicpm5-1b-agentic-tooluse` → `...@q8_0` |
| Launcher start/stop/status | ✅ |

See [`../llamaswap/swap-proxy.md`](../llamaswap/swap-proxy.md) for ops.

### 11.2 Qwen3.8-Flash-Next — the offload fix that made it load

First attempt `cpu_moe:false, ngl:999` → **OOM**
(`cudaMalloc failed: allocating 57697.13 MiB` — 90 GB GGUF on a 16 GB GPU).

Fix = canonical MoE partial offload: **routed experts → CPU, always-active
layers + KV → GPU** (`cpu_moe:true` → `--n-cpu-moe 999`).

Measured (100K ctx, Q3_K_XL):

| Metric | Value |
|---|---|
| Load | ~20 s |
| GPU VRAM | ~14.2 GB (fits) |
| System RAM | ~14 GB (mmap'd experts) |
| Prefill / Decode | ~5–8 / ~4.8 t/s |

Settings doc: [`../models/qwen3.8-flash-next-settings.md`](../models/qwen3.8-flash-next-settings.md).

> **Lesson (feed back to §10 checklist):** for any 90 GB-class MoE on a 16 GB
> GPU, set `cpu_moe:true` (experts to CPU) BEFORE trying `ngl:999` — otherwise
> you get an opaque OOM at load. Record the verified `contextWindow` (100K) in
> `~/.pi/agent/models.json`.

---

## 12. Qwen3.8 Flash Next — CPU-thread speedup (2026-09-08)

`qwen3.8-flash-next@q3_k_xl` was decode-bound at **~4.8 t/s** (100K ctx,
`cpu_moe:true` → `--n-cpu-moe 999`, §11.2). Root cause: the launcher pinned
`-t 8` (8 CPU threads) while the model keeps **ALL 512 routed experts on CPU**
(~14 GB mmap'd in RAM) on a **16-core** host — expert decode uses system RAM
bandwidth and needs every core.

Change (registry + launcher + router generator, per-model knob):

| File | Change |
|---|---|
| `scripts/llama-models.yaml` | added `threads: 16` to `q3-flash` and `q3-flash-swap` (ctx stays **100000**) |
| `scripts/model-host.sh` | new `model_threads()` reader; `-t "$threads"` (default **8**, per-model override) |
| `scripts/gen-llama-router-config.py` | **per-model `threads` emitted into each INI section** (overrides the `[*]` default `threads = 8`) |

Launch line now: `-t 16` for the flash model on BOTH paths (`model-host start`
**and** the router `--models-preset`). Since expert decode is CPU-bound,
doubling threads 8 → 16 should roughly double token throughput (subject to the
system-RAM bandwidth cap — §9.3.7).

Verified 2026-09-08 (router path — the live serving path):

```bash
# after `llama-router restart` + a request to qwen3.8-flash-next@q3_k_xl:
#   /v1/models -> status.args contains --threads 16  (was --threads 8)
#   VRAM ~13.2 GB (100K ctx, n-cpu-moe 999)
```

`threads` is the new schema field — keep it in mind for future CPU-bound MoE
entries. Todo: re-bench decode t/s at 100K ctx with `-t 16` vs the §11.2
`~4.8 t/s` baseline and record the number here.

---

## 13. GPT-OSS 20B F16 — the 100K GPU model (2026-09-08)

Added + benched **gpt-oss-20b** (OpenAI's MoE: 21B total / 3.6B active, 32
experts, 4/tok, 24 layers, 131K train ctx) as `gptoss20b` / `gptoss20b-swap`.

**Measured (F16 GGUF 13.8 GB, pure GPU, `-ngl 999`, temp 0 seed 42):**

| Context | KV | VRAM | Prefill t/s | Decode t/s | GPU util |
|---|---|---|---|---|---|
| 60,000 | f16 | 14,534 MiB | 157 | 29.1 | 91% |
| **100,000** | **q8_0** | **15,496 MiB** | **141.9** | **28.4** | **93%** |
| 100,000 | f16 | — | OOM | — | — |

**Why it matters:** this is the FIRST model on the box that gives **100K
context at GPU speed** — ~28 t/s decode vs Flash-Next's ~4-5 t/s (CPU-bound,
§11/§12). Prefer it over Flash-Next for any GPU-speed 100K need.

**Registered:** `llama-models.yaml` (port 8096, ctx 100K, kv q8_0), router
(`gpt-oss-20b@f16`), pi (`llamacpp-gptoss20b` → :8080). Research:
[`gpt-oss-20b-research.md`](./gpt-oss-20b-research.md).

**Zed IDE fix (same day):** Zed's `language_models.llama.cpp` had
`auto_discover: false` + 4 stale hardcoded `@`-ids. Set `auto_discover: true`
(now pulls all 23 router models) and repointed the 13 dead
`openai_compatible.llamacpp-*` sub-providers (old direct ports 8081/8084/...)
to the router `:8080`.

---

## 14. zerwiz-1 (Windows) — router installed, GPU FIXED (2026-09-09)

Mirror box: ASUS ROG Flow X13, **RTX 3080 Laptop 16 GB** (driver 595.79 / CUDA
13.2, `nvidia-smi` works without admin), llama.cpp **b10868** `cuda-12.4-x64`
installed at `C:\Users\josef\llama.cpp`, router running from WSL via
`scripts/llama-router-win.sh` → `http://172.17.16.1:8080/v1`.

**The CUDA-on-this-box trap (fixed):** `--list-devices` was showing `(none)`,
no `ggml_cuda_init`/`load_backend` lines, all buffers Host/CPU_REPACK → models
ran CPU-only. Root cause: the official Windows CUDA build ships its runtime in
a **separate companion zip** —
download `https://github.com/ggml-org/llama.cpp/releases/download/b10868/cudart-llama-bin-win-cuda-12.4-x64.zip`
and unzip `cudart64_12.dll` + `cublas64_12.dll` + `cublasLt64_12.dll` **next to
`llama-server.exe`**. Verify: `llama-server.exe --list-devices` → `CUDA0
(16383 MiB)`. Any Ubuntu/Arch Linux native install will have these already.

**Measured cold (fixed, NV = full GPU offload, KV q8_0, 32K ctx, seed 42):**

| model | ngl | prefill t/s | decode t/s | TTFT | vs CPU-only |
|---|---|---|---|---|---|
| qwen3-4b Q4_K_M | 999 | 3,810 | **105.7** | 70 ms | 10× decode |
| gpt-oss-20b MXFP4 (MoE) | 999 | 1,510 | **109.6** | 209 ms | 10× decode (was cpu_moe) |
| gemma-3-12b Q8_0 | 999 | 968 | **29.4** | 274 ms | 12× decode |
| devstral-14b Q4_K_M | 36 | 729 | **10.6** | 1.98 s | 5.3× decode (ngl 40 OOMs) |

**Tuning history:** registry `scripts/llama-models.win.yaml` assumed the old
"8 GB" spec. gptoss `cpu_moe: true` killed it (30 t/s) → remove → 110 t/s.
gemma-r ngl 26 → 999. devstral 32 → 36; **40 OOMs** because 14 GB dense + KV
q8_0 32K + ~1.1 GB compute buffer > 16 GB — always leave compute headroom.

**Still failing (not GPU):** `qwen35-4b` / `qwen35-4b-64k` GGUFs error on the
`rope.dimension_sections` metadata (quantizer/build mismatch on b10868). Only
fix = re-quant.

The process to reproduce on this box:
`.agents/skills/modeltesting/scripts/bench-win-router.py`. Full tables:
[`../backends-benchmark.md`](../backends-benchmark.md) §10.5.6 (CPU baseline) +
§10.5.7 (GPU fixed). Windows paths differences:
[`docs/DEVELOPER_SETUP/windows.md`](../../../docs/DEVELOPER_SETUP/windows.md).

---

## Related

- [`../backends-benchmark.md`](../backends-benchmark.md) — §3 methodology, §9 MoE,
  §10 matrix+command shapes, §12.5 router mode, §12.4 build flags
- [`../../LLAMA_CPP_SERVER.md`](../../LLAMA_CPP_SERVER.md) — llama.cpp server notes
- `~/Models/unsloth/` — the GGUF catalog this bench self-hosts