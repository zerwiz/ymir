# qwen3.8:27b — Ollama MoE Configuration & Testing Guide

**Model:** qwen3.8:27b (27.3B hybrid dense/MoE, 262K context, multimodal)
**VRAM baseline:** ~17-18 GB at Q4_K_M (Ollama default quant)
**Hardware target:** RTX A5000 16 GB VRAM + 122 GB system RAM
**Ollama exposes:** `num_gpu` / `OLLAMA_NUM_GPU` (layer offload), `num_ctx`, `num_parallel`, `keep_alive`
**Ollama HIDES:** `--n-cpu-moe` / `-ot` (MoE expert offload dial) — this is the critical limitation

---

## 1. Model Reality on Ollama

| Property | Value |
|---|---|
| Architecture | Hybrid linear attention + full attention (not classic MoE but "hybrid-attn dense") |
| Active params / token | ~27B (all params active — dense forward) |
| Total size (Q4_K_M) | ~17-18 GB |
| Native context | 262,144 tokens |
| Default context (trap) | 4,096 unless Modelfile sets `num_ctx` |
| Vision | Yes (bundled mmproj) |

**Key fact:** qwen3.8-27b is **not a classic MoE** — it's a hybrid-attention dense model. Every token touches all 27B params. There are NO routed experts to offload. `--n-cpu-moe` does nothing for this model.

**Consequence on 16 GB VRAM:** The model (~18 GB) **does not fit** on GPU. Ollama will auto-spill layers to CPU (via `OLLAMA_NUM_GPU` heuristic). You cannot control which layers — only *how many* via `num_gpu`.

---

## 2. Ollama MoE Control — What You Can't Do

```bash
# llama.cpp (raw) — FULL control
llama-server -m qwen3.6-35b-a3b -ngl 999 --n-cpu-moe 999 --cpu-moe  # MoE experts → CPU

# Ollama — HIDDEN, no access
# OLLAMA_NUM_GPU controls total layers on GPU (not MoE-specific)
# NO --n-cpu-moe, NO -ot, NO expert-offload dial
```

**For qwen3.8:27b specifically:** it's NOT a MoE with experts. It's dense hybrid. So "MoE offload" is irrelevant — the whole model either fits or spills. The `OLLAMA_NUM_GPU` layer count is your only lever.

---

## 3. Recommended Modelfiles

### 3.1 80K Context (coding target)
```bash
cat > ~/Modelfile.qwen3.8-27b-highctx-80k <<'EOF'
FROM qwen3.8:27b
PARAMETER num_ctx 81920
TEMPLATE {{ .Prompt }}
PARAMETER temperature 0.2
PARAMETER top_p 0.95
PARAMETER min_p 0.05
PARAMETER repeat_penalty 1.05
PARAMETER repeat_last_n 256
EOF
ollama create qwen3.8:27b-highctx-80k -f ~/Modelfile.qwen3.8-27b-highctx-80k
```

### 3.2 32K Context (balanced)
```bash
cat > ~/Modelfile.qwen3.8-27b-highctx-32k <<'EOF'
FROM qwen3.8:27b
PARAMETER num_ctx 32768
TEMPLATE {{ .Prompt }}
PARAMETER temperature 0.2
PARAMETER top_p 0.95
PARAMETER min_p 0.05
PARAMETER repeat_penalty 1.05
PARAMETER repeat_last_n 256
EOF
ollama create qwen3.8:27b-highctx-32k -f ~/Modelfile.qwen3.8-27b-highctx-32k
```

### 3.3 4K Context (default/trap baseline)
```bash
# No Modelfile needed — base model loads at 4096 (Context Trap)
# Or explicit:
ollama create qwen3.8:27b-base -f <(echo -e 'FROM qwen3.8:27b\nPARAMETER num_ctx 4096')
```

---

## 4. Layer Offload Tuning (OLLAMA_NUM_GPU)

Since the model is ~18 GB and VRAM is 16 GB, you MUST offload some layers to CPU.

| Setting | Behavior | Expected VRAM | Speed |
|---|---|---|---|
| `OLLAMA_NUM_GPU=-1` (default) | Try all layers on GPU → fails, spills auto | ~15-16 GB GPU + rest CPU | Slow (auto-spill overhead) |
| `OLLAMA_NUM_GPU=999` | Force all GPU → OOM or heavy spill | OOM or 16 GB + swap | Unstable |
| `OLLAMA_NUM_GPU=35` | ~35 layers GPU, rest CPU | ~12-14 GB GPU | **Best hybrid** |
| `OLLAMA_NUM_GPU=0` | Full CPU | 0 GB GPU | Very slow (~3-5 t/s) |

**Start point:** `OLLAMA_NUM_GPU=35` (approx 14 GB GPU + 4 GB CPU). Tune by watching `nvidia-smi`:
- VRAM stable < 15.5 GB = good
- VRAM hits 16 GB and system RAM climbs = spill overhead killing speed

```bash
# Test with explicit layer count
OLLAMA_NUM_GPU=35 ollama run qwen3.8:27b-highctx-80k "write a python class for LRU cache"
```

---

## 5. Benchmark Matrix (clean baseline, unload between)

**Script:** `/tmp/opencode/bench_one.sh` (load → `ollama ps` verify → warmup → timed → GPU capture → unload)

| Config | Context | OLLAMA_NUM_GPU | VRAM (GPU/CPU) | Prefill t/s | Decode t/s | Notes |
|---|---|---|---|---|---|---|
| base | 4096 | auto | 18 GB 25/75% | 165 | 9.0 | Spill at default ctx |
| 32k Modelfile | 32,768 | auto | ~20 GB 50/50% | TBD | TBD | KV larger = more spill |
| 80k Modelfile | 81,920 | auto | ~20 GB 50/50% | TBD | TBD | Target coding context |
| 80k Modelfile | 81,920 | 35 | ~14 GB 100/0% | TBD | TBD | **Target: force GPU-fit** |
| 80k Modelfile | 81,920 | 0 | 0/20 GB CPU | TBD | TBD | CPU-only baseline |

**Expected reality at 80K + 35 layers:**
- 14 GB KV + model on GPU = ~15-16 GB (tight but fits)
- Prefill should jump from ~165 → ~800-1200 t/s (GPU-class)
- Decode ~20-30 t/s (vs 9 t/s spill)

---

## 6. Running the Tests

```bash
# 1. Clean baseline
for m in $(ollama ps | tail -n +2 | awk '{print $1}'); do ollama stop "$m"; done
sleep 2
nvidia-smi --query-gpu=memory.used --format=csv,noheader

# 2. Test base 4K (auto-spill) — already done: 165 t/s prefill, 25/75% CPU/GPU

# 3. Test 32K Modelfile (auto)
bash /tmp/opencode/bench_one.sh qwen3.8:27b-highctx-32k 0

# 4. Test 80K Modelfile (auto)
bash /tmp/opencode/bench_one.sh qwen3.8:27b-highctx-80k 0

# 5. Test 80K with forced GPU layers
OLLAMA_NUM_GPU=35 bash /tmp/opencode/bench_one.sh qwen3.8:27b-highctx-80k 0

# 6. Test 80K CPU-only
OLLAMA_NUM_GPU=0 bash /tmp/opencode/bench_one.sh qwen3.8:27b-highctx-80k 0
```

---

## 7. Key Ollama Settings for MoE/Hybrid Models

| Env / Flag | Purpose | For qwen3.8:27b |
|---|---|---|
| `OLLAMA_NUM_GPU=N` | Layers on GPU (0=all CPU, -1=all GPU) | **35** for 80K on 16 GB |
| `OLLAMA_NUM_PARALLEL=N` | Concurrent requests (adds KV per request) | 1 for max context |
| `OLLAMA_KEEP_ALIVE=3600` | Keep model loaded (avoids reload) | Use for bench runs |
| `OLLAMA_FLASH_ATTENTION=1` | Flash attention (saves VRAM) | **ON** — saves ~15% KV |
| `num_ctx` (Modelfile/API) | Context window | 81920 for coding |
| `OLLAMA_GPU_LAYERS` | Alias for NUM_GPU | Same as above |

**Flash attention is critical at 80K** — it cuts KV VRAM by ~15-20%, the difference between fitting and spilling.

```bash
# Full optimized run
OLLAMA_NUM_GPU=35 OLLAMA_FLASH_ATTENTION=1 OLLAMA_KEEP_ALIVE=3600 \
  ollama run qwen3.8:27b-highctx-80k "implement async redis pool in python"
```

---

## 8. What NOT to Expect from Ollama MoE

| Wish | Reality |
|---|---|
| `--n-cpu-moe 999` (offload all experts) | **Hidden** — Ollama issue #11772 open since 2025 |
| Per-expert offload control | **Not exposed** — only total layer count |
| MoE-specific batch sizing (`-b 4096`) | **Not exposed** |
| KV quantization (`-ctk q4_0`) | **Not exposed** |
| Expert regex offload (`-ot exps=CPU`) | **Not exposed** |

**Workaround for true MoE (qwen3.6-35b-a3b, gemma-4-26b-a4b):**
- Use raw llama.cpp (or LM Studio with custom args) where you control `--n-cpu-moe`
- Or use Colibri (disk-streamed MoE) for CPU-big models

---

## 9. qwen3.8:27b Coding Workflow on This Box

**Best practical config for 16 GB VRAM:**
1. Modelfile: 80K context + coding sampling params
2. `OLLAMA_NUM_GPU=35` (tune: find max that keeps VRAM < 15.5 GB)
3. `OLLAMA_FLASH_ATTENTION=1` (saves ~2 GB KV at 80K)
4. `OLLAMA_KEEP_ALIVE=3600` (avoid reload between agent turns)
4. `OLLAMA_NUM_PARALLEL=1` (single request max context)

**If even 35 layers spills:** drop to 32K context or accept CPU-mixed speed.

**If you NEED 100K+ pure GPU for MoE:** use llama.cpp router mode with `--n-cpu-moe 999` + low quant (IQ3_S/IQ3_XXS) — that's what the bench plan §12.5 recommends as #1 backend.

---

## 10. Quick Reference Card

```bash
# Create 80K coding Modelfile
cat > ~/Modelfile.qwen3.8-27b-coder-80k <<'EOF'
FROM qwen3.8:27b
PARAMETER num_ctx 81920
TEMPLATE {{ .Prompt }}
PARAMETER temperature 0.2
PARAMETER top_p 0.95
PARAMETER min_p 0.05
PARAMETER repeat_penalty 1.05
PARAMETER repeat_last_n 256
EOF
ollama create qwen3.8:27b-coder-80k -f ~/Modelfile.qwen3.8-27b-coder-80k

# Verify loaded context
ollama run qwen3.8:27b-coder-80k --verbose "hi" >/dev/null 2>&1
ollama ps | grep qwen3.8

# Bench (clean, GPU capture)
OLLAMA_NUM_GPU=35 OLLAMA_FLASH_ATTENTION=1 bash /tmp/opencode/bench_one.sh qwen3.8:27b-coder-80k 0

# Unload
ollama stop qwen3.8:27b-coder-80k
```

---

## 11. Recording Results

Update **two places** after each accepted run:
1. `backends-benchmark.md` §10.5 / §10.5.3
2. `ollama/TESTING.md` §8 (add qwen3.8 rows)
3. **`~/.pi/agent/models.json`** — set `contextWindow: 81920`, note `processor: "50/50 CPU/GPU"` or `100% GPU` per actual `ollama ps`