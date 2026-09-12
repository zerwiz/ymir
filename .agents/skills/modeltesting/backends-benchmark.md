# pi Backend Benchmark: Ollama vs LM Studio vs llama.cpp

Benchmark investigation into local backend performance on zerwiz — how to
measure correctly, what the current (imperfect) measurements show, and what
needs re-testing.

- Date: 2026-09-04 (ongoing)
- Machine: zerwiz (Ubuntu 26.04, RTX A5000 Laptop 16 GB VRAM, 16 cores, 122 GiB RAM)
- Reporter: zerwiz
- Status: **methodology documented, key findings from flawed runs recorded, clean re-benchmark needed**

---

## 1. TL;DR

- **User requirement:** **100K+ context for coding** that runs at **GPU speed**
  (not CPU crawl).
- **Current state of knowledge:**
  - LM Studio at 139K ctx runs on **CPU** (0% GPU util, ~100 tok/s prefill).
  - Ollama `qwen3.5:9b-highctx-262k` *reported* 100% GPU / 1532 tok/s — BUT
    there is a serious doubt whether it actually ran at 262K context (Ollama's
    default context is 4096, see §3).
  - Both engines are llama.cpp under the hood. On identical files at identical
    context, raw llama.cpp is ~10% faster than Ollama and ~2% faster than LM
    Studio (per published benchmarks, §3). On identical files at identical context
    *on this machine*, the difference was NOT isolated cleanly.
- **Critical flaw in prior testing:** previous runs did NOT unload the model
  between tests. The GPU held residual memory from earlier runs. This means
  numbers across sessions are not comparable and may be wrong.
- **What we DO know (robust, not contaminated):**
  - LM Studio's qwen3.5-9b at 139K ctx = 0% GPU util during prefill.
  - The standalone Unsloth llama.cpp (no CUDA) at 139K ctx = 0% GPU util.
  - LM Studio's `--mlock` fails (8 MB limit) — logged in LM Studio server output.
  - LM Studio 0.4.20, CUDA engine 2.32.0 selected, 0.4.23 available.
- **What we DON'T know yet (needs clean re-bench):**
  - Whether Ollama highctx actually ran at 262K or silently at 4096.
  - True head-to-head: same file, same ctx, each engine loaded fresh.
  - Whether a text-only 9B GGUF (no mmproj) fits 100K+ KV on the 16 GB card
    at GPU speed.

---

## 2. The question

Running the same Qwen3.5-9B through pi, Ollama at 190K/262K context *felt*
~10x faster than LM Studio at 139K context. Which backend is actually fast
at 100K+, and what is the real bottleneck?

---

## 3. How to benchmark correctly (methodology)

### Sources

- [InventiveHQ: llama.cpp vs Ollama vs LM Studio (2026)](https://inventivehq.com/blog/ollama-vs-llama-cpp-vs-lm-studio-benchmark) — measured 10% llama.cpp advantage, 12-prompt suite, wall-clock tok/s
- [rajbos benchmark gist](https://gist.github.com/rajbos/8c9a5bfb832469db52482082f88aae06) — kills LM Studio between providers, `ollama stop` before each run
- [SupermodularAI local_bench](https://github.com/SupermodularAI/local_bench) — documents Ollama's context trap (see below)
- [localaimaster.com](https://localaimaster.com/blog/benchmark-local-ai-setup) — warmup, seed, API-based TTFT measurement
- [markaicode.com](https://markaicode.com/benchmarks/ollama-vs-llamacpp-benchmark) — reproducible protocol, lock GPU clocks, 5 iterations drop first

### The five numbers that matter

| # | Metric | What it measures |
|---|---|---|
| 1 | **Prefill (prompt eval) tok/s** | How fast the model ingests the prompt. Dominates large-context workloads. |
| 2 | **Decode (eval) tok/s** | How fast the model generates output tokens. |
| 3 | **TTFT (time to first token)** | Wall-clock from request to first emitted token. Perceived latency. |
| 4 | **Peak VRAM (GB)** | Max GPU memory used. Determines what context sizes are feasible. |
| 5 | **GPU utilization (%)** | Whether the GPU is actually doing the work, or the CPU is. |

### Critical pitfalls — why most online benchmarks are wrong

1. **The Ollama Context Trap** (SupermodularAI):
   > "Ollama loads a model at 4096 tokens by default, no matter what the model
   > supports (Gemma 3 advertises 131072 and still loads at 4096). A prompt past
   > that is not rejected and does not error — Ollama discards the older half of
   > the context and evaluates the rest."

   **This means any Ollama number without an explicit `num_ctx` in the API call
   or `OLLAMA_NUM_CTX` env var is suspect.** The "262K" context Ollama reported
   may have been 4096 effective context, silently truncated — which would
   explain why it appeared ~10x faster than LM Studio at true 139K.

2. **Memory not unloaded between runs:**
   The rajbos gist explicitly kills LM Studio (`Stop-Process -Force`) and calls
   `ollama stop` before each provider test so they "don't compete for the same
   VRAM." Without this, a previously loaded model's weights/KV remain resident,
   inflating or contaminating the next measurement. **Our prior tests did NOT do
   this — the highctx model was still in VRAM when we loaded the LM-Studio GGUF
   through Ollama.**

3. **No warmup run:**
   First load of a model is always slow (cold weights, JIT, page faults). Must
   discard the first run. Protocol: `ollama run ... "warmup" > /dev/null` before
   the actual timed run.

4. **Same seed required:**
   Without `--seed 42` (or `temperature: 0, seed: 42` in the API), different
   runs generate different tokens, making decode tok/s non-comparable. Ollama
   supports seed in the API; LM Studio does not always propagate it.

5. **GPU clock not locked:**
   NVIDIA GPU clocks vary with load/thermal state. Lock them before benchmarking:
   ```
   sudo nvidia-smi -lgc <min>,<max>   # lock GPU clock
   sudo nvidia-smi -lmc <min>,<max>   # lock memory clock
   ```
   Unlock after: `sudo nvidia-smi -rgc` / `sudo nvidia-smi -rlmc`.

6. **Wall-clock vs self-reported:**
   LM Studio and Ollama both report `prompt_eval_rate` internally, but these
   don't include HTTP overhead, templating, or scheduling. The InventiveHQ
   protocol measures `completion_tokens / wall_clock` for end-to-end speed.
   llama.cpp self-reports are more accurate since they measure inside the engine.

7. **Same quantization, same file:**
   Two "Q4_K_M" quants from different sources may differ. Best to use the
   *exact same GGUF file* across all engines. Or at minimum, same quantization
   from the same source.

### Correct benchmark procedure

```bash
# === 0. Environment snapshot ===
nvidia-smi --query-gpu=name,driver_version,clocks.gr,clocks.mem,memory.total \
  --format=csv
uname -a
ollama --version

# === 1. Lock GPU clocks (requires sudo) ===
sudo nvidia-smi -lgc 1900,1900
sudo nvidia-smi -lmc 7000,7000

# === 2. Unload everything — critical ===
ollama stop 2>/dev/null
pkill -f "lm-studio" 2>/dev/null          # or use lms CLI if available
pkill -f "llama-server" 2>/dev/null
sleep 5
nvidia-smi --query-gpu=memory.used --format=csv,noheader   # must show baseline

# === 3. Warmup (discard) ===
ollama run <model> --verbose "warmup" > /dev/null 2>&1

# === 4. Timed run — Ollama ===
curl -s http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "<model>",
    "prompt": "<your test prompt>",
    "stream": false,
    "options": {
      "num_ctx": <EXPLICIT_CONTEXT_SIZE>,
      "temperature": 0,
      "seed": 42,
      "num_predict": 5
    }
  }' | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(f'prefill: {d[\"prompt_eval_count\"]} tok, {d[\"prompt_eval_count\"]/(d[\"prompt_eval_duration\"]/1e9):.1f} tok/s')
print(f'decode:  {d[\"eval_count\"]} tok, {d[\"eval_count\"]/(d[\"eval_duration\"]/1e9):.1f} tok/s')
"

# === 5. Capture GPU state DURING run ===
# (run in parallel with step 4 in another terminal)
for i in $(seq 1 15); do
  nvidia-smi --query-gpu=utilization.gpu,memory.used --format=csv,noheader
  sleep 1
done

# === 6. Unload before next engine ===
ollama stop
sleep 3
nvidia-smi --query-gpu=memory.used --format=csv,noheader   # confirm clean

# === 7. Load next engine, repeat from step 3 ===

# === 8. Unlock GPU clocks ===
sudo nvidia-smi -rgc
sudo nvidia-smi -rlmc
```

### Benchmarking each engine specifically

**Ollama:**
- Always pass `num_ctx` explicitly in API calls — never rely on defaults.
- `ollama ps` shows loaded model, context size, and `PROCESSOR` split.
- `ollama stop` to unload. Verify with `nvidia-smi`.
- API: `POST /api/generate` (non-streaming) returns `prompt_eval_count`,
  `prompt_eval_duration`, `eval_count`, `eval_duration` in nanoseconds.
- CLI: `ollama run <model> --verbose` prints the same at the end.

**LM Studio:**
- Model loaded via GUI or API (`POST /api/v1/models/load`).
- Context length set per-model in the load config: `llm.load.contextLength`.
- GPU offload slider (gear icon) must be at max; verify with `nvidia-smi`.
- API: `POST /v1/chat/completions` — `usage.prompt_tokens` and timing in
  the response, but NOT as fine-grained as Ollama's self-report.
- To unload: either the GUI, or restart the app. `pkill -f lm-studio` works
  but the app restarts via systemd autostart — check for lingering processes.
- Headless option: `lmstudio server` or `llmster` (daemon mode).

**llama.cpp (raw):**
- Compile with CUDA: `cmake -DGGML_CUDA=ON ..` (verify: `./llama-cli --help`
  shows `--gpu-layers`).
- Server: `./llama-server --model <file> --ctx-size <N> --n-gpu-layers 999999
  --flash-attn on --n-predict 5`.
- CLI: `./llama-cli --model <file> --ctx-size <N> --n-gpu-layers 999999
  --prompt "<text>" --n-predict 5`.
- Self-reports: `llama_print_timings()` at the end gives prompt eval and
  eval tokens/sec directly.
- Most accurate engine numbers — no wrapper overhead. The reference standard.

### What published benchmarks say (for context)

| Source | llama.cpp vs Ollama | llama.cpp vs LM Studio |
|---|---|---|
| InventiveHQ (2026, RTX 5060 Ti) | llama.cpp **10.3% faster** (77.0 vs 69.1 tok/s) | LM Studio within **2%** of llama.cpp |
| BestLLMfor (2026, Qwen3-Coder 32B) | — | LM Studio 20-25% ahead on Apple Silicon (MLX) |
| localaimaster (2026, RTX 4090) | llama.cpp **14.3% faster** (1842 vs 1624 prefill) | — |

The pure inference gap between llama.cpp, Ollama, and LM Studio on **NVIDIA
hardware with the same GGUF** is typically **3–15%** — NOT 10x. A 10x gap
indicates a setup problem (wrong backend, wrong context, memory not unloaded,
CPU fallback), not an engine difference.

---

## 4. What we know (robust findings — not contaminated)

These findings are based on direct observation of running processes and
server logs, not comparative benchmarks that required memory isolation.

### LM Studio runs on CPU for prefill at 139K context

**Evidence:**
- `nvidia-smi` during LM Studio prefill: **0% GPU utilization, 8718 MiB used**
  (flat — no KV arriving on GPU).
- GPU memory never climbed above 8718 MiB despite LM Studio estimating
  the model needs **~10.4 GB** (7.4 GB weights + 2.9 GB KV at 139K).
- LM Studio's llama-server logs show `failed to mlock 572129280-byte buffer`
  (572 MB — the memlock limit on this box is 8 MB, see §6).

### Standalone llama.cpp (no CUDA) confirmed: offload is the bottleneck

Running `/home/zerwiz/.unsloth/llama.cpp/llama-server` directly (no CUDA
backend compiled in) with the same GGUF at 139K:
- GPU: 0% util, memory unchanged.
- Same prompt took **41.8 s** — same ~100 tok/s class as LM Studio.
- No CUDA/offload log lines in output → confirmed CPU-only.

This proves: if llama.cpp has no CUDA, or can't fit the model on the GPU,
prefill runs on CPU at ~100 tok/s regardless of the wrapper (LM Studio,
Ollama, or raw llama.cpp).

### LM Studio server flags are correct (but insufficient)

LM Studio launches llama-server with near-ideal flags:
```
--n-gpu-layers 999999 --flash-attn on --kv-offload --kv-unified
--cache-type-k q8_0 --cache-type-v q4_0 --mlock
```
The request is for full GPU offload. The problem is the working set
(model + KV + mmproj) does not fit in the available VRAM after the
driver overhead (~2 GB) is accounted for.

### LM Studio version/runtime

- App: 0.4.20 (build 1), **0.4.23 available**.
- Engine: `llama.cpp-linux-x86_64-nvidia-cuda12-avx2@2.32.0` — correct CUDA
  engine selected (not CPU-only). 2.33.0 auto-downloading.
- Per-model config: `llm.load.contextLength = 138979`, `offloadKVCacheToGpu: true`.

### Both qwen3.5 models are multimodal

`ollama show qwen3.5:9b-highctx-262k` and base both list `Capabilities:
vision`. LM Studio's `qwen3.5-9b` loads `mmproj-F32.gguf`. So the
vision/mmproj path is NOT the differentiator between the two — both have it.

---

## 5. What we think we know (contaminated — needs clean re-test)

**CAUTION:** the following numbers were gathered without unloading the model
between tests and without verifying the Ollama context trap (§3). They may
be valid or may be measuring residual VRAM effects. Flagged for re-testing.

### Contaminated data: LM Studio GGUF through Ollama at different contexts

Tested `ollama create` of LM Studio's exact GGUF (`Qwen3.5-9B-Q4_K_S.gguf`
+ `mmproj-F32.gguf`) through Ollama:

| Context | Prefill tok/s | Processor split |
|---|---|---|
| 16384 | 847 | 6.4 GB → 28%/72% CPU/GPU |
| 139008 | 106 | 11 GB → 58%/42% CPU/GPU |

**Why this is contaminated:**
- The highctx Ollama model was potentially still resident in VRAM from the
  prior test (was `ollama stop` called? unclear).
- The Ollama context trap (§3) means the 139K run may not have actually
  allocated 139K of KV cache — it may have silently run at 4096.

**What it MIGHT indicate (if repeated cleanly):**
- The Qwen-VL file with mmproj at 139K cannot fit fully on the 16 GB card.
- The same file at 16K fits better → more GPU residency → faster prefill.

### Contaminated data: Ollama highctx at "262K"

Ollama `qwen3.5:9b-highctx-262k` with a ~2560-token prompt:
- Reported: 14 GB on GPU, 100% GPU, 1532 tok/s prefill.

**Why this is contaminated:**
- Was memory fully clean before this run? Unknown.
- Did Ollama actually allocate 262144 of KV cache, or silently run at 4096?
  The SupermodularAI finding says Ollama defaults to 4096 unless `num_ctx`
  is explicitly passed. No explicit `num_ctx` was used in this test.
- If the model actually ran at 4096 context, the 1532 tok/s is for a
  ~4096-window prefill, NOT a 262K-window prefill — a completely different
  measurement.

**To verify:** run with explicit `num_ctx: 262144` in the API call, confirm
`ollama ps` shows `CONTEXT 262144`, confirm `nvidia-smi` shows full GPU
memory usage during prefill, and compare `prompt_eval_count` to the
estimated token count of the prompt.

---

## 6. The `ulimit -l` (memlock) angle

LM Studio's llama-server uses `--mlock` to pin buffers in RAM. On this box:

- systemd user manager applies `DefaultLimitMEMLOCK = 8388608` (8 MB).
- The model needs to lock ~572 MB → `mlock()` fails (logged as warning).
- GNOME-spawned per-app scopes don't inherit the fix even after
  `daemon-reload` + `daemon-reexec`.

Impact is secondary to GPU residency, but worth clearing for completeness.

**Fix (requires sudo):**
```
# /etc/systemd/user.conf.d/memlock.conf
[Manager]
DefaultLimitMEMLOCK=infinity
```
Then `systemctl --user daemon-reload && systemctl --user daemon-reexec`.
**Known issue:** GNOME app scopes may still apply 8MB. Verified on this box.

---

## 7. Fixes — to get 100K+ context that is fast

Ordered by leverage. **All require clean re-testing to validate.**

1. **Verify the Ollama highctx path actually works at true 262K.** Pass
   `num_ctx: 262144` explicitly, confirm `ollama ps` shows 262144 context,
   confirm GPU memory is >12 GB during prefill, and measure prefill tok/s
   against the actual token count of the prompt. If this works, the path
   to 100K+ fast coding is simply using Ollama at a big explicit context.

2. **Test a text-only 9B GGUF (no mmproj) at 100K+** — dropping the 1.8 GB
   mmproj leaves more room on the 16 GB card. If weights + 100K KV fit,
   prefill stays on GPU.

3. **Update LM Studio 0.4.20 → 0.4.23** (and engine 2.32 → 2.33) — may
   carry GPU-offload or KV-cache residency improvements.

4. **Use raw llama.cpp** (compiled with CUDA) — the 10-15% overhead of
   Ollama's wrapper is real (InventiveHQ data). For maximum throughput,
   `llama-server` with `--n-gpu-layers 999999 --flash-attn on --ctx-size <N>`
   is the reference standard. But on this box the Unsloth build has no CUDA —
   a CUDA build is needed.

5. **Raise memlock** (§6) — secondary, but clears the `failed to mlock` warning.

---

## 8. Notebook — raw data (flagged for contamination)

- LM Studio loaded: `qwen3.5-9b | ctx: 139008 | kv_gpu: True | fa: True`
- LM Studio small prompt (~50-token completion): **1.17 s**
- LM Studio large prompt (~2560-token): **~11 s** (~100 tok/s prefill)
- Ollama highctx same large prompt (UNVERIFIED ctx): **~4.5 s**, 1532 tok/s
- GPU state during LM Studio prefill: **0% util, 8718 MiB** (flat)
- GPU state baseline: **8726 MiB used, 7257 MiB free**
- LM Studio server: `127.0.0.1:33199`, key `NtGZe...` (session-specific)
- LM Studio VRAM estimate: model 7.4 GB + KV 2.9 GB (139K) ≈ 10.4 GB
- Ollama process: `/usr/local/bin/ollama serve`; server: `/usr/local/lib/ollama/llama-server`
- LM Studio 0.4.20 → 0.4.23 available; CUDA12 engine 2.32.0, 2.33.0 downloading
- **Controlled test (CONTAMINATED — memory not unloaded):**
  - Same GGUF via Ollama, 16K ctx: 847 tok/s, 6.4 GB, 72% GPU
  - Same GGUF via Ollama, 139K ctx: 106 tok/s, 11 GB, 42% GPU

---

## 9. How to benchmark MoE models (added 2026-09-04)

The user asked to bench **qwen3.5-9b** (dense), **qwen3.6-35b-a3b** (MoE),
and **qwen3.8** (new). MoE models behave differently from dense ones, so they
benchmark differently. This section documents how, sourced from published
16GB-VRAM data, llama.cpp MoE offload guides, and a real MoE VRAM benchmark
suite.

### 9.1 MoE in one paragraph

A **dense** model activates every parameter per token. A **Mixture-of-Experts
(MoE)** model stores many small "expert" FFN sub-networks but only activates a
fraction per token. E.g. `Qwen3.6-35B-A3B` = **35B total** parameters stored in
memory, **~3B active** per token ("A3B"). Three components live on the model:

| Component | Always active? | Notes |
|---|---|---|
| Attention layers | Yes | Every token passes through; GPU-critical, latency-sensitive |
| Dense / shared-expert FFN | Yes | Always run |
| Routed-expert FFN | No (sparse) | Bulk of the params; only ~1/N touched per token |

Key consequence: **MoE cuts compute (speed) but NOT memory** — all experts must
stay resident even if only a few run per token. On a 16GB VRAM card the right
play is **`--cpu-moe` / `--n-cpu-moe`**: keep attention + KV on GPU, push the
big routed-expert FFN to system RAM. Because only a couple of experts are read
per token, RAM is touched lightly → decode stays fast.

### 9.2 Test targets (the three models)

| Target | Arch | Guess on this 16 GB A5000 | Reference (16 GB, llama.cpp) |
|---|---|---|---|
| `qwen3.5-9b` (`Q4_K_S`, 5.4G file) | dense ~9B | fits GPU, ~140-150 t/s | (matched the 139K-ctx config already on this box) |
| `qwen3.6-35b-a3b` | MoE | Q4 ~20 GB **won't fit**; use `--cpu-moe` or an IQ3_XXS/IQ3_S quant | glukhov: `35B-A3B-UD-IQ3_XXS` = **~147 t/s, 13.8GB, 96%/100%** GPU at 19K-64K ctx; IQ3_S handles **100K context with no perf drop** |
| `gemma-4-26B-A4B` | MoE (A4B active) | Q5 21.2 GB **won't fit**; use IQ4_XS/IQ3 (~13-14 GB) | glukhov: `gemma-4-26B-A4B-it-UD-IQ4_XS` = **~121 t/s @19K, ~114 @32K, ~96 @64K**, ~13.4 GB, 95%/100% GPU |
| `qwen3.8-27b` | hybrid-attn (dense-fit) | 13.1 GB Q3_K_XL fits | §9.6 (identified on disk) |

Published reference numbers from R. Glukhov (RTX 4080 16 GB, llama.cpp, no
`-ngl` finetune):
- `Qwen3.6-35B-A3B-UD-IQ3_XXS`: **147.5 t/s @19K, 149.1 @32K, 145.8 @64K** — flat
  across context because it stays GPU-resident (96%/100% load).
- `Qwen3.5-35B-A3B-UD-IQ3_S`: **~136-138 t/s**, 88-93%/100% GPU, and
  author-confirmed it **fits 100K context with no perf drop** in VRAM.
- `gemma-4-26B-A4B-it-UD-IQ4_XS`: ~121 t/s @19K, ~114 @32K, ~96 @64K.
- Heart of it: **MoE at low quant is the realistic path to 100K+ fast context
  on 16 GB VRAM** — a dense 9B can't hold a big KV cache + weights and still
  offload to GPU, but a low-quant MoE can.

### 9.3 Correct procedure — mirrors §3 but MoE-aware

Only add these on top of the §3 rules (unload between runs, lock clocks, warm
up, explicit `num_ctx`, seed, temp=0). MoE-specific:

1. **Choose the offload strategy per candidate, don't brute-force.**
   - Dense `qwen3.5-9b`: pure GPU, `-ngl 999`.
   - MoE `qwen3.6-35b-a3b` @ Q4 (won't fit): `-ngl 999 --cpu-moe` (all routed
     experts → CPU, attention → GPU). Then sweep `--n-cpu-moe N` to pull as
     many experts back onto GPU as fit.
   - MoE @ low quant (IQ3_XXS / IQ3_S): likely fits entirely, so pure GPU first.
2. **Pass `--cpu-moe` vs `--n-cpu-moe` — don't mix.**
   `--cpu-moe` = *all* routed experts to CPU. `--n-cpu-moe N` = a dial to put
   N layers' experts on CPU (starting from the *highest*-numbered layers).
   They express the same split; using both is confusing.
3. **Verify placement, don't assume.** Read llama.cpp's load log: confirm
   attention is on CUDA and the expert tensors are really on CPU. An
   `-ot`/`--n-cpu-moe` regex that matches nothing silently offloads nothing →
   you OOM silently.
4. **Raise batch size for GPU offload prompt processing.** For CPU+GPU MoE,
   `-b 4096 -ub 4096` is the common recommendation (physical `ub` drives VRAM
   compute-buffer use — may need to drop a few expert layers to fit it).
5. **Quantize + shrink the KV cache to buy expert VRAM.** Enable flash
   attention (`--flash-attn on`), and use quantized KV (`--cache-type-k q8_0
   / --cache-type-v q4_0`, or q4_0/q4_0) — this directly reclaims VRAM that can
   instead hold experts (or a bigger context). See the esonhjz suite, which
   got a 35B MoE under **4,000 MiB** with `-ncmoe 999 -fa on -ctk q4_0 -ctv
   q4_0 -lm none -c 260000`.
6. **Measure prefill and decode SEPARATELY.** MoE expert-offload hurts
   **prefill** (long-prompt processing, compute-bound) far more than
   **decode** (generation, bandwidth-bound). For our long-context *coding*
   use case, **time-to-first-token on a big prompt is the number that
   matters** — record it, not just t/s.
7. **Watch RAM bandwidth.** When experts live in RAM, system memory bandwidth
   caps decode. If generation is slow and the GPU is underused, it's almost
   always RAM bandwidth, not core count — and it explains why the same model
   differs across boxes.

### 9.4 Known-good MoE llama.cpp launch (16 GB class)

From the esonhjz VRAM-saver suite and DocShotgun's guide — the shape to test
against (adjust `-c`, quant, and `--n-cpu-moe` per candidate):

```
llama-server \
  -m <model>.gguf \
  -ngl 999 --n-cpu-moe 999 \      # alternative: --cpu-moe
  --flash-attn on \
  --cache-type-k q4_0 --cache-type-v q4_0 \
  -c 100000 -b 4096 -ub 4096 \
  -t 8 --jinja
```

The esonhjz measured outcome on that exact recipe (Qwen 3.6 35B-A3B
Q4_K_M, 16 GB card):
- Pure-GPU brute force (`-ngl 99`, no strategy): **114 prefill / 11 gen
  t/s**, 15.7 GB VRAM 🔴.
- VRAM-saver (`--n-cpu-moe 999 -fa -ctk q4_0 -ctv q4_0`): **1,041 prefill /
  52 gen t/s**, **~3.9 GB** VRAM 🟢.

That 9× prefill / 4.8× gen win is precisely the MoE trick this doc's larger
goal (100K+ fast) depends on.

### 9.5 Ollama specifics for MoE

Ollama hides `--n-cpu-moe`/`-ot`. For MoE it only exposes
`OLLAMA_NUM_GPU` / `num_gpu`. So for MoE **on Ollama**, you mostly get whatever
default llama.cpp picks; if it can't fit, it spills to CPU automatically. To
reproduce a controlled comparison, prefer raw llama.cpp (or LM Studio's
launch args) where you control `--n-cpu-moe`, KV quant, and batch explicitly.
If comparing Ollama for MoE, at minimum: pass explicit `num_ctx` in the API
call and confirm `ollama ps` shows your target context (not the 4096 default —
the "context trap" from §3/§5).

### 9.6 qwen3.8 identification (answered)

Inspected on disk (`~/Models/unsloth/Qwen3.8-27B-GGUF/`):
- Arch: `Qwen3_5ForConditionalGeneration`, model_type `qwen3_5`.
- **Hybrid attention**: `layer_types` alternate `linear_attention` +
  `full_attention` (linear-attention fast path with periodic full attention) —
  NOT a classic FFN-expert MoE, and not a plain dense attention model.
- Multimodal (`mmproj-F16.gguf` present, ~0.9 GB).
- On disk: `Qwen3.8-27B-UD-Q3_K_XL.gguf` **13.1 GB** (27B params, Q3_K_XL).
- **Fit on 16 GB:** ~13.1 GB weights + KV → likely fits pure GPU at a moderate
  context. Its hybrid linear-attention KV cache class makes it attractive for
  long context, since linear attention keeps the KV footprint small.

So for the bench, `qwen3.8-27b` is treated as a **dense-fit hybrid-attention**
model (no `--n-cpu-moe` needed if it fits), unlike the 35B-A3B MoE. Verify by
loading and watching `nvidia-smi` before assuming.

---

## 10. Benchmark matrix — qwen3.5-9b / qwen3.6-35b-a3b / qwen3.8-27b / gemma-4-26b-a4b

Concrete test plan for the requested models. Files confirmed on this box:

| # | Model served | On-disk file | Size | Arch class | Fit 16 GB | Strategy |
|---|---|---|---|---|---|---|
| A | `qwen3.5-9b` | `Qwen3.5-9B-Q4_K_S.gguf` (+mmproj-F32) | 5.4 GB | dense | yes (fits) | pure GPU, `-ngl 999` |
| B | `qwen3.6-35b-a3b` | `Qwen3.6-35B-A3B-UD-Q2_K_XL` (12.3G), `-UD-Q4_K_S` (20.9G), or `iq3_s` (13.7G) | 12.3-20.9 GB | **MoE** | Q4 no / Q2/iq3 mostly | `--n-cpu-moe` sweep; KV-quant |
| C | `qwen3.8-27b` | `Qwen3.8-27B-UD-Q3_K_XL.gguf` (+mmproj-F16) | 13.1 GB | hybrid-attn (dense-fit) | yes (fits) | pure GPU, `-ngl 999` |
| D | `gemma-4-26b-a4b` | `gemma-4-26B-A4B-it-UD-Q5_K_XL.gguf` (+mmproj-F32) | 21.2 GB (Q5) | **MoE** (A4B active) | Q5 no; IQ4_XS/IQ3 yes | **MoE** strategy (§9); get a lower quant or use `--n-cpu-moe` |

### 10.1 Context sizes

Run every model at **80K and 100K** context (the user's goal is **min 80K**,
ideally 100K+; iterated beyond the original 19/32/64K table). If a model/quant
can't hold a size on GPU, **running on CPU is acceptable** — record where it
spills to CPU and at what point t/s collapses; that's the finding. Add 64K as a
reference point only if it helps show where the model starts to spill.

### 10.2 Per-run metrics (§3 + §9)

For each model × context × strategy, record:
- **Generation t/s** (decode)
- **Prefill t/s** and **TTFT** at a big prompt (~2–16k tokens) — critical for
  coding
- **Peak VRAM** (GB) and GPU/CPU load % during prefill + decode
- Ollama: explicit `num_ctx`, then confirm `ollama ps` shows the target context
  (the §3/§5 4096-default trap)
- For model B (MoE): which layers landed on CPU (`--n-cpu-moe N`), RAM
  bandwidth hitting decode?

### 10.3 Command shapes per model

```bash
# A + C (dense-fit): pure GPU
llama-server -m <file> -ngl 999 --flash-attn on -c 100000 -b 4096 -ub 4096 -t 8 --jinja

# B (MoE) Q4 when it must spill:
llama-server -m Qwen3.6-35B-A3B-UD-Q4_K_S.gguf -ngl 999 --n-cpu-moe <sweep> \
  --flash-attn on --cache-type-k q4_0 --cache-type-v q4_0 -c 100000 -b 4096 -ub 4096 -t 8 --jinja

# B at low quant (iq3_s / Q2_K_XL) — likely full GPU:
llama-server -m qwen3.6-35b-a3b-iq3_s.gguf -ngl 999 --flash-attn on -c 100000 -b 4096 -ub 4096 -t 8 --jinja

# D (gemma-4-26b-a4b) MoE — Q5_K_XL (21.2 GB) won't fit 16 GB alone:
#   option 1 — pull an IQ4_XS/IQ3 quant (fits ~13-14 GB, pure GPU):
#     llama-server -m gemma-4-26B-A4B-it-UD-IQ4_XS.gguf -ngl 999 --flash-attn on -c 100000 -b 4096 -ub 4096 -t 8 --jinja
#   option 2 — Q5_K_XL with expert spill:
#     llama-server -m gemma-4-26B-A4B-it-UD-Q5_K_XL.gguf -ngl 999 --n-cpu-moe <sweep> \
#       --flash-attn on --cache-type-k q4_0 --cache-type-v q4_0 -c 100000 -b 4096 -ub 4096 -t 8 --jinja
```

### 10.4 Expected / reference values to sanity-check against

From glukhov (RTX 4080, 16 GB, llama.cpp), same model class:
- `Qwen3.6-35B-A3B-UD-IQ3_XXS`: **~147 t/s**, ~13.8 GB, 96%/100% GPU — flat
  19K→64K; IQ3_S confirmed to fit **100K** context w/o perf drop.
- `Qwen3.5-27B-UD-IQ3_XXS` (closest to our qwen3.8-27b): ~45 t/s @19-32K
  (dense, smaller active compute), uses ~13 GB.
Our A5000 (16 GB) is slower than a 4080, so treat these as upper bounds.

### 10.5 Record here (tables to fill after the clean run)

**Hardware baseline (zerwiz, this box):** RTX A5000 Laptop 16 GB (max 1635 MHz
gfx / 6001 MHz mem), i9-11950H 8c/16t @ 2.6-5.0 GHz, 122 GB RAM.

**Context is genuinely high on the built Ollama models** (verified via
`ollama show` / the Modelfiles in `~/`):
- `qwen3.5:9b-highctx-262k` — `num_ctx 262144` (262K)
- `qwen3.5:9b-highctx-196k` — `num_ctx 196608` (196K)

So the "262K" is **not** a 4096-trap and **not** fake for these models — the
Modelfiles set `num_ctx` explicitly. The only real, narrow caveat is physical:
a 262K/196K KV cache is large, so on 16 GB VRAM it may (or may not, for a 9B)
need CPU spill — that is what the clean runs below must measure, not something
to assert as "impossible." Earlier waffle about "262K = NO / not real" was
wrong for the highctx Modelfiles. **Bench targets: whatever context you want
(80K / 100K / 196K / 262K), GPU-first, CPU spill acceptable (122 GB RAM,
8 real cores).**

| Model | ctx | quant | engine | gen t/s | prefill t/s | TTFT | VRAM GB | GPU/CPU% | notes |
|---|---|---|---|---|---|---|---|---|---|
| qwen3.5-9b | 80K | Q4_K_S | | | | | | | |
| qwen3.5-9b | 100K | | | | | | | | |
| qwen3.6-35b-a3b | 80K | iq3_s | | | | | | | MoE |
| qwen3.6-35b-a3b | 100K | | | | | | | | |
| qwen3.8-27b | 80K | Q3_K_XL | | | | | | | hybrid-attn |
| qwen3.8-27b | 100K | | | | | | | | |
| gemma-4-26b-a4b | 80K | IQ4_XS (if pulled) | | | | | | | MoE |
| gemma-4-26b-a4b | 100K | | | | | | | | |

CPU-fallback runs (happy to accept — record gen t/s + TTFT + RAM used):
| Model | ctx | quant | engine | gen t/s | prefill t/s | TTFT | RAM GB | CPU threads | notes |
|---|---|---|---|---|---|---|---|---|---|
|  | 100K | | CPU | | | | | | |

### 10.5.1 CLEAN RESULTS — `qwen3.5:9b-highctx-196k` @ true 196,608 ctx (verified 2026-09-04)

Dense `qwen3.5-9b` (Q4_K_M, ~11 GB resident) loaded via Ollama at its full
`num_ctx 196608`. **This settles the §5 doubt for 196K**: it is a genuine
high-context load (not a 4096 trap) and it runs **GPU-first**, not CPU crawl.

**Environment:** baseline clean (26 MiB used) before load; model loaded with
`ollama run qwen3.5:9b-highctx-196k --verbose` → `ollama ps` shows
`11 GB | 100% GPU | CONTEXT 196608`. Peak VRAM 12,690 MiB. No CUDA llama.cpp
build used — this is Ollama's bundled engine, pure.

| Metric | Small prompt (3,308 tok) | Mid prompt (9,823 tok) | Big prompt (18,923 tok) |
|---|---|---|---|
| Prefill t/s | 126.7 | **1,634.8** | **1,606.2** |
| Decode t/s | 57.5 | 54.6 | 43.2 |
| Wall (total) | 26.3 s* | 6.8 s | 12.5 s |
| GPU util (prefill) | 0%*(sample gap) | **100% / 99% / 81–79%** | — |
| Peak VRAM | 12,690 MiB | 12,690 MiB | 12,690 MiB |

\* The small-prompt "126.7 tok/s / 0% GPU" is a **sampling artifact**: the prompt
was only 3,308 tokens so the fast prefill burst was missed by the 1 s GPU
sampler; the mid/big runs with a tighter 0.25 s sampler confirm **100% GPU** and
large prefill t/s. The model is GPU-resident (11 GB, 100% GPU in `ollama ps`).

**Bottom line for §10.5 / the matrix:**
- **196K fits on the 16 GB card** (12.7 GB peak, ~3.3 GB headroom) with
  GPU-class prefill (~1,600 t/s). No CPU spill.
- Confirms §7 fix #1: the steady path to 100K+ fast coding is **Ollama at an
  explicit big context**.
- Still to test: the **262K** model (does the larger KV still fit, or spill?);
  larger generation length (decode t/s here is a 5-token sample only); and the
  MoE models (§10.6).

**Filled matrix row (dense 9B, 196K):**

| Model | ctx | quant | engine | gen t/s | prefill t/s | TTFT | VRAM GB | GPU/CPU% | notes |
|---|---|---|---|---|---|---|---|---|---|
| qwen3.5-9b | 196K | Q4_K_M | Ollama | ~50 | ~1,600 | <6 s | 12.7 | 100% GPU | highctx-196k verified; fits |

**Filled matrix row (dense 9B, 262K) — verified 2026-09-04:**

`qwen3.5:9b-highctx-262k` loaded at true `num_ctx 262144`
(`ollama ps` → `14 GB | 100% GPU | CONTEXT 262144`). Mid prompt (9,823 tok):
prefill **1,645.6 t/s**, decode 55.4 t/s, wall 6.26 s, **peak VRAM 14,802 MiB**,
GPU util 100% / 99% during prefill. **Fits the 16 GB card with ~1.6 GB
headroom — no CPU spill.** Same run warmup + clean baseline (unloaded 196K →
26 MiB first). Confirms 262K is GPU-first, not a trap, not CPU crawl.

| Model | ctx | quant | engine | gen t/s | prefill t/s | TTFT | VRAM GB | GPU/CPU% | notes |
|---|---|---|---|---|---|---|---|---|---|
| qwen3.5-9b | 262K | Q4_K_M | Ollama | ~55 | ~1,646 | <7 s | 14.8 | 100% GPU | highctx-262k verified; fits |

**Both high-ctx dense-9B Modelfiles are now verified on this box:** 196K → 12.7
GB, 262K → 14.8 GB, both 100% GPU prefill ~1,600-1,645 t/s, no CPU spill. The
earlier ~10x-speed / 1532 t/s "262K" claim (§5) is **confirmed real** — it was
a genuine 262K load, and prefill is GPU-class. Remaining: MoE models (§10.6),
real decode-length generation, and the llama.cpp source-build comparison.

### 10.5.2 ALL Ollama models — full sweep (2026-09-04, adds to §10.5.1)

Clean-baseline run of every generation-capable Ollama model (unloaded each →
26 MiB between runs, warmup discarded, `temp 0, seed 42, num_predict 5`):

| Model | Modelfile num_ctx | ACTUAL ctx (`ollama ps`) | Prefill t/s | Decode t/s | Peak VRAM | Notes |
|---|---|---|---|---|---|---|
| `qwen3.5:9b-highctx-262k` | 262144 | **262,144** ✅ | 1,645.6 | 55.4 | 14,802 MiB | fits 16 GB |
| `qwen3.5:9b-highctx-196k` | 196608 | **196,608** ✅ | ~1,600–1,635 | ~43–58 | 12,690 MiB | fits 16 GB |
| `qwen3.5:9b-32k` | 32768 | **32,768** ✅ | 1,446.2 | 49.2 | 7,538 MiB | fits |
| `qwen3.5:9b` (base) | — | **4,096** ⚠️ trap | 1,568.3 | 57.1 | 6,486 MiB | default=4096; @`num_ctx 100000` → 100% GPU, 1,432 t/s, ~10.2 GB |
| `qwen3-vl:8b` | — | **4,096** ⚠️ trap | 1,756.1 | 60.8 | 7,172 MiB | default=4096 |
| `gemma4:e4b` | — | **4,096** ⚠️ trap | 2,395.1 | 69.1 | 4,684 MiB | default=4096; fastest |

**Findings:**
- **Context Trap confirmed in practice** (§3/§5): the plain models
  (`qwen3.5:9b`, `qwen3-vl:8b`, `gemma4:e4b`) load at **4,096** — only
  `-32k`/`-highctx-*` Modelfiles set `num_ctx`. Verify every time via `ollama ps`.
- **Base `qwen3.5:9b` @ explicit `num_ctx 100000`** stays 100% GPU, no spill
  (~10.2 GB, 1,432 t/s) — plain 9B does 100K on GPU when told to.
- All 6 gen models run **100% GPU prefill** (1,446–2,395 t/s); none spilled to
  CPU on the 16 GB card.
- Clean unload confirmed each time (back to 26 MiB baseline).
- `nomic-embed-text` / `mxbai-embed-large` are embedding-only (not gen).

### 10.5.3 High-ctx derivatives + VL spill (2026-09-04, adds to §10.5.2)

Fresh `ollama create` high-ctx Modelfiles, verified by `ollama ps`:

| Model | Modelfile num_ctx | ACTUAL ctx | Processor | VRAM | Prefill | Decode | Notes |
|---|---|---|---|---|---|---|---|
| `gemma4:e4b-highctx-131k` | 196608 | **131,072** (clamped) | 100% GPU | 8,624 MiB | 2,766 t/s | 72.1 | gemma **caps 131,072**; 196K silently clamps |
| `qwen3-vl:8b-highctx-100k` | 100000 | **100,000** ✅ | 36%/64% CPU/GPU | ~15,256 MiB | ~19.5 | ~9.9 | **VL spills** — mmproj+KV too big |
| `qwen3-vl:8b-highctx-196k` | 196608 | **196,608** ✅ | 61%/39% CPU/GPU | 37 GB | — | — | **VL spills hard** |

- gemma4:e4b's native cap is 131,072 — a 196K Modelfile is accepted but Ollama
  **clamps to 131,072** (record `ollama ps` truth, don't trust the Modelfile).
  At its max it's the fastest model of the whole bench (2,766 t/s, fits 8.6 GB).
- **VL models spill at high context on 16 GB**: `qwen3-vl:8b` is 8.8B + vision
  projector, so even 100K is 22 GB (36/64) and 196K is 37 GB (61/39). Real
  CPU-spill numbers measured, not assumed. Text-only 9B fits 262K on GPU; the
  VL model does not fit at useful context.
- **Renderer/parser gotcha:** the first VL Modelfiles set `RENDERER qwen3-vl`
  (model id) → `500: unknown renderer "qwen3-vl"`, 0 tokens. **Omit** them and
  inherit from `FROM qwen3-vl:8b`; if you must override, use the `ollama show`
  `architecture` token. After the fix the VL model generates normally.
- All returned to 26 MiB on unload.

### 10.5.4 llama.cpp CUDA — `qwen3.6-35b-a3b` UD-Q2_K_XL @ 80K/130K (2026-09-04)

**First CUDA llama.cpp run on this box** (build `6703d78` — the pending §12.4
source build is now done). Pure GPU, KV q8_0, b4096, temp 0 seed 42, 7,785-token
coding prompt, `llama-server` self-reported timings. Clock-pin skipped (no TTY
for sudo; idle-boost values). Baseline 71 MiB → unloaded clean.

| Context | KV | VRAM | Prefill t/s | Decode t/s | GPU util | Notes |
|---|---|---|---|---|---|---|
| 80,000 | q8_0 | 13,975 MiB | **1,848** | **65.2** | 100% | fits, ~2.4 GB headroom |
| 130,048 | q8_0 | 14,885 MiB | **1,866** | **64.5** | 100% | fits, ~1.5 GB headroom |
| 130,048 | f16 | — | **OOM** | — | — | compute buffer (1.9 GB), not KV |

**Q4_K_S / Q5_K_M MoE-offload runs** (`--n-cpu-moe 999`, KV q8_0, `--reasoning
off`, 2026-09-04):

| Quant | Context | VRAM GPU | RAM RSS | Prefill t/s | Decode t/s | Notes |
|---|---|---|---|---|---|---|
| Q4_K_S (19.5 GB) | 80,000 | 4,751 MiB | ~20.5 GB | 774 | 23.9 | all 256 experts → CPU; attention+KV on GPU |
| Q5_K_M (24.6 GB) | 32,768 | 4,009 MiB | ~24 GB | 654 | 17.5 | slowest of the four |

Offload penalty quantified: **~2.4× decode and ~2.4× prefill slower than the
pure-GPU Q2** (65→24 t/s, 1.85K→0.77K t/s). Q4/Q5 expert-offload buys quality
at ~3× latency — Q2_K_XL pure GPU is the speed pick for 80–130K coding.

### 10.5.5 llama.cpp CUDA — `gemma-4-26b-a4b` UD-Q5_K_XL MoE offload (2026-09-04)

Gemma 4 26B-A4B (bench model D), `gemma-4-26B-A4B-it-UD-Q5_K_XL.gguf` (19.8 GB,
25.23 B params, 30 layers, **128 experts/8 used**, SWA on every 6th layer).
Q5 won't fit 16 GB pure GPU → `--n-cpu-moe 999` (experts on CPU), KV q8_0,
`--reasoning off`, temp 0 seed 42, 9,557-token coding prompt.

| Context | VRAM GPU | RAM RSS | Prefill t/s | Decode t/s | Notes |
|---|---|---|---|---|---|
| 32,768 | 5,312 MiB | ~20.5 GB | 722 | 13.4 | SWA keeps KV small |
| 80,000 | 6,174 MiB | ~20.5 GB | 715 | 11.9 | **80K fits** thanks to SWA |

**Verdict:** decode is slow (11.9–13.4 t/s) — the Q5 experts on CPU + the
SWA-heavy attention make this the slowest model of the bench. Its only edge is
SWA: 80K fits in just 6.2 GB GPU. For coding on this box, the qwen3.6 Q2 pure
GPU (~65 t/s) is ~5× faster; gemma Q5 only if you need its specific quality and
can live with ~12 t/s. Higher-quant gemma (IQ4_XS/IQ3) would need a download
and would still be expert-offloaded on 16 GB.

**Filled matrix row:**

| Model | ctx | quant | engine | gen t/s | prefill t/s | TTFT | VRAM GB | GPU/CPU% | notes |
|---|---|---|---|---|---|---|---|---|---|
| gemma-4-26b-a4b | 80K | Q5_K_XL | llama.cpp CUDA | 11.9 | 715 | ~13.4 s @9.6K prompt | 6.2 + 20.5 RAM | experts CPU | `--n-cpu-moe 999`; SWA; KV q8_0 |

Offload penalty quantified: **~2.4× decode and ~2.4× prefill slower than the
pure-GPU Q2** (65→24 t/s, 1.85K→0.77K t/s). Q4/Q5 expert-offload buys quality
at ~3× latency — Q2_K_XL pure GPU is the speed pick for 80–130K coding.

**Key structural finding:** Qwen3.6-35B-A3B is a **hybrid linear-attention MoE**
(30/40 Gated DeltaNet layers = fixed state), so its KV cache grows only
**~20 KB/token** — ~¼ the rate of a dense transformer. That's why 130K fits
100% GPU on 16 GB. **No `--n-cpu-moe` needed at ≤130K**; the MoE knob is only
for the Q4_K_S (19.5 GB) / Q5_K_M (24.6 GB) quants that don't fit. The f16-KV
OOM is the compute buffer, not KV — shrink `-b` to 2048 or quant KV first.
Recipe + full doc: `llamacpp/qwen36-35b-moe-coding-context.md`.

**Filled matrix rows:**

| Model | ctx | quant | engine | gen t/s | prefill t/s | TTFT | VRAM GB | GPU/CPU% | notes |
|---|---|---|---|---|---|---|---|---|---|
| qwen3.6-35b-a3b | 80K | Q2_K_XL | llama.cpp CUDA | 65.2 | 1,848 | ~4.2 s @7.8K prompt | 14.0 | 100% GPU | hybrid-attn MoE; KV q8_0 |
| qwen3.6-35b-a3b | 130K | Q2_K_XL | llama.cpp CUDA | 64.5 | 1,866 | ~4.2 s @7.8K prompt | 14.9 | 100% GPU | fits; KV q8_0 |
| qwen3.6-35b-a3b | 80K | Q4_K_S | llama.cpp CUDA | 23.9 | 774 | ~10.1 s @7.8K prompt | 4.8 + 20.5 RAM | experts CPU | `--n-cpu-moe 999`; KV q8_0 |
| qwen3.6-35b-a3b | 32K | Q5_K_M | llama.cpp CUDA | 17.5 | 654 | ~11.9 s @7.8K prompt | 4.0 + 24 RAM | experts CPU | `--n-cpu-moe 999`; slowest |

Target quants are low enough to fit 16 GB VRAM and hold 80-100K context on GPU
(dense) or via MoE expert spill.

```bash
# 1. qwen3.5-9b (dense, fits GPU)
ollama pull qwen3.5:9b

# 2. qwen3.6-35b-a3b (MoE — the 100K-fast best bet; ~147 t/s @100K on 16 GB)
ollama pull qwen3.6:35b-a3b-iq3_s

# 3. qwen3.8-27b (hybrid linear/full attention, fits GPU)
ollama pull qwen3.8:27b

# 4. gemma-4-26b-a4b (MoE) — low quant to fit 16 GB
ollama pull gemma-4:26b-a4b-iq4_xs
```

> **Ollama default context is 4096** — the §3/§5 trap. Every run MUST pass
> explicit `num_ctx` and be verified:
>
> ```bash
> ollama run <model> --verbose        # /set parameter num_ctx 81920  (80K)
> # or via API, then confirm it actually loaded at that context:
> curl http://localhost:11434/api/chat -d '{
>   "model": "<model>",
>   "options": {"num_ctx": 81920, "temperature": 0},
>   "messages": [{"role":"user","content":"hi"}]}'
> ollama ps    # CONTEXT column must show 81920, not 4096
> ```
>
> If `ollama pull` says **"file does not exist"**, the exact tag differs — list
> real tags first:
> `curl -s https://ollama.com/library/qwen3.6/tags | grep -o '"name":"[^"]*"' | head -40`
> (pull done by the user, not the agent).

### 10.5.6 zerwiz-1 (Windows mirror) — llama.cpp router, **CPU-only** (2026-09-09)

**Machine:** ASUS ROG Flow X13, RTX 3080 Laptop **16 GB** (driver 595.79 / CUDA
13.2; `nvidia-smi` works **without** admin — earlier "8 GB"/"needs admin" notes
were wrong). llama.cpp **b10868** `cuda-12.4-x64` at `C:\Users\josef\llama.cpp`,
`llama-server` router via `scripts/llama-router-win.sh`, models INI from
`scripts/llama-models.win.yaml` (selected by `LLAMA_MODELS_YAML` env).
Endpoint: Win `http://0.0.0.0:8080/v1`; from WSL use `172.17.16.1:8080`
(WSL localhost forward does not reach the Windows side).

**CRITICAL — these numbers are NOT "the Windows numbers".** The CUDA backend
enumerates **0 devices** (`--list-devices` → `(none)`; log has no
`ggml_cuda_init`/`load_backend`; buffers are all Host/CPU_REPACK). Root cause:
the release split the CUDA runtime into a **companion zip**
(`cudart-llama-bin-win-cuda-12.4-x64.zip` — cudart64_12/cublas64_12/cudnn*),
which was **not** unpacked next to `llama-server.exe`, so `ggml-cuda.dll`
fails to load and llama.cpp silently runs on CPU. **Repeat this bench after the
fix** — expect ~10–60× faster prefill/decode on the 16 GB GPU.

Method: cold (cache_prompt=false, warmup "hi" first), 266–1443-token code
prompt, max_tokens 96, temp 0, KV default f16, `--threads 8`. VRAM not
measured (no GPU). qwen35-4b / qwen35-4b-64k FAIL to load (GGUF
`rope.dimension_sections` array-length 3 vs 4 — quantizer/build mismatch).

| model | prompt_tok | cache | wall_s | prefill t/s | decode t/s | TTFT ms | status |
|---|---|---|---|---|---|---|---|
| qwen35-4b | — | — | — | — | — | — | FAIL-WARM (GGUF metadata) |
| qwen35-4b-64k | — | — | — | — | — | — | FAIL-WARM (same) |
| qwen3-4b (Q4_K_M) | 266 | 0 | 10.5 | 59.2 | 10.6 | 4,493 | ok — CPU-only |
| gpt-oss-20b (MXFP4) | 315 | 0 | 14.4 | 36.6 | 10.9 | 8,598 | ok — MoE, CPU-only |
| gemma-3-12b (Q8_0) | 265 | 0 | 48.1 | 12.3 | 2.4 | 21,492 | ok — cold load slow |
| devstral-14b (Q4_K_M, ngl 32) | 1,443 | 0 | 179.0 | 9.8 | 2.0 | 147,254 | ok — huge prefill |

**Filled matrix rows (flagged CPU-only):**

| Model | ctx | quant | engine | gen t/s | prefill t/s | TTFT | VRAM GB | GPU/CPU% | notes |
|---|---|---|---|---|---|---|---|---|---|
| qwen3-4b | 266 | Q4_K_M | llama.cpp (CPU!) | 10.6 | 59.2 | 4.5 s | n/a | 0% GPU | **CUDA DLLs missing**, silent CPU fallback |
| gpt-oss-20b | 315 | MXFP4 | llama.cpp (CPU!) | 10.9 | 36.6 | 8.6 s | n/a | 0% GPU | MoE; experts on CPU anyway |
| gemma-3-12b | 265 | Q8_0 | llama.cpp (CPU!) | 2.4 | 12.3 | 21.5 s | n/a | 0% GPU | dense 12B on 8 CPU threads |
| devstral-14b | 1,443 | Q4_K_M | llama.cpp (CPU!) | 2.0 | 9.8 | 147 s | n/a | 0% GPU | ngl 32 ignored (no GPU) |

**Bottom line:** until the cudart companion zip is installed, the Windows
llama.cpp router is CPU-bound and useless for coding (2 t/s is the best decode).
Fix + re-bench, then compare against the A5000 reference numbers in §10.5.4/§10.5.5.

### 10.5.7 zerwiz-1 FINAL — GPU fixed, full offload (2026-09-09)

Root cause was identified and FIXED same day: the CUDA runtime (cudart/cublas)
ships in a **separate companion zip** (`cudart-llama-bin-win-cuda-12.4-x64.zip`),
which was installed into `C:\Users\josef\llama.cpp\` → `--list-devices` now shows
`CUDA0` (16 GB) and buffers are CUDA0. Registry `scripts/llama-models.win.yaml`
retuned from the old "8 GB" assumptions:
gptoss `cpu_moe` removed (full GPU), gemma-r ngl 26→999, devstral ngl 32→36
(40 OOMs — needs ~1.1 GB compute headroom). KV q8_0, ctx 32K, server-reported
timings, cold cache (cache_prompt=false after "hi" warmup).

| model | ngl | prompt_tok | cache | wall_s | prefill t/s | decode t/s | TTFT ms | status |
|---|---|---|---|---|---|---|---|---|
| qwen35-4b | — | — | — | — | — | — | — | FAIL (GGUF `rope.dimension_sections`, not GPU) |
| qwen35-4b-64k | — | — | — | — | — | — | — | FAIL (same) |
| qwen3-4b (Q4_K_M) | 999 | 266 | 0 | 0.7 | 3,810 | **105.7** | 70 | ok |
| gpt-oss-20b (MXFP4, MoE) | 999 | 315 | 0 | 0.8 | 1,510 | **109.6** | 209 | ok |
| gemma-3-12b (Q8_0) | 999 | 265 | 0 | 2.4 | 968 | **29.4** | 274 | ok |
| devstral-14b (Q4_K_M) | 36 | 1,443 | 0 | 7.9 | 729 | **10.6** | 1,980 | ok (ngl 40 OOM) |

**Improvement vs CPU-only (§10.5.6):** qwen3-4b 10× decode (10.6→106), gptoss
10× (10.9→110), gemma-r 12× (2.4→29), devstral 5.3× (2.0→10.6). Prefill gains
are even bigger (2–64×). zerwiz-1's RTX 3080 Laptop 16 GB = ~60% of the A5000's
speed (A5000 100K gpt-oss 28 t/s; zerwiz-1 32K 110 t/s on the smaller MXFP4).

**Fresh filled matrix rows:**

| Model | ctx | quant | engine | gen t/s | prefill t/s | TTFT | VRAM GB | GPU/CPU% | notes |
|---|---|---|---|---|---|---|---|---|---|
| qwen3-4b | 32K | Q4_K_M | llama.cpp CUDA (zerwiz-1) | 105.7 | 3,810 | 0.07 s | ~4 | 100% GPU | ngl 999; KV q8_0 |
| gpt-oss-20b | 32K | MXFP4 | llama.cpp CUDA (zerwiz-1) | 109.6 | 1,510 | 0.21 s | ~12 | 100% GPU | ngl 999; MoE, no cpu_moe |
| gemma-3-12b | 32K | Q8_0 | llama.cpp CUDA (zerwiz-1) | 29.4 | 968 | 0.27 s | ~13 | 100% GPU | ngl 999 |
| devstral-14b | 32K | Q4_K_M | llama.cpp CUDA (zerwiz-1) | 10.6 | 729 | 1.98 s | ~15 | ~90% GPU | ngl 36 (40 OOM); KV q8_0 |

**Bottom line:** zerwiz-1 is now a usable coding box via the router
(`http://172.17.16.1:8080/v1`). qwen3-4b/gptoss are the fast picks (~106–110
t/s); devstral is the heavy dense option. Re-bench in a session and lock in the
yaml values before further ngl tuning.

### 10.5.8 zerwiz-1 HIGH-CONTEXT — 100K achieved, devstral capped at 70K (2026-09-09)

Ctx raised for the coding target (user asked "80–100 000"). KV switched to
**q4_0** on the big models (halves KV VRAM). Bench is cold short-prompt; the
load itself (KV buffers allocated for full ctx) is the OOM gate — prompt_tok is
just the warmup prompt length, prefill/decode unchanged from §10.5.7 (short
prompts). Measured max ctx per model on the 16 GB card, found by bisecting
one-shot `llama-server` loads:

| model | target ctx | kv | ngl | result | notes |
|---|---|---|---|---|---|
| qwen3-4b (Q4_K_M) | 100K | q8_0→q4_0 | 999 | ✅ 100K | full GPU, no pressure |
| gpt-oss-20b (MXFP4) | 100K | q4_0 | 999 | ✅ 100K | full GPU |
| gemma-3-12b (Q8_0) | 100K | q4_0 | 999 | ✅ 100K | full GPU |
| devstral-14b (Q4_K_M) | 100K | q4_0 | 36 | ❌ OOM | `failed to allocate CUDA0 buffer of size 1459921408` |
| devstral | 80K | q4_0 | 36 | ❌ OOM | CUDA_Host pp-buffer 412 MB also failed |
| devstral | 64K | q4_0 | 34 | ❌ OOM | — |
| devstral | 64K | q4_0 | 32 | ✅ | max tested 73728 |

devstral ceiling tipped over between 73728 and 77824 at ngl 32 (q4_0 KV); set
**ctx 70000 / ngl 32** for reliability.

First-run full config in `scripts/llama-models.win.yaml`:
`qwen35-4b(-64k)` keep (still broken GGUF), `qwen3-4b/gptoss/gemma-r`
ctx 100000, `devstral` ctx 70000. Cold bench across the router:

| model | state | prefill t/s | decode t/s | TTFT ms | ctx |
|---|---|---|---|---|---|
| qwen3-4b | ok | 3,880 | **106.3** | 69 | 100K |
| gpt-oss-20b | ok | 1,540 | **109.7** | 205 | 100K |
| gemma-3-12b | ok | 1,010 | **29.2** | 262 | 100K |
| devstral-14b | ok | 603 | 6.8 | 2,393 | 70K |

devstral decode dropped 10.6→6.8 t/s because ngl 36→32 (4 layers now on CPU) +
bigger ctx; that's the 16 GB tax on a 14 GB dense model. If devstral speed
matters more than ctx, trade back to ngl 36 at 32K.

**Filled matrix rows (final, high-ctx):**

| Model | ctx | quant | engine | gen t/s | prefill t/s | TTFT | VRAM GB | GPU/CPU% | notes |
|---|---|---|---|---|---|---|---|---|---|
| qwen3-4b | 100K | Q4_K_M | llama.cpp CUDA (zerwiz-1) | 106.3 | 3,880 | 0.07 s | ~4 | 100% GPU | ngl 999; KV q4_0 |
| gpt-oss-20b | 100K | MXFP4 | llama.cpp CUDA (zerwiz-1) | 109.7 | 1,540 | 0.21 s | ~12 | 100% GPU | ngl 999; MoE |
| gemma-3-12b | 100K | Q8_0 | llama.cpp CUDA (zerwiz-1) | 29.2 | 1,010 | 0.26 s | ~13 | 100% GPU | ngl 999; KV q4_0 |
| devstral-14b | 70K | Q4_K_M | llama.cpp CUDA (zerwiz-1) | 6.8 | 603 | 2.39 s | ~15 | ~80% GPU | ngl 32; 100K OOMs |

`~/.pi/agent/models.json` `llamacpp` provider now advertises these exact
context windows (100K/100K/100K/70K) so Pi agents pick realistic ctx.

---

### 10.5.9 Linux/Omarchy host — 27B dense + 30B MoE at 80K, both pure GPU (2026-09-12)

**New host.** This box reports **NVIDIA GeForce RTX 3080 Laptop GPU, 16384 MiB,
driver 610.57.04** (max SM 2100 MHz). It is *not* the A5000 the §10.5 baseline
above was written on — do not compare the two sets directly.

**The CUDA trap on this host (fixed).** The distro's `/usr/bin/llama-server` is a
CPU-only build — `--list-devices` prints `Available devices: (none)` and a model
"loads" pure-CPU. LM Studio ships *both* a CUDA12 llama.cpp build and the
matching CUDA12 runtime (`libcudart.so.12`, `libcublas.so.12`) in separate
extension packs; the binary needs `LD_LIBRARY_PATH` at both. Shim:
`~/.local/share/llama-router/scripts/llama-server-cuda` (machine property,
outside every repo). Verified: `--list-devices` →
`CUDA0: NVIDIA GeForce RTX 3080 Laptop GPU (15981 MiB, 15812 MiB free)`.

**Models.** Both GGUFs are LM Studio downloads (`~/.lmstudio/models`;
`settings.json` → `downloadsFolder`) and the registry's `models_dir` now points
there. Registry ids `27b` / `27b-swap` / `27b-cpu` / `27b-cpu-swap` and
`30b-coder` / `30b-coder-swap`. Both at **81,920 ctx**, KV **iq4_nl**, pure GPU
(`ngl 999`), `-np 1`, temp 0 seed 42.

| Model | quant | ctx | KV | VRAM | Load | prefill t/s | decode t/s | GPU util | verdict |
|---|---|---|---|---|---|---|---|---|---|
| Qwen3.8-27B (dense) | IQ3_XXS (10.2 GB) | 81,920 | iq4_nl | **13,602 MiB** | 12 s | see note | **21.1** | 92-95% @114 W | ✅ 80K fits, ~2.2 GB headroom |
| Qwen3-Coder-30B-A3B (MoE) | IQ2_M (10.1 GB) | 81,920 | iq4_nl | **13,140 MiB** | 12 s | n/m | **46.6** | 92-95% | ✅ 80K, via the router |

`n_ctx` was read back from the server via `/props` (both 81,920) — verified, not
asserted.

**Prefill note (observed, not trusted).** The 27B's first cold-clock run reported
prefill 28.2 t/s / decode 8.2 t/s on a 3,805-token prompt, with `nvidia-smi`
sampling **0 % util** — while a second, warmed run of the same model held
**92-95 % util, 114 W, 1755 MHz** and gave decode **21.1 t/s**. Cause: this GPU
sits at **210 MHz idle** and boosts lazily; a timed request fired straight after
a model restart measures the ramp, not the model. **Warm the GPU with a throwaway
request before any timed run.** Prefill t/s from a tiny prompt (~30 tok) is also
meaningless — it measures fixed overhead, not throughput.

**Router autoload verified (2026-09-12).** A pi-shaped `POST /v1/chat/completions` naming
`qwen3-coder-30b-a3b@iq2_m` loaded the model and answered in **5 s wall**, decode
**46.6 t/s** — the router swaps on the `model` field with no client-side launch step.

**Context length dominates decode speed here — this is measured, not theory.**
Same resident model (`qwen3.8-27b@iq3_xxs`), same server, same power state
(AC online, 115 W limit), only the prompt length changed:

| Run | prompt_tok | prefill t/s | decode t/s | peak util | peak W |
|---|---|---|---|---|---|
| short context | 19 | 64.7 | **21.2** | 9% | 53.4 |
| long context | 7,940 | 14.5 | **4.6** | 100% | 112.7 |

Decode falls **4.6x** and prefill **4.5x** between a cold context and ~8K. The
slow run drew **more** power (112.7 W vs 53.4 W), so this is not a power,
thermal, or battery cap — it is KV-cache traffic. **Every "decode t/s" figure in
this section was taken at near-empty context and is therefore an upper bound.**
Quote it as such, or re-measure at the context you actually care about.

**Correction, same day (2026-09-12).** An earlier revision of this section blamed
a 6.2 t/s reading on the laptop being on battery. That was wrong — it was a
~3.7K context, and the run drew *more* power than the fast one. The battery
explanation was inferred from a single `/sys/class/power_supply` status string
without testing the alternative — precisely the "asserted > observed"
anti-pattern this skill exists to catch.

**Method fix for `scripts/bench-one.sh`:** its step [6/7] *restarts* the model to
clear the cache, which also discards the GPU's boosted clock state and produces
exactly the misleading 0 %-util sample above. Either warm after the restart, or
clear the prefix cache without reloading.

**Filled matrix rows:**

| Model | ctx | quant | engine | gen t/s | prefill t/s | TTFT | VRAM GB | GPU/CPU% | notes |
|---|---|---|---|---|---|---|---|---|---|
| qwen3.8-27b | 80K | IQ3_XXS | llama.cpp CUDA (this host) | 21.1 | n/m | n/m | 13.6 | ~94% GPU | `ngl 999`; KV iq4_nl; dense |
| qwen3-coder-30b-a3b | 80K | IQ2_M | llama.cpp CUDA (this host) | 46.6 | n/m | n/m | 13.1 | ~94% GPU | MoE 30B/3B; `ngl 999`; KV iq4_nl |

`n/m` = not measured (run aborted on request). Both need one clean re-run with a
warmed GPU to fill prefill/TTFT.

---

The Unsloth GGUF files themselves are **standard llama.cpp / GGUF** — nothing
inherently slow about the format. The slowness in LM Studio comes from the
engine + config, not the files. Findings:

### 11.1 LM Studio bundles an older llama.cpp (30-52% slower than source)
LM Studio ships a specific llama.cpp build baked in; it lags llama.cpp HEAD by
days-to-weeks, and llama.cpp gets performance commits (flash-attn, KV-cache
rework, architecture-specific fixes) weekly. Community benchmarks on the same
GGUF:

| Hardware | Model | LM Studio | llama.cpp (source) | Gap |
|---|---|---|---|---|
| RTX Pro 6000 | GPT-OSS 120B Q4 | ~86 tok/s | ~180 tok/s | 52% |
| RTX 3090 | Qwen 3.5 35B-A3B Q4 | ~60 | ~111 | 46% |
| M3 Ultra | Gemma 3 27B | ~22 | ~33 | 33% |
| RTX 4070 Ti | Qwen 2.5 7B Q4 | ~45 | ~65 | 31% |

Bigger gap on high-end GPUs (overhead is a larger fraction); smaller on budget
GPUs where the model itself is the bottleneck.

### 11.2 Qwen3.5 architecture quirks hit worst in LM Studio/Ollama
Qwen3.5 / Qwen3.6 (the `qwen3.6-35b-a3b` and `qwen3.8-27b` here) have
documented compatibility issues in LM Studio + Ollama: chain-of-thought loops,
garbage output, and the MoE-routing issues that early llama.cpp builds had
(fixed in later commits). The bundled-version lag therefore hits these exact
models harder than older/denser ones.

### 11.3 Conservative LM Studio defaults push toward CPU spill
- Context length default 4096-8192 allocates more KV cache than a tight 2048.
- Batch size "auto" is conservative (needs `-b 4096 -ub 4096` for fast CPU+GPU MoE).
- Flash Attention sometimes ships **off** for compatibility.
- Auto GPU-layer detection occasionally leaves layers on CPU, which bottlenecks
  the whole pipeline — force all layers to GPU if VRAM allows.
- On this box the earlier LM Studio `qwen3.5-9b` load ran at **0% GPU util**
  during prefill with ~8.7 GB VRAM used — i.e. the compute was effectively not
  offloaded / clock-limited, while 139K context bloated the KV cache.

### 11.4 MoE offload regex (`-ot`) — partial expert offload is SLOW
For MoE GGUFs, offloading **only some** expert layers to CPU (leaving others on
GPU) can cut gen rate in half — some backend op the model needs can't run on
CUDA, kicking GPU experts to CPU dynamically every token. If you must CPU-offload
experts, offload **all** of them (e.g. `--n-cpu-moe 999` or
`-ot "exps=CPU -ngl 99"`), and keep attention + KV on GPU. ~20 t/s gen at 256K on
a 9900K + 4070 12GB with all experts on CPU.

### 11.5 Bottom line / what to do
1. **Don't blame the GGUF** — re-test the same file in a **source-built CUDA
   llama.cpp** (`--n-cpu-moe` for MoE, `--flash-attn on`, `--cache-type-k/v q4_0`
   to reclaim VRAM, explicit `num_ctx`) — §9/§10 command shapes.
2. Push LM Studio settings: **GPU offload all layers, Flash Attention on, KV
   quant on, batch 4096**, keep context to what you need (don't let it auto-inflate
   to 139K).
3. If raw token speed is the goal for these 4 models, drive the bench with
   llama.cpp/llama-server, not the LM Studio GUI.

---

## 12. Hosted model access — always-available coding tools (aizerwiz)

Goal: **always have access to the coding models from anywhere** (even away from
home) via one network service that pi and other programs use. Models **load and
unload on demand** — they are NOT all resident at once. This is what the bench
(§10) feeds into. **No backend is assumed yet — pick the one that actually does
on-demand model switching AND hits the speed targets.**

### 12.1 Which backends can do on-demand model switching (verified 2026-09-04)

| Backend | On-demand load/unload | Multi-model | Status on this box |
|---|---|---|---|
| **LM Studio** (`lms load/unload/ps`) | ✅ yes | loads one at a time, swaps on demand | Server **running** `:1234`; **all 4 targets available** (`qwen3.6-35b-a3b@q2_k_xl/q4_k_s/q5_k_m/iq3_s`, `qwen3.8-27b`, `gemma-4-26b-a4b-it`, `qwen3.5-9b`, …). `lms ps` = nothing loaded now. Bundled llama.cpp **slow** (§11.1). |
| **Ollama** (`run`/`stop`/`ps`) | ✅ yes | keeps running models resident, swaps | Installed; Modelfiles built (`qwen3.5:9b-highctx-262k/196k`). Hides `--n-cpu-moe`/`-ot`. |
| **llama-server** (CUDA, source build) | ⚠️ one model **per process** | needs a supervisor to start/stop per model | Cloned `/home/zerwiz/llama.cpp`, **NOT built yet**; only CPU-only binary exists. **Fastest** when built. |

**Decision (user):** endorse the backend **only after the bench proves it** — the
bench decides whether LM Studio can hit the fast builds; Ollama is a parallel
candidate; source-built llama-server is the fallback for raw speed.

### 12.2 Three builds per model (CPU-big / mid / fast)
For each model, define **3 configs of the same GGUF** (same weights, different
engine settings) exposed as separate model ids behind the chosen backend:

| Config | Purpose | Context | Placement | Speed expectation |
|---|---|---|---|---|
| **slow-but-big (CPU)** | long coding sessions, big ctx | 196K-262K | CPU (or MoE experts→CPU), 122 GB RAM, 8 cores | slow but big |
| **mid** | balanced default | ~100K | GPU where it fits, else hybrid | medium |
| **fast** | max token speed | ~32K | GPU, all layers, flash-attn on, KV quant | fastest |

For MoE this maps to the §9 rules: keep attention + KV on GPU, spill routed
experts to CPU only on the "big" config (`--n-cpu-moe` / `-ot exps=CPU`).

### 12.3 What the bench must answer (feeds this plan)
1. **Which backend** actually does acceptable on-demand load/unload over the
   gateway for pi + other programs (test `lms load/unload`, `ollama run/stop`,
   and llama-server+supervisor)?
2. For each model, which of the 3 configs are **usable** on that backend (i.e.
   does LM Studio's bundled engine run the fast builds fast enough — its ~30-50%
   penalty §11.1 — or must we fall back to source llama-server)?
3. What are the real 80K/100K/196K/262K numbers (fill §10.5) for each config?
4. Confirm remote access works from outside the home network (Tailscale / port)
   through aizerwiz with a bearer token.

### 12.4 Files / state
- aizerwiz: `~/CodeP/aizerwiz` (gateway, `.env` → `WOT_AI_UPSTREAM_URL`,
  default `http://127.0.0.1:1234/v1` = LM Studio).
- LM Studio server currently running `:1234`, models available (see 12.1).
- The **build is in progress**: a fresh CUDA llama.cpp cloned to
  `/home/zerwiz/llama.cpp` (HEAD `6703d78`, source build not yet configured).
  This is the fast fallback engine — build with:
  `cmake -B build -DGGML_CUDA=ON -DGGML_CUDA_F16=ON -DGGML_CUDA_FA_ALL_QUANTS=ON -DGGML_CUDA_MMQ=ON -DGGML_NATIVE=ON` + build `llama-server llama-cli`.
- Local CUDA **toolkit is 12.4** (`nvcc` 12.4, /usr/bin/nvcc) — driver is newer
  (580.x) but the compiler is 12.4; fine for llama.cpp CUDA builds.

### 12.5 Model-switching services — researched online (2026-09-04)

`llama.cpp` now has **native router mode** — the big one: dynamic on-demand
load/unload/swap **without restarts**, like LM Studio/Ollama but with full speed
and `--n-cpu-moe` control. Verified present in our clone
(`tools/server/server-models.cpp`, `tools/server/README.md` §1653+).

| Option | On-demand swap | Multi-model residency | In-memory eviction | Notes |
|---|---|---|---|---|
| **llama.cpp router mode** (native) | ✅ per-request | multiple defined, **one resident per worker** | per-model unload, `--models-max` | Start with **no `--model`**: `llama-server --models-preset models.ini` (also `--models-dir`, `--models-max N`, `--models-autoload`). Each instance = a model alias + per-instance args (so each of the 3 builds-per-model can be an alias in one ini). Router forwards on the `"model"` JSON field / `?model=` query. Reload latency 3-10 s on swap. Config still experimental — flags shift across versions. |
| **llama-swap** (external orchestrator, Go) | ✅ per-request | spawns a `llama-server` **per** model | idle unload after timeout | Sits in front of llama-server/vLLM/etc. Watches `model` field, starts the right backend process, routes, unloads when idle. Best when per-model isolation is wanted. Extra moving part vs native router. |
| **Ollama** | ✅ per-request | keeps running models resident; `OLLAMA_MAX_LOADED_MODELS`≥2 for parallel | TTL/aggressive eviction | Your Modelfiles (`.5:9b-highctx-262k/196k`) already work. Hides `--n-cpu-moe`/`-ot`; auto-unloads fast. ~15-20% slower than localAI pure inference in some tests. |
| **LM Studio** (`lms load/unload`, `lms ps`) | ✅ per-request **JIT** (0.4.x auto-loads on first call) | keeps loaded until manual unload/quit or TTL | **JIT + Auto-Evict**: idle TTL unload / `lms ps`; native v1 REST `/api/v1/models/load` & `/unload` allow self-eviction | All 4 targets available now (`:1234`). 0.4.x **JIT** auto-loads an unloaded model when a `/v1/chat/completions` arrives (~15 s first load), and **Auto-Evict** frees one when another must load — true on-demand swap, not just manual. Native v1 REST lets a wrapper set `context_length`, `offload_kv_cache_to_gpu`, `num_experts`, `flash_attention`, and a per-model idle **TTL** (auto-unload). Caveats: still llama.cpp-**based** (§11.1 slow), and some clients (Qwen Code pre-flight) wrongly reject an unloaded model instead of letting JIT load it. |

**Key finding for the plan:** the freshly-built CUDA `llama.cpp` (clone exists,
not built) is the strongest single service for "always available, on-demand
load/unload, serves pi + programs over aizerwiz":
- one server, one INI → all 3 builds-per-model as aliases,
- per-instance `--n-gpu-layers` / `--n-cpu-moe` / `--ctx-size` → CPU-big/mid/fast
  from the **same GGUF file**, no duplicates,
- full speed (not LM Studio's bundled lag),
- sleeps/evicts unneeded models → frees VRAM for the bench and other apps.
- Caveats: one resident per worker at a time, swap = unload+reload (3-10 s),
  timed eviction `--stop-timeout` (default 10 s), config still stabilizing.

So the backend ranking to validate in the bench: **(1) native llama.cpp router
mode** → (2) LM Studio (JIT + Auto-Evict improves it — but still llama.cpp-based
slowness, §12.5.1) → (3) Ollama → (4) llama-swap for per-model isolation. The
bench (§10) fills the real numbers that decide.

### 12.5.1 More model-switching services — researched online (2026-09-04)

Expanding the table above with services found in the web research, in rough
order of fit for this plan (small single-user box, GGUF MoE, on-demand
load/unload, serves pi + scripts via one OpenAI endpoint):

| Service | Engine / quant | On-demand swap | Concurrency | Notes / fit for our plan |
|---|---|---|---|---|
| **vLLM** | fp8/bf16, HF checkpoints (not GGUF) | `/v1/chat/completions` per model; **instant load/unload during serving**; `--cpu-offload-gb` adds CPU as swap | PagedAttention + continuous batching, 100s of concurrent | **Production/multi-user tier**, not this box: FP16 weights + big VRAM (70B ≈ 140 GB FP16). `--cpu-offload-gb` pretends more VRAM by offloading to CPU — but that's a different mechanism from our fully-unsilced CPU mode. Long model load times (weights are large). Right tool when hundreds share one endpoint on a big GPU box — not the aizerwiz/pi single-user case. |
| **TabbyAPI** (theroyallab) | **ExLlamaV2/V3**; **EXL2/EXL3 only, no GGUF** | `POST /v1/model/load` and `/unload` (admin key); switch by setting `model` on any completions call | asyncio, paged attention, tensor parallel | **Very fast** on consumer GPUs (EXL2/3 beats llama.cpp 30-60% same quant size on RTX 4090-class). Admin/API key split. **Blocked for us because our 4 targets are GGUFs** — ExLlama can't read them. Same team's **YALS** is the GGUF twin (same API surface on llama.cpp) — a real candidate if TTL/idle-unload scripting beats llama.cpp router mode. |
| **SGLang** | fp8/bf16 HF | multi-model concurrent on one server; RadixAttention KV caching | high-throughput, TP multi-GPU | Another production serving framework; great when serving many models/prefix-heavy workloads. Same GGUF/footprint mismatch as vLLM for this single-user 16 GB box. |
| **Prism / kvcached** (research) | any (shim layer) | GPU-memory **ballooning** — reclaim VRAM from idle models to swap in new ones, shrink KV-cache of cold models | time- + space-sharing unified | Academic (MIT/ovg-project) but the exact idea behind "load/unload on demand to fit 16 GB". Emerging; not a drop-in today — noted as the conceptual anchor, not a candidate. |

**Summary of the wider field:** every serious option for "serve many models on
one GPU, load/unload on demand" falls on two axes —
(1) **weight swap** (evict + reload; llama.cpp router / LM Studio JIT / Ollama /
llama-swap / TabbyAPI) vs **co-resident** (vLLM / SGLang space-share what fits
in VRAM), and
(2) **GGUF** (llama.cpp, Ollama, LM Studio, YALS) vs **EXL2/3** (TabbyAPI) vs
**FP16/fp8 HF** (vLLM, SGLang).
For our case (MoE GGUFs, 16 GB VRAM, single user behind aizerwiz), the **GGUF +
weight-swap** corner is the right lane — which is exactly the llama.cpp router
mode / LM Studio JIT / Ollama / llama-swap set already ranked above. The
non-GGUF engines (vLLM/SGLang/TabbyAPI) are real but only matter if we abandon
GGUF — a decision the bench's speed results would have to force.

### 12.6 Colibri — disk-streamed MoE (different mechanism, worth knowing)

Distinct from the model-switching services above: those swap **which model is
resident**; **Colibri** (`JustVugg/colibri`, ~26.8k★, Apache-2.0) instead
**streams MoE experts from disk on demand** so a model that *couldn't* fit in
fast memory still runs — VRAM/RAM/NVMe treated as one placement hierarchy
("one hierarchy, not a memory requirement"). Pure-C engine, zero runtime deps
(build needs only `gcc`/`clang` + OpenMP), no GPU required.

- **Idea:** a 744B MoE only activates ~40B params/token (~11 GB of routed
  experts change per token). The dense part stays resident in RAM (int4, ~9.9
  GB for GLM-5.2); the ~19k routed experts live on disk and are streamed in
  with a per-layer LRU + learned pinned hot-store + one-layer-ahead
  prefetch (`PILOT`). **Placement decides speed, never semantics.**
- **Speed reality:** decode is *disk/bandwidth-bound*, not VRAM-bound — a few
  tok/s on a fast NVMe warm, fraction of a tok/s cold. e.g. 6×5090 full-resident
  5.8-6.8 tok/s; 128 GB CPU-only ~1.8 tok/s; 25 GB dev box 0.05-0.1 tok/s cold.
  Dual-SSD mirror (`COLI_MODEL_MIRROR`) sums read bandwidth, often the biggest
  single win on a real box.
- **Relevant to our roster — Qwen3.6-35B-A3B** (one of our 4 targets):
  - family supported as its own engine (`make -C c qwen36`, `CUDA=1` for the
    VRAM expert tier);
  - needs ~20 GB int4-gs64 container, **24 GB full RAM residency** (not a
    disk-streamed "fit on small box" case — qwen36 needs full residency);
  - optional CUDA VRAM expert tier measured **1.44 → 10.05 tok/s (7.0×)** on
    two 8 GB cards, **output bit-identical** to the CPU path.
  - Docker / Ollama containers aside, this is the one of our four families with
    a dedicated Colibri engine — a potential CPU-big / long-context alternative
    that sidesteps the "fits in 16 GB VRAM?" question entirely (streaming + CPU
    instead of cramming into VRAM).
- **Also runs:** GLM-5.2 (744B), GLM-5.3-Flash (321B, vision), Inkling (975B),
  Kimi K3 (2.8T), DeepSeek V4 Flash (284B), Qwen3.8-Flash-Next (125B+51B),
  OLMoE (7B). `coli chat` / `coli serve` / `coli web` (OpenAI-compatible HTTP
  gateway + dashboard) — so it can also sit behind aizerwiz like LM Studio /
  llama-server.
- **Caveats / cost:** converts to its own int4 container (one-time, Python
  converter); correctness/quality are hard-guaranteed (token-exact vs a
  transformers oracle) but speed has **no SLA** and is entirely hardware-bound.
  A GPU only makes it faster; it never changes output.

**Where this fits the plan:** not a competitor to llama.cpp router mode for the
*fast/mid* builds (it's a throughput trade-off, not a speed play on this box) —
but it is a genuine **CPU-big alternative** for the MoE families that fit (esp.
Qwen3.6-35B-A3B), turning the "does 16 GB VRAM hold it?" question into a disk
bandwidth question. Lower priority than building/benching the CUDA llama.cpp
router mode, but worth a slot in §10 if a very long-context CPU-resident mode
wins out. First sharp edit: none — verified directly from the repo README
(2026-09-04).

---

## Related

- [`../pi/pi-models-registry.md` §10](../pi/pi-models-registry.md) — LM-Studio-vs-Ollama GPU-offload summary
- [`../LLAMA_CPP_SERVER.md`](../LLAMA_CPP_SERVER.md) — llama.cpp server notes
- MoE references: [DocShotgun llama.cpp MoE offload guide](https://huggingface.co/blog/Doctor-Shotgun/llamacpp-moe-offload-guide), [llama.cpp MoE VRAM benchmarks (esonhjz)](https://github.com/esonhjz/llama-cpp-moe-vram-benchmarks), [16 GB VRAM llama.cpp benchmarks (Glukhov)](https://www.glukhov.org/llm-performance/benchmarks/best-llm-on-16gb-vram-gpu), [llama.cpp VRAM tuning for MoE (Big Iron)](https://www.bigiron.cc/guides/llama-cpp-vram-tuning-for-moe-models-on-gpu)


---

### 10.5.10 ROOT CAUSE of the "extremely slow" runs — IQ4_NL KV silently ran attention on the CPU (2026-09-12)

Symptoms measured on this host:

- `27b` (Qwen3.8-27B IQ3_XXS, 80K ctx): **prefill 14.5 t/s** on a 7,940-token
  prompt; decode **21.2 t/s** at a 19-token context but **4.6 t/s** at ~8K.
- Prefill was CPU-class, while this same GPU class is recorded elsewhere in this
  file at 729-3,810 t/s.

**Root cause — llama.cpp issue #27109**, "CUDA: 4-bit KV cache (q4_1/q4_0)
collapses prefill to ~34 t/s on qwen35 hybrid" (OPEN, filed 2026-08-15):

> "when the CUDA flash-attention kernel cannot handle the requested KV types, the
> scheduler places the whole `FLASH_ATTN_EXT` op on the CPU backend. Prefill then
> runs on CPU at ~34 t/s."

From `ggml/src/ggml-cuda/fattn.cu`, a **default** build accepts KV types
`F32, F16, Q4_0, Q8_0, BF16` — `Q4_1/Q5_0/Q5_1` need
`-DGGML_CUDA_FA_ALL_QUANTS=ON` — and additionally:

```c
if (K->type != V->type) { return BEST_FATTN_KERNEL_NONE; }   // default builds
```

**IQ4_NL is not in the accepted set at all.** Our registry carried
`kv: iq4_nl` on the 27B family and the 30B coder, so every attention op was
scheduled onto the CPU — silently: no error, no warning, no offload log line.

Reported shape on an RTX 3090 with the same Qwen3.8-27B:

| Config | Prefill (4-10K prompt) | Generation |
|---|---|---|
| `q8_0 / q8_0` | 991-1,276 t/s | ~60 t/s |
| `K=q4_1, V=q8_0` | 34-106 t/s | ~60 t/s |

Rebuilt with the flag, the same reporter measured ~20K 1,094 / ~65K 852 /
~120K 659 t/s prefill.

**Fix applied here:** all six affected registry entries now use `kv: q8_0` for
both K and V; the router was restarted so it takes effect.

> **The rule:** the KV cache type must be one the CUDA flash-attention kernel
> accepts, **and K must equal V**. Use `q8_0`/`q8_0` (quality + GPU speed) or
> `q4_0`/`q4_0` (half the KV memory, more context, some quality loss). Never mix
> K and V, and never IQ4_NL / Q4_1 / Q5_* on a default build — it costs ~20-30x
> prefill with no diagnostic.

**For smaller KV (= more context) at full speed**, rebuild llama.cpp with
`-DGGML_CUDA_FA_ALL_QUANTS=ON`, which compiles the q4_1/q5_0/q5_1 kernels and
permits K != V. Blocked on this host today: no CUDA toolkit (`nvcc` absent) and
no passwordless sudo, and the distro package `extra/llama-cpp 0.4.0-1` is
CPU-only (`/usr/bin/llama-server --list-devices` → none).

**KV memory for this model** (Qwen config: 16 full-attention layers, 4 KV heads,
head dim 256 → 65,536 B/token at F16):

| Context | F16 KV | Q8_0 KV | Q4 KV |
|---|---|---|---|
| 65,536 | 4.00 GiB | 2.00 GiB | 1.00 GiB |
| 81,920 | 5.00 GiB | 2.50 GiB | 1.25 GiB |
| 131,072 | 8.00 GiB | 4.00 GiB | 2.00 GiB |

Against 11.05 GiB of IQ3_XXS weights on a 16 GB card, `q8_0` at 80K (~2.5 GiB)
fits with room for the compute buffer; 131K (~4 GiB) is tight. A smaller weight
quant is what buys context, not a smaller KV type (see the trap above).

**Two earlier diagnoses in §10.5.9 were wrong and are superseded.** The 6.2 t/s
reading was blamed first on battery power capping, then on context length.
Context length is a real *secondary* effect, but the governing fault was the CPU
attention fallback above — which also explains why prefill sat at ~14.5 t/s while
the GPU drew near its 115 W cap. The context-scaling table in §10.5.9 remains
valid as a shape, but every number in it was taken with the CPU-attention config
and must be re-measured after the `q8_0` fix.


---

### 10.5.11 FIX VERIFIED — all models at maximum context, GPU-resident (2026-09-12)

The §10.5.10 fix (`kv: q8_0`, K == V, on every model) was applied to the
registry and every model re-measured with a real ~8K-token request after a
warm-up. **Prefill recovered from CPU speed to GPU speed: 14.5 -> 495 t/s on the
27B and 17.4 -> 2,251 t/s on the 30B coder.**

| Model | quant | weights | ctx | prefill t/s | decode t/s | peak VRAM | kernel |
|---|---|---|---|---|---|---|---|
| Qwen3.5-4B | Q4_K_S | 2.41 GiB | **262,144** | 2,705 | **91.3** | 9,337 MiB | q8_0/q8_0 |
| Qwen3.6-35B-A3B (MoE) | IQ2_XXS | 10.02 GiB | **262,144** | 2,057 | **89.4** | 14,763 MiB | q8_0/q8_0 |
| Qwen3-Coder-30B-A3B (MoE) | IQ2_M | 10.09 GiB | **90,112** | 2,251 | **67.0** | 15,673 MiB | q8_0/q8_0 |
| Qwen3.8-27B (dense) | IQ3_XXS | 11.05 GiB | **114,688** | 495 | **20.7** | 15,345 MiB | q8_0/q8_0 |

All four are 100% GPU (`ngl 999`), `-np 1`, batch 2048, flash-attn on, temp 0
seed 42, on the RTX 3080 Laptop 16 GB. `n_ctx` read back from `/props` each time.

**How each ceiling was found** — and why "loads" is not "works":

- The 27B **loads** at 131,072 (15,741 MiB) but **core-dumped on the first real
  request**. 114,688 is the largest value that survives an actual prompt
  (peak 15,345 MiB). Never take a load as proof of a working ceiling.
- The 30B coder fails to load at 98,304 entirely; 90,112 works (peak 15,673 MiB,
  only ~700 MiB spare).
- The 4B and the 35B-A3B reach the model's **full native 262,144**, because
  their KV is small: both are hybrid architectures where only 8 of 32 (4B) and
  10 of 40 (35B) blocks keep a KV cache. At q8_0 that is 17.0 and 10.6 KiB/token
  respectively — against 32 KiB/token for the dense 27B and 51 KiB/token for the
  pure-attention 30B coder.

**The sizing rule this yields:** maximum context is bought by a *small KV*, and
KV size is set by the architecture (how many blocks are full-attention) and the
KV type — not by the weight quant alone. Compute KV budget as
`KV_layers x 2 x kv_heads x head_dim x bytes/elem x ctx`, then subtract weights
and ~0.9 GiB of compute buffer from 15,812 MiB.

**Service state after the fix** — `GET :8080/v1/models` on the systemd-managed
router:

```
qwen3.5-4b@q4_k_s            ctx 262144
qwen3.6-35b-a3b@iq2_xxs      ctx 262144
qwen3-coder-30b-a3b@iq2_m    ctx  90112
qwen3.8-27b@iq3_xxs          ctx 114688
qwen3.8-27b-cpu@iq3_xxs      ctx 114688   (CPU-only variant)
nomic-embed-text-v1.5@embed  ctx   8192
```

pi (`~/.pi/agent/models.json`, provider `llamacpp` -> `:8080/v1`) advertises all
five chat models with exactly these `contextWindow` values — static entries, so
pi never falls back to its 8,192 default in router mode.

---

### 10.5.12 The internal AMD iGPU — the 4B without the eGPU (2026-09-12)

This box has two display devices: the **XG Mobile RTX 3080 eGPU** (card0, what
the router uses) and the **AMD Cezanne Radeon Vega iGPU** (card2, the internal
one). There is no 3050 and no 1080 on this machine. The CUDA build cannot reach
the AMD device; LM Studio's **Vulkan** build can (see HOST-RUNBOOK §10).

Qwen3.5-4B Q4_K_S (2.41 GiB) on Vulkan0, q8_0 KV, `ngl 999`, batch 512, with the
same 7,937-token prompt used elsewhere in this section:

| ctx configured | prefill t/s | decode t/s | wall | RAM |
|---|---|---|---|---|
| 32,768 | 129.3 | 11.7 | 73 s | — |
| **262,144** (native max) | **128.0** | **11.7** | 73 s | 15 GiB of 30 GiB |

Both configurations load and serve; context is nearly free because the iGPU has
no VRAM and borrows system RAM. The cost is speed: **~8x slower decode and ~21x
slower prefill** than the same model fully resident on the XG Mobile 3080
(91.3 / 2,705). Throughput is flat across configured context — attention tracks
the context actually in use, not the ceiling.

**Host correction:** this machine has **30 GiB of RAM**, not the 122 GiB recorded
in §10.5 and the README (that figure belongs to the earlier A5000 box). Check
`/proc/meminfo` before sizing anything RAM-backed.

---

### 10.5.13 Dual-GPU — the eGPU and the internal iGPU serving at once (2026-09-12)

Both GPUs of this box can serve simultaneously: the XG Mobile RTX 3080 via CUDA
on `:8080` (the router) and the **internal AMD Vega iGPU** via Vulkan on `:8097`
(`llama-igpu`). Full write-up: [`DUAL-GPU.md`](./DUAL-GPU.md).

Same ~1.5K-token prompt fired at both endpoints at the same instant:

| Where | model | prefill t/s | decode t/s | note |
|---|---|---|---|---|
| eGPU :8080 | Qwen3.6-35B-A3B IQ2_XXS @ 262,144 | 1,858 | **92.7** | peak 14,764 MiB / 16,384, 95% util |
| iGPU :8097 | Qwen3.5-4B Q4_K_S @ 262,144 | 8.2 | **9.0** | concurrent with the above |

Solo: eGPU 2,057 / 89.4, iGPU 128.0 / 11.7.

**Decode coexists; prefill contends.** The eGPU's decode was unaffected
(92.7 vs 89.4) but the iGPU's prefill fell from **128 to 8.2 t/s (15x)** — it has
no VRAM of its own and reads weights and KV from system RAM, competing with the
eGPU model's CPU threads and host bandwidth. Treat the internal GPU as a
background server, not a second lane for long prompts.

**Trap found by this test — batch size vs VRAM.** The eGPU child died mid-request
with `CUDA error: out of memory` at 15,976 MiB. Cause: the router preset INI
defaulted to `batch-size = 4096 / ubatch-size = 4096` while every verified
configuration had been measured at **2048**; at 262,144 ctx the wider batch's
compute buffer no longer fit. Fixed in the generator `[*]` defaults
(2048/2048, threads 16) and per-model. After the fix both models completed and
peak VRAM settled at 14,764 MiB.

**Lesson:** a model that loads is not a model that runs — push a real request at
the exact configuration you intend to ship, and count the router's preset
defaults as part of that configuration.

---

### 10.5.14 Qwen3.5-9B Q4_K_S — verified at its native window (2026-09-12)

Weights 5.02 GiB; geometry 32 blocks, **8 KV-bearing**, 4 KV heads x 256, so
q8_0 KV is **17.0 KiB/token**. The registry named its path but the window had
never been verified (it was inherited from the earlier A5000 box).

| Where | ctx | prefill t/s | decode t/s | memory |
|---|---|---|---|---|
| eGPU 3080 | **262,144** | **1,797.8** | **61.5** | 11,470 MiB at load |
| eGPU 3080 | 100,000 | 1,783.0 | 61.8 | 7,512 MiB at load |
| internal iGPU (Vulkan) | 262,144 | 80.8 | 7.1 | ~9 GiB RAM, 10 s load |

End-to-end through the router: reply `9b ready`, 55.2 t/s, 10,900 MiB resident.

The 9B repeats the pattern for the third time — **the ceiling buys memory, not
speed** (61.5 vs 61.8 t/s, ~4 GiB apart). Registry: the four 9B ids all carry
the verified 262,144 with `kv: q8_0`, `batch: 2048`, `threads: 16`; the legacy
`9b-highctx` alias was collapsed into `qwen3.5-9b@q4_k_s`, and the light option
became an explicit pair `9b-100k` / `9b-100k-swap` at 100,000. Consolidated
table of every verified model: [`../HOST-RUNBOOK.md`](../HOST-RUNBOOK.md) §11.
