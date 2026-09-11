# Ollama Testing — high-context Modelfiles and the Context Trap

Per-backend testing guide for **Ollama**. This is the parallel candidate to LM
Studio for the high-context path — it already has `qwen3.5:9b-highctx-262k/196k`
Modelfiles — but its silent **4096 context default** makes every number suspect
until verified. Numbered sections map to
[`../backends-benchmark.md`](../backends-benchmark.md).

- Date: 2026-09-04
- Machine: zerwiz (RTX A5000 Laptop **16 GB VRAM**, 122 GiB RAM)
- Ollama: `/usr/local/bin/ollama serve`; engine `/usr/local/lib/ollama/llama-server`
- Status: **Modelfiles verified high-ctx; clean re-bench needed to confirm real 262K/196K vs silent 4096**

---

## 1. Why this folder matters to the bench — the Context Trap

Ollama's central testing hazard (§3, §5) is the **Ollama Context Trap**:

> "Ollama loads a model at 4096 tokens by default, no matter what the model
> supports. A prompt past that is not rejected and does not error — Ollama
> discards the older half of the context and evaluates the rest."

**Consequence:** any Ollama number without an explicit `num_ctx` in the API
call (or `OLLAMA_NUM_CTX`) is suspect. The earlier "262K" run that appeared
~10x faster may have been a 4096-window prefill — a *completely different*
measurement.

**Verification on this box (§10.5):** the high-ctx is genuinely set in the
Modelfiles (`num_ctx 262144` / `196608`) — **not** a 4096 trap and not fake for
these models. So the number is real *in config*; what the clean run must verify
is whether the **physically large KV cache** fits/spills on the 16 GB card.

---

## 2. Current state on this box

| Item | State |
|---|---|
| Server | running (`ollama serve`) |
| Built Modelfiles | `qwen3.5:9b-highctx-262k` (`num_ctx 262144`), `qwen3.5:9b-highctx-196k` (`num_ctx 196608`) |
| Context trap | verified analytically — needs runtime confirm (`ollama ps` CONTEXT column) |
| MoE control | **`--n-cpu-moe` / `-ot` hidden** (§9.5) — cannot reproduce the llama.cpp MoE strategy |
| Wrapper overhead | ~10–20% slower than raw llama.cpp in published tests |

---

## 3. The benchmark procedure — Ollama specifics (§3, §10.6)

**Always pass `num_ctx` explicitly, then verify it actually loaded at that
context.** `ollama ps` CONTEXT column must show your target, not 4096.

```bash
# restore clean baseline — MUST ollama stop before/after each run (§3)
ollama stop
nvidia-smi --query-gpu=memory.used --format=csv,noheader   # confirm baseline
sleep 5

# warmup (discard)
ollama run <model> --verbose "warmup" > /dev/null 2>&1

# timed run — explicit num_ctx, temp 0, seed
curl -s http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "<model>",
    "prompt": "<test prompt>",
    "stream": false,
    "options": {
      "num_ctx": 81920,       # 80K — NEVER rely on defaults
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

# VERIFY the context actually took (the trap check):
ollama ps    # CONTEXT column must show 81920 (or your target), NOT 4096
```

Capture GPU during the run in parallel, then `ollama stop` + confirm clean
before the next engine (§3.6).

---

## 4. The models to test — Ollama tags (§10.6)

Target quants low enough to fit 16 GB and hold 80–100K on GPU (dense) or via
MoE spill:

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

> If `ollama pull` says "file does not exist", the tag differs — list real tags
> first before guessing:
> `curl -s https://ollama.com/library/qwen3.6/tags | grep -o '"name":"[^"]*"' | head -40`
> Pulls are done by the user, **not the agent** (AGENTS/bench rules).

---

## 5. High-ctx Modelfiles — what the clean run proves (§10.5)

Confirmed in config: `qwen3.5:9b-highctx-262k` → `num_ctx 262144`,
`196k` → `num_ctx 196608`. So:

- **Bench target:** whatever you want (80K / 100K / 196K / 262K), GPU-first,
  **CPU spill acceptable** (122 GB RAM, 8 real cores).
- The only real, narrow caveat is physical: a 262K/196K KV cache is large; on
  16 GB VRAM it may (or may not, for a 9B) need CPU spill. **That** is what the
  clean runs below measure — record it, don't assert it impossible.

To check what a high-ctx Modelfile actually loaded at:

```bash
ollama run qwen3.5:9b-highctx-262k --verbose   # RTN_NUM_CTX / verbose footer
ollama ps                                       # CONTEXT column = truth
```

---

## 6. MoE on Ollama — the control limit (§9.5)

Ollama **hides `--n-cpu-moe` / `-ot`**. For MoE it only exposes
`OLLAMA_NUM_GPU` / `num_gpu`. So for MoE on Ollama you mostly get whatever
default llama.cpp picks; if it can't fit it spills to CPU automatically.

- If Ollama's default assignment is too slow for `qwen3.6-35b-a3b` / gemma,
  that's a **finding** (Ollama can't express the §9 placement strategy) — not a
  fix here.
- To reproduce a controlled MoE comparison, **prefer raw llama.cpp (or LM
  Studio launch args)** where you control `--n-cpu-moe`, KV quant, and batch.
- At minimum for Ollama MoE: pass explicit `num_ctx` and confirm `ollama ps`
  shows your target (the trap from §1/§5).

---

## 7. Expected values / decision gate

- **Context trap check first:** numbers that don't pass the `ollama ps` CONTEXT
  verification are discarded.
- With the high-ctx truth confirmed, does `qwen3.5:9b-highctx-262k` genuinely
  run 262K at faster-than-LM-Studio speed (§2/§5 of parent)? If yes, the path
  to 100K+ fast coding is simply "Ollama at a big explicit context." If the
  physical KV forces CPU spill, that t/s collapse is the finding.
- Compare wrapper overhead vs raw llama.cpp (§3: ~10–20%).

---

## 8. What to record / outcomes

> **After every accepted test, always update `~/.pi/agent/models.json`:**
> set the model's `contextWindow` to the verified `ollama ps` CONTEXT value
> (not the Modelfile request) and reflect CPU-spill/processor findings, so pi's
> registry is never stale (§ shared rule 8).

- Fill §10.5 rows A–D at 80K/100K (and the high-ctx CPU-fallback table if
  spilling). Always with the `ollama ps` CONTEXT evidence.
- Decision inputs for §12.3: does Ollama do acceptable on-demand load/unload
  (`ollama run`/`stop`/`ps`) over the gateway for pi, and does its hidden MoE
  control disqualify it for the MoE fast lane?

### 8.1 CLEAN RESULTS — high-ctx verified (2026-09-04)

**196K** — `qwen3.5:9b-highctx-196k` at true `num_ctx 196608`
(`ollama ps` → `11 GB | 100% GPU | CONTEXT 196608`), peak VRAM 12,690 MiB:

| Metric | value |
|---|---|
| Real context | **196,608** (verified, not 4096 trap) |
| Resident | 11 GB, **100% GPU** |
| Peak VRAM | 12,690 MiB (**fits** 16 GB) |
| Prefill t/s | ~1,600–1,635 (GPU-class; small-prompt 126.7 was a sampler gap) |
| Decode t/s | ~43–58 |
| GPU util (prefill) | 100% / 99% / 81% |

**262K** — `qwen3.5:9b-highctx-262k` at true `num_ctx 262144`
(`ollama ps` → `14 GB | 100% GPU | CONTEXT 262144`), 9,823-token prompt:

| Metric | value |
|---|---|
| Real context | **262,144** (verified, not 4096 trap) |
| Resident | 14 GB, **100% GPU** |
| Peak VRAM | 14,802 MiB (**fits** 16 GB, ~1.6 GB headroom) |
| Prefill t/s | **1,645.6** |
| Decode t/s | 55.4 |
| Wall | 6.26 s (9.8k-token prompt) |
| GPU util (prefill) | 100% / 99% |

**Conclusion:** both high-ctx dense-9B Modelfiles **work, fit GPU, no CPU spill**,
and run GPU-class prefill (~1,600–1,645 t/s). The earlier ~10x / 1532 t/s "262K"
claim is confirmed real. Next: MoE models (§10.6) and real decode-length gen.

### 8.2 ALL Ollama models tested — full sweep (2026-09-04)

Tested every generation-capable Ollama model, each on a clean baseline (26 MiB),
warmup discarded, `temp 0, seed 42, num_predict 5`, 0.25 s GPU sampler,
then unloaded. Same 9,823-token mid prompt (base/vl runs are 4,096-ctx
defaults, so their prefill counts differ).

| Model | Modelfile num_ctx | ACTUAL ctx (`ollama ps`) | Prefill t/s | Decode t/s | Peak VRAM | GPU% | Notes |
|---|---|---|---|---|---|---|---|
| `qwen3.5:9b-highctx-262k` | 262144 | **262,144** ✅ | 1,645.6 | 55.4 | 14,802 MiB | 100 | fits 16 GB (~1.6 GB headroom) |
| `qwen3.5:9b-highctx-196k` | 196608 | **196,608** ✅ | ~1,600–1,635 | ~43–58 | 12,690 MiB | 100 | fits 16 GB |
| `qwen3.5:9b-32k` | 32768 | **32,768** ✅ | 1,446.2 | 49.2 | 7,538 MiB | 100 | fits |
| `qwen3.5:9b` (base) | — | **4,096** (trap) | 1,568.3 | 57.1 | 6,486 MiB | 100 | ⚠️ Context Trap confirmed |
| `qwen3-vl:8b` | — | **4,096** (trap) | 1,756.1 | 60.8 | 7,172 MiB | 100 | ⚠️ Context Trap confirmed |
| `gemma4:e4b` | — | **4,096** (trap) | 2,395.1 | 69.1 | 4,684 MiB | 100 | ⚠️ Context Trap; fastest |
| `nomic-embed-text` | — | n/a | n/a | n/a | — | — | embedding, not gen |
| `mxbai-embed-large` | — | n/a | n/a | n/a | — | — | embedding, not gen |

**Key findings:**

1. **Context Trap CONFIRMED for the plain models.** `qwen3.5:9b`, `qwen3-vl:8b`,
   and `gemma4:e4b` all loaded at **4,096** by default (`ollama ps`), because
   their Modelfiles don't set `num_ctx`. Only the `-32k` / `-highctx-*`
   Modelfiles set it explicitly — that's exactly why those worked. Any use of the
   plain models at long context **must** pass `num_ctx` in the API call (and
   Ollama will reload the model at the request's context).
2. **Base `qwen3.5:9b` at explicit `num_ctx 100000` ran 100% GPU, no spill.**
   Passing `num_ctx: 100000` in the API request made Ollama allocate a bigger KV
   (VRAM spiked to ~10,156 MiB during the run vs 6.5 GB at 4096) and ran 1,432
   tok/s prefill — so even the plain 9B handles 100K on GPU when told to.
3. **All 6 gen models run 100% GPU prefill** (1,446–2,395 t/s) at their loaded
   contexts — none spilled to CPU on this 16 GB card.
4. **gemma4:e4b is the fastest** overall (2,395 t/s prefill, 69 decode, smallest
   4.7 GB footprint), but caps at 4,096 ctx by default.
5. Every run returned VRAM to **26 MiB baseline** after `ollama stop` — clean
   unload confirmed (no residual-memory contamination between tests, §3 pitfall 2).

**Bottom line:** the high-ctx Modelfiles (`-196k`/`-262k`) are the correct way to
get big context on Ollama; the plain models need explicit `num_ctx` per request
and still fit GPU at 100K. All are GPU-class prefill with clean unload.

### 8.3 High-ctx derivatives + VL spill (2026-09-04)

Built fresh high-context Modelfiles (`ollama create`), each verified by `ollama ps`.

| Model | Modelfile num_ctx | ACTUAL ctx | Processor | Size | VRAM | Prefill | Decode | Notes |
|---|---|---|---|---|---|---|---|---|
| `gemma4:e4b-highctx-131k` | 196608 | **131,072** (clamped) | 100% GPU | 3.4 GB | 8,624 MiB | 2,766 t/s | 72.1 | ⚠️ gemma **caps at 131,072** — 196K silently clamps |
| `qwen3-vl:8b-highctx-100k` | 100000 | **100,000** ✅ | **36%/64% CPU/GPU** | 22 GB | ~15,256 MiB | ~19.5 (CPU-mixed) | ~9.9 | ⚠️ **spills** — VL+mmproj too big for 16 GB |
| `qwen3-vl:8b-highctx-196k` | 196608 | **196,608** ✅ | **61%/39% CPU/GPU** | 37 GB | — | — | — | ⚠️ **spills hard** |

**Key findings added by this round:**

1. **gemma4:e4b CANNOT reach 196K.** Its native cap is **131,072** (`ollama show`
   → context length 131072). A 196608 Modelfile is accepted but `ollama ps`
   shows **131,072** — the earlier 196K is silently clamped. Rebuilt as
   `gemma4:e4b-highctx-131k` (its true max): 100% GPU, 2,766 t/s prefill,
   72 decode, 8,624 MiB — **fastest of all, and fits comfortably.**
2. **qwen3-vl 8B at high context SPILLS — VL models are much bigger.** Even at
   100K it's 22 GB (36%/64% CPU/GPU), and 196K is 37 GB (61%/39%) — the vision
   projector (mmproj) plus KV doesn't fit 16 GB. This is a real CPU-spill finding
   (vs. the text-only 9B that fits at 262K on GPU).
3. **Renderer/parser must be the ARCH token, not the model id.** The first VL
   Modelfiles used `RENDERER qwen3-vl` → `500: unknown renderer "qwen3-vl"` on
   generate (0 tokens / 0.02 s wall). Fix: **omit** `RENDERER`/`PARSER` and let
   Ollama inherit the base's (`FROM qwen3-vl:8b`). After rebuild it generates
   normally. Use `ollama show <model>` → `architecture` for the token if you
   must override.
4. After the fix, `qwen3-vl:8b-highctx-100k` generates (305 tokens) but at CPU-
   mixed speed (~19.5 / ~9.9 t/s) — usable but not GPU-class.
5. Every run returned to **26 MiB** baseline on unload.

**Bottom line:** for high-context + GPU-class speed on Ollama, the **text-only**
9B highctx models are the answer. The **VL model caps GPU-fit at modest context**
— treat high-ctx `qwen3-vl:8b` as CPU-spill by default on this 16 GB card.

---

## Related

- [`../backends-benchmark.md`](../backends-benchmark.md) — §3 context trap + procedure, §5 contaminated data, §10.5 Modelfiles verification + **§10.5.1 clean 196K + 262K results**, §9.5 Ollama MoE limits, §10.6 pull list, §12.5 ranking
- `~/` — the Modelfiles source (`num_ctx 262144/196608`)