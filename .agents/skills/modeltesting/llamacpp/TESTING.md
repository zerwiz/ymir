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

## 10. The host is not this skill's business

This skill **tests**. It does not install, run, or reconfigure the serving
stack: installing it on a machine is [`../INSTALL.md`](../INSTALL.md), and
day-to-day operation belongs to the machine's own manuals
(`~/.local/share/llama-router/docs/`).

What concerns a tester here:

- `scripts/bench-one.sh` starts its **own** throwaway single-model server on a
  scratch port and kills it. It never calls `model-host`, `llama-router`, or
  `swap-proxy`.
- It reads the machine registry **read-only** (`llama-models get …`) only to
  learn a model's `gguf`, `ctx`, `ngl`, `kv`, `cpu_moe`, `threads`, so the
  measured configuration matches what the service would actually serve.
- `ctx` is the **verified** window: the value read back from `/props`, never the
  file's maximum and never simply what you asked for.

So the add-a-model procedure is not written here. When an operator adds a model
to the service, the tester's job is to measure it on this box and record the
result in the three places listed in [`../HOST-RUNBOOK.md`](../HOST-RUNBOOK.md) §6.

---

## 11. Test record — swap-proxy + Qwen3.8 Flash Next (2026-09-07)

### 11.1 The auto-swap proxy (legacy :8090 gateway — see HOST-RUNBOOK §7)

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

Ops live on the machine: `~/.local/share/llama-router/docs/swap-proxy.md`.

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

Launch line now: `-t 16` for the flash model on both serving paths (the
launcher and the router preset). Since expert decode is CPU-bound,
doubling threads 8 → 16 should roughly double token throughput (subject to the
system-RAM bandwidth cap — §9.3.7).

Verified 2026-09-08 (router path — the live serving path):

```bash
# after the machine's router restarts + a request to qwen3.8-flash-next@q3_k_xl:
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

## 15. The LM Studio models on the Linux host — 80K on a 3080 Laptop (2026-09-12)

The GGUFs live where LM Studio puts them: `~/.lmstudio/models` (`settings.json`
→ `downloadsFolder`). That is now the registry's `models_dir`, so every `gguf:`
in `llama-models.yaml` is relative to it.

**Getting a CUDA server was the whole battle.** `/usr/bin/llama-server` on this
host is CPU-only (`--list-devices` → `none`), and a CPU-only server "loads"
fine — it just runs 10× slow. LM Studio keeps a CUDA12 llama.cpp build *and* its
CUDA12 runtime in separate packs; the binary needs `LD_LIBRARY_PATH` at both:

```
~/.lmstudio/extensions/backends/llama.cpp-linux-x86_64-nvidia-cuda12-avx2-2.34.0   # the build
~/.lmstudio/extensions/backends/vendor/linux-llama-cuda12-vendor-v1                # libcudart.so.12, libcublas.so.12
```

Shim (machine property, outside every repo):
`~/.local/share/llama-router/scripts/llama-server-cuda`. The registry's
`defaults.server` points at the shim, so `model-host` and `llama-router` never
pick the CPU-only binary again.

**Measured — `27b` (Qwen3.8-27B-UD-IQ3_XXS, dense 27B, 10.2 GB):**

| Context | KV | VRAM | decode t/s | GPU | notes |
|---|---|---|---|---|---|
| 81,920 | iq4_nl | 13,602 MiB | **21.1** | 92-95% @114 W | `/props` n_ctx 81,920; load 12 s; ~2.2 GB headroom |

**Measured — `30b-coder` (Qwen3-Coder-30B-A3B-Instruct-UD-IQ2_M, MoE 30B/3B, 10.1 GB):**

| Context | KV | VRAM | decode t/s | GPU | notes |
|---|---|---|---|---|---|
| 81,920 | iq4_nl | 13,140 MiB | **46.6** | 92-95% | `/props` n_ctx 81,920; load 12 s; measured through the router (:8080), which autoloaded it in 5 s |

**The clock-ramp trap (cost me a bogus number).** The 27B's first timed run read
prefill 28.2 / decode 8.2 t/s with `nvidia-smi` showing **0 % util**. Same model,
warmed: **92-95 % util, 114 W, decode 21.1 t/s**. This GPU idles at 210 MHz and
boosts lazily; `bench-one.sh` step [6/7] restarts the model to clear the KV cache,
which throws away the boost too. **Warm the GPU after the restart, before timing.**
And never quote prefill t/s from a ~30-token prompt — that is overhead, not
throughput.

- **Context scaling (2026-09-12).** Same `27b` server, same power state, only
  prompt length changed: at a 19-token prompt prefill **64.7** / decode **21.2**
  t/s (peak 53 W, 9% util); at a 7,940-token prompt prefill **14.5** / decode
  **4.6** t/s (peak 113 W, 100% util). Decode falls **4.6x** while drawing
  *more* power — KV-cache traffic, not a power cap. **All decode figures above
  are short-context upper bounds.**

**Registered + wired:** `llama-models.yaml` (`27b*` → IQ3_XXS at 81,920; `30b-coder`
+ new `30b-coder-swap` on :8129, group `qwen30b`), `model-host verify`, and pi's
`contextWindow` set to the verified 81,920.

Two more downloads were still in flight at the time of writing and are **not**
registered yet: `Qwen3.5-4B-Q4_K_S` (6 %) and `Qwen3.6-35B-A3B-UD-IQ2_XXS` (17 %).
Register them only once the `.part` files complete.

---

## Related

- [`../backends-benchmark.md`](../backends-benchmark.md) — §3 methodology, §9 MoE,
  §10 matrix+command shapes, §12.5 router mode, §12.4 build flags
- [`../../LLAMA_CPP_SERVER.md`](../../LLAMA_CPP_SERVER.md) — llama.cpp server notes
- `~/Models/unsloth/` — the GGUF catalog this bench self-hosts

---

## 16. KV cache type — the silent 20-30x prefill trap (2026-09-12)

Everything in §15 above was measured with `kv: iq4_nl`, which is the wrong KV
type for a CUDA build: the flash-attention kernel rejects it and the scheduler
moves the whole attention op to the **CPU** without any error. See
[`../backends-benchmark.md`](../backends-benchmark.md) §10.5.10 for the source
(llama.cpp issue #27109), the mechanism, and the memory table.

The rule for any bench or registry entry on a CUDA box:

- KV type must be `f16`, `q8_0`, `q4_0` (or `bf16`); **never `iq4_nl`, `q4_1`,
  `q5_0`, `q5_1`** on a default build.
- **K must equal V.** Mixed types also fail the kernel check.
- If you need a smaller KV for more context, build with
  `-DGGML_CUDA_FA_ALL_QUANTS=ON` rather than guessing at a 4-bit type.

Quick check after any config change — if prefill is near CPU numbers while the
GPU shows high utilisation and near-limit wattage, suspect this fallback:
compare a multi-thousand-token prefill against the ~1,000 t/s class recorded in
§15/§10.5.x, and confirm the KV types with:

```bash
grep -E "cache-type-k|cache-type-v" /tmp/opencode/llama-router.log | tail -4
```


---

## 17. Maximum context per model on this card — measured, not guessed (2026-09-12)

After the §16 correction, every model was re-measured at its own ceiling with a
real ~8K-token request (a warm-up, then a timed run, `n_ctx` read back from
`/props`):

| Model | quant | ctx | prefill t/s | decode t/s | peak VRAM |
|---|---|---|---|---|---|
| Qwen3.5-4B | Q4_K_S | 262,144 | 2,705 | 91.3 | 9,337 MiB |
| Qwen3.6-35B-A3B (MoE) | IQ2_XXS | 262,144 | 2,057 | 89.4 | 14,763 MiB |
| Qwen3-Coder-30B-A3B (MoE) | IQ2_M | 90,112 | 2,251 | 67.0 | 15,673 MiB |
| Qwen3.8-27B (dense) | IQ3_XXS | 114,688 | 495 | 20.7 | 15,345 MiB |

**A successful load is not a working ceiling.** The 27B loads at 131,072 and
then dies on the first real request; 114,688 is what survives. Always finish a
ceiling search with an actual prompt.

**Why the MoE and hybrid models reach 256K and the dense one does not:** context
is bought with a small KV cache. Only 8 of the 4B's 32 blocks and 10 of the
35B-A3B's 40 blocks are full-attention (the rest are Gated DeltaNet linear
layers with a fixed-size state), so their q8_0 KV is 17.0 and 10.6 KiB/token
against 32 KiB/token for the dense 27B and 51 KiB/token for the pure-attention
30B coder.

Budget the next one as:
`KV_layers x 2 x kv_heads x head_dim x bytes_per_elem x ctx`, then fit it plus
the weights plus ~0.9 GiB of compute buffer inside the card's ~15,812 MiB free.

---

## 18. Full measurement appendix — every run on this host (2026-09-12)

Consolidated record of every measurement taken on this machine. Configurations
that were rejected are included, because the failures are the useful part.

### 18.1 Machine and method

| | |
|---|---|
| GPU (serving) | NVIDIA RTX 3080 Laptop 16 GB — the XG Mobile eGPU, **PCIe 3.0 x4** |
| GPU (internal) | AMD Cezanne Radeon Vega iGPU — Vulkan, **no VRAM**, borrows system RAM |
| RAM | **30 GiB** (not the 122 GiB carried over from the earlier A5000 box) |
| Driver / CUDA build | 610.57.04 / LM Studio cuda12-avx2-2.34.0 |
| Prompt | 7,937 tokens unless stated; temp 0, seed 42, `-np 1`, flash-attn on |

Method: a throwaway single-model server (or the router for the concurrent runs),
a discarded warm-up request, then a timed run; `n_ctx` read back from `/props`;
VRAM sampled during the run. Peak VRAM is the maximum observed, not the allocation.

### 18.2 The KV-type fix — before and after (the single biggest change)

`kv: iq4_nl` is not accepted by a default CUDA build's flash-attention kernel, so
the whole attention op ran on the **CPU**, silently (llama.cpp issue #27109).
After switching to `q8_0` on both K and V:

| Model | ctx | KV | prefill t/s | decode t/s | verdict |
|---|---|---|---|---|---|
| Qwen3.8-27B IQ3_XXS | 80,000 | `iq4_nl` | **14.5** | **4.6** | CPU fallback |
| Qwen3.8-27B IQ3_XXS | 114,688 | `q8_0` | **495.2** | **20.7** | fixed (34x prefill) |
| Qwen3-Coder-30B-A3B IQ2_M | 80,000 | `iq4_nl` | **17.4** | **6.2** | CPU fallback |
| Qwen3-Coder-30B-A3B IQ2_M | 90,112 | `q8_0` | **2,250.5** | **67.0** | fixed (129x prefill) |

### 18.3 Context ceiling sweep, per model

Each row is a real ~8K request against the stated configuration.

**Qwen3.8-27B IQ3_XXS — dense, 11.05 GiB weights, 32 KiB/token at q8_0**

| ctx | prefill t/s | decode t/s | peak VRAM | result |
|---|---|---|---|---|
| 81,920 | 488.7 | 20.5 | 14,001 MiB | ok |
| 98,304 | 497.7 | 20.8 | 14,673 MiB | ok |
| **114,688** | **495.2** | **20.7** | 15,345 MiB | **chosen — largest that survives a request** |
| 131,072 | — | — | 15,741 MiB | **loads, then core-dumps on the first real request** |

**Qwen3-Coder-30B-A3B IQ2_M — MoE 30B/3B, 10.09 GiB weights, 51 KiB/token**

| ctx | prefill t/s | decode t/s | peak VRAM | result |
|---|---|---|---|---|
| 81,920 | 2,265.7 | 66.7 | 15,217 MiB | ok |
| **90,112** | **2,250.5** | **67.0** | 15,673 MiB | **chosen — largest that fits** |
| 98,304 | — | — | — | load fails: out of memory |
| 131,072 | — | — | — | load fails: out of memory |

**Qwen3.5-4B Q4_K_S — 2.41 GiB weights, 17 KiB/token**

| ctx | prefill t/s | decode t/s | VRAM at load | result |
|---|---|---|---|---|
| **100,000** | **2,702.6** | **90.9** | **5,358 MiB** | light variant (`4b-100k`) |
| **262,144** | **2,693.5** | **90.9** | 9,316 MiB | **chosen — native max** |

**Qwen3.6-35B-A3B IQ2_XXS — hybrid MoE, 10.02 GiB weights, 10.6 KiB/token**

| ctx | prefill t/s | decode t/s | peak VRAM | result |
|---|---|---|---|---|
| **262,144** | **2,057.0** | **89.4** | 14,763 MiB | **chosen — full native window** |

### 18.4 The internal GPU (AMD iGPU, Vulkan)

Same 4B, `--device Vulkan0`, `ngl 999`, q8_0 KV, batch 512:

| ctx configured | prefill t/s | decode t/s | wall | RAM |
|---|---|---|---|---|
| 32,768 | 129.3 | 11.7 | 73 s | — |
| 262,144 | 128.0 | 11.7 | 73 s | 15 GiB of 30 GiB |

Roughly **8x slower decode and 21x slower prefill** than the same model on the
eGPU (91.3 / 2,705). Configuring more context costs nothing in speed — only RAM.

### 18.5 Both GPUs at once

Same prompt fired at `:8080` (eGPU) and `:8097` (iGPU) simultaneously:

| Where | model | prefill t/s | decode t/s | note |
|---|---|---|---|---|
| eGPU :8080 | Qwen3.6-35B-A3B @ 262,144 | 1,858 | **92.7** | peak 14,764 MiB / 16,384, 95% util |
| iGPU :8097 | Qwen3.5-4B @ 262,144 | 8.2 | **9.0** | concurrent with the above |

**Decode coexists; prefill contends.** The eGPU's decode was unaffected (92.7 vs
89.4 solo) while the iGPU's prefill collapsed **128 → 8.2 t/s (15x)** — it reads
weights and KV from system RAM and competes with the eGPU model's CPU threads.

### 18.6 Two things that do NOT change speed

- **The configured context ceiling.** The 4B measured *identically* at 100,000
  and at 262,144 (decode 90.9 both, prefill 2,702.6 vs 2,693.5). A smaller
  ceiling buys ~4 GiB of memory, nothing else. Attention cost follows the context
  actually in use.
- **Concurrency, for the eGPU.** Running the internal-GPU server alongside it did
  not slow the 3080's decode.

### 18.7 Failures and traps observed on this host

| Symptom | Cause | Resolution |
|---|---|---|
| Prefill at CPU speed with the GPU at 100% and 115 W | `iq4_nl` KV → attention op silently scheduled to the CPU | use `q8_0`/`q8_0`; K must equal V |
| 131,072 "works" then the model core-dumps | load succeeded at 15,741 MiB, no headroom for compute | treat 114,688 as the real ceiling |
| `CUDA error: out of memory` at 15,976 MiB on a 262,144-ctx model | the router preset INI defaulted to batch/ubatch **4096** while every verified config used **2048** | INI defaults are now 2048/2048, threads 16 |
| A model "present" per the registry fails to load | an unfinished `.part` download, or `models_dir` not pointing at LM Studio's folder | check for `.part`; `llama-models defaults` |
| Numbers far below a recorded value | measured at a different context, or on a validated-but-wrong KV config | compare at equal context; check the KV types in the router log |
| A launcher dies between commands | the shell that spawned it was torn down with its process group | run it under systemd (`llama-igpu.service`) |

### 18.8 Two misdiagnoses worth remembering

While chasing the slowness I first blamed **battery power capping**, then
**context length**. Both were wrong, and the second was the more dangerous kind
of wrong — plausible, arithmetically tidy, and unsupported. The actual cause was
the silent KV-type fallback in §18.2. The context-length effect is real but
secondary; the battery reading was a single `/sys/class/power_supply` status
string I never tested against an alternative.

Record the mechanism, not the correlation.

### 18.9 Qwen3.5-9B Q4_K_S — the model that arrived later the same day

Weights **5.02 GiB**. Geometry: **32 blocks, only 8 KV-bearing, 4 KV heads x
256** — a hybrid, so its q8_0 KV is **17.0 KiB/token**, the same rate as the 4B.

| Where | ctx | prefill t/s | decode t/s | VRAM / RAM | note |
|---|---|---|---|---|---|
| eGPU 3080 | **262,144** | **1,797.8** | **61.5** | 11,470 MiB at load | native window, chosen |
| eGPU 3080 | 100,000 | 1,783.0 | 61.8 | 7,512 MiB at load | light variant |
| internal iGPU (Vulkan) | 262,144 | 80.8 | 7.1 | ~9 GiB RAM (load 10 s) | works; a better quality/size fit there than the 4B |

The 9B repeats the pattern exactly: the ceiling changes memory (~4 GiB between
100,000 and 262,144) and nothing else — decode 61.5 vs 61.8 t/s.

**Registry:** `9b`, `9b-swap`, `9b-highctx`, `9b-highctx-swap` all point at this
file and now all carry the verified **262,144** window with `kv: q8_0`,
`batch: 2048`, `threads: 16`. The legacy `9b-highctx` identity has been collapsed
into `qwen3.5-9b@q4_k_s` — it existed to offer a second context size, and a
second context size is not a second capability. The light option is now an
explicit pair, `9b-100k` / `9b-100k-swap` -> `qwen3.5-9b-100k@q4_k_s`.

**Total on this host:** nine router aliases over six real models, every one
measured, every window read back from `/props`.
