# Qwen3.6-35B-A3B on llama.cpp — MoE activation & 80–130K coding context

**Verified on zerwiz** (RTX A5000 Laptop **16 GB VRAM**, 16 cores / 122 GiB RAM),
llama.cpp CUDA build `6703d78` (2026-09-04), Unsloth `UD-Q2_K_XL` GGUF.
Companion to `TESTING.md`; benchmark methodology lives in
[`../backends-benchmark.md`](../backends-benchmark.md) §3/§9/§10.

> **Headline:** on this 16 GB card the model runs **100% GPU at 130K context**
> with just two flags (`--flash-attn on` + `--cache-type-k/v q8_0`) — no
> `--n-cpu-moe` needed at all, because Qwen3.6-35B-A3B is a **hybrid
> linear-attention MoE** whose KV cache grows only ~20 KB/token (30/40 layers
> are Gated DeltaNet, fixed state). The one MoE-specific knob (`--n-cpu-moe`)
> exists for the Q4_K_S / Q5_K_M quants that DON'T fit — see §5.

---

## 1. What this model is (verified from the GGUF, not guessed)

`llama-cli -v` metadata for `Qwen3.6-35B-A3B-UD-Q2_K_XL.gguf`:

| Key | Value | Why it matters for coding contexts |
|---|---|---|
| Architecture | `qwen35moe` | hybrid **MoE + Gated DeltaNet linear attention** |
| Total / active params | 34.66 B / ~3 B (A3B) | 8 of 256 experts used per token |
| Layers | 40 (30 linear-attn / 10 full-attn) | KV cache only on attention layers |
| `n_expert` / `n_expert_used` | 256 / 8 | routing cost is tiny (expert FFN = 512-dim) |
| `n_head` / `n_head_kv` | 16 / 2 | GQA → small KV |
| `n_embd` | 2048 | — |
| Train context | **262,144** | 130K is comfortable; 262K reachable with KV quant |
| RoPE base | 10,000,000 | — |
| SSM state / inner size | 128 / 4096 | linear-attention layers hold fixed state, not per-token KV |

**The key structural fact:** in a *hybrid* model, only the attention layers
accumulate a KV cache; the Gated DeltaNet (SSM/linear-attention) layers keep a
**fixed-size state** regardless of sequence length. That's why KV grows at only
~20 KB/token here — about 1/4 the rate of a dense transformer of equal depth.
This is the property that makes 80–130K context feasible on 16 GB at all.

## 2. Measured results (this box, 2026-09-04)

Build: CUDA llama.cpp `6703d78`, `-ngl 999 --flash-attn on -t 8`, temp 0,
seed 42, single slot (`-np 1`). GPU clocks NOT pinned (no TTY for
`sudo nvidia-smi -lgc`); values are idle-boost, repeatable within noise.

| Context | KV cache | Batch | VRAM | Prefill | Decode | GPU util |
|---|---|---|---|---|---|---|
| 80,000 | q8_0 | 4096 | 13,975 MiB | **1,848 t/s** | **65.2 t/s** | 100% |
| 130,048 | q8_0 | 4096 | 14,885 MiB | **1,866 t/s** | **64.5 t/s** | 100% |
| 130,048 | **f16** (default) | 4096 | — | **OOM** (compute buf 1.9 GB) | — | — |

- Prefill measured via `llama-server` self-reported timings on a 7,785-token
  coding prompt (`prompt_per_second`); TTFT ≈ prefill time at n_predict start
  (~4.2 s on ~8K prompts → sub-second on typical 1–2K coding edits).
- GPU samples during prefill: 100% util, ~89 W, no CPU spill (decode ~87%).
- Both contexts fit fully on GPU — **no `--n-cpu-moe`, no CPU fallback**.
- f16 KV at 130K OOMs only because the batch-4096 compute buffer (1.9 GB) no
  longer fits after weights+KV; q8_0 KV frees enough. If you need to run 262K,
  drop KV to q4_0 and/or batch to 2048.

**Bigger quant offload runs (measured 2026-09-04, `--n-cpu-moe 999`, KV q8_0):**

| Quant | Context | VRAM (GPU) | RAM (RSS) | Prefill t/s | Decode t/s | Verdict |
|---|---|---|---|---|---|---|
| `UD-Q2_K_XL` (11.4 GB) | 130,048 | 14,885 MiB | — | 1,866 | 64.5 | **pure GPU — the pick** |
| `UD-Q4_K_S` (19.5 GB) | 80,000 | 4,751 MiB | ~20.5 GB | 774 | 23.9 | experts on CPU; 2.4× slower decode than Q2 |
| `UD-Q5_K_M` (24.6 GB) | 32,768 | 4,009 MiB | ~24 GB | 654 | 17.5 | experts on CPU; slowest |

**Offload penalty quantified:** moving all 256 routed experts to CPU costs
~2.4× on decode (65→24 t/s) and ~2.4× on prefill (1.85K→0.77K t/s) vs the
pure-GPU Q2. Q4/Q5 expert-offload only makes sense when you need the *quality*
of Q4+ and can live with ~24 t/s. For 80–130K coding on this box, **Q2_K_XL
pure GPU is strictly better on speed**; Q4/Q5 buy quality at 3× the latency.

## 3. The activation recipe for 80–130K coding (llama-server)

```bash
cd /home/zerwiz/llama.cpp
./build/bin/llama-server \
  -m /home/zerwiz/Models/unsloth/Qwen3.6-35B-A3B-GGUF/Qwen3.6-35B-A3B-UD-Q2_K_XL.gguf \
  -ngl 999 --flash-attn on \
  --cache-type-k q8_0 --cache-type-v q8_0 \
  -c 130048 -b 4096 -ub 4096 -t 8 \
  --jinja --temp 0.6 --top-k 20 --top-p 0.95 --min-p 0.0 \
  -np 1 --port 8125
```

Then point any OpenAI-compatible client at `http://localhost:8125/v1`.

**Recommended coding sampling** (Qwen3.6 official): `--temp 0.6 --top-p 0.95
--top-k 20 --min-p 0.0`. Thinking is ON by default for Qwen3.6; disable with
`--reasoning off` if you want pure direct answers (or keep it for hard tasks —
it costs tokens, not VRAM).

### Context size presets on 16 GB (all pure GPU)

| Target ctx | Flags | VRAM headroom |
|---|---|---|
| 80K | `q8_0` KV, b4096 | ~2.4 GB free |
| 130K | `q8_0` KV, b4096 | ~1.5 GB free |
| 196K | `q8_0` KV, b2048 | tight (~16 GB) — test before trusting |
| 262K | `q4_0` KV, b2048 | marginal — verify with nvidia-smi; or CPU-KV spill |

Rule of thumb on this card: **KV quant q8_0 is the default; drop to q4_0 only
past ~150K.** The compute buffer (batch × layers) is the hidden VRAM consumer —
shrink `-b`/`-ub` to 2048 before lowering KV quality.

## 4. How to verify it's really running right

1. **Model loaded on GPU** — `nvidia-smi` shows 13.9–14.9 GiB used and the
   server log shows no `out of memory`.
2. **No CPU spill** — capture GPU during prefill (`nvidia-smi` in parallel);
   expect ~100% util throughout. If util collapses mid-prompt, tensors are
   paging over PCIe.
3. **Real context** — confirm `n_ctx_slot` = target in the load log, and that
   you can prompt-process past 80K without `prompt eval time` exploding.
4. **MoE placement** — only relevant if you use `--n-cpu-moe` (see §5); read
   the load log for the `exps=CPU` assignment regex.

## 5. The MoE knob: `--n-cpu-moe` (when and when NOT)

### When NOT to use it (this exact config)
The Q2_K_XL at ≤130K fits 100% GPU. Adding `--n-cpu-moe` would move routed
expert weights to system RAM and **slow decode down** for zero benefit — the
classic V-shape: you're on the "already fits" right arm, so more offload = more
PCIe reads per token. Skip it.

### When to use it (bigger quants / longer context)
The Q4_K_S (19.5 GB) and Q5_K_M (24.6 GB) GGUFs won't fit 16 GB pure GPU. That's
the case for MoE offload — **measured on this box: Q4_K_S @ 80K = 774 prefill /
23.9 decode t/s, 4.8 GB VRAM + ~20.5 GB RAM; Q5_K_M @ 32K = 654 / 17.5 t/s,
4.0 GB VRAM.** See §2 table. The quality gain over Q2_K_XL comes at ~2.4–3.7×
decode latency — decide per workload whether Q4+ quality is worth it.

```bash
# Q4_K_S with all routed experts on CPU, attention+KV on GPU (the fast split)
./build/bin/llama-server \
  -m .../Qwen3.6-35B-A3B-UD-Q4_K_S.gguf \
  -ngl 999 --n-cpu-moe 999 \        # ALL experts → CPU (NOT partial!)
  --flash-attn on --cache-type-k q8_0 --cache-type-v q8_0 \
  -c 80000 -b 4096 -ub 4096 -t 8 --jinja --port 8125
```

**How it works:** `--n-cpu-moe N` overrides the buffer type for tensors matching
`\.ffn_(up|down|gate|gate_up)_(ch|)exps` in layers 0..N-1 (counting from the
highest-numbered layer). It moves **only routed-expert weights**; attention,
router, shared experts, norms and the KV cache stay on GPU. Since experts are
most of the weight but only a fraction of per-token work, that's the right
split.

**The rules (from backends-benchmark.md §9.3 + community data):**
1. Offload **all** experts (`--n-cpu-moe 999`) or none — partial offload is
   slow. `--cpu-moe` (all MoE weights to CPU) is the other end; don't mix.
2. Prefill takes the hit, not decode — for coding, **TTFT on a big prompt is
   the metric that matters**, and expert-offload prefill is slower. Budget for it.
3. Raise batch for CPU+GPU MoE (`-b 4096 -ub 4096`).
4. On this 16-core / 122 GiB box the CPU is strong (16 threads), so an
   all-experts-CPU Q4 split is the best quality/VRAM trade if you need Q4.
5. When the model already fits on GPU, `--n-cpu-moe` only hurts. Measure, don't
   assume (a documented 5× "speedup" is people escaping PCIe thrash, not a
   CPU win).

**Reference numbers (community, same model):** Qwen3.6-35B-A3B Q4 with full
expert offload + KV quant reached ~52 gen t/s / ~1,041 prefill t/s @ ~3.9 GB on
a 16 GB card (esonhjz recipe, from TESTING.md §5). The pure-GPU Q2 numbers
above are ~64 t/s decode — expect Q4-with-offload to land under that on decode
but higher on quality.

## 6. Why this beats the other options on this box

| Backend | Same model | Why |
|---|---|---|
| **llama.cpp CUDA (this doc)** | 130K, 100% GPU, 1.8K/64 t/s | MoE + KV-quant + hybrid-attn all native |
| LM Studio bundled engine | lags llama.cpp HEAD | its bundled engine is older; ~30–50% slower per §11.1 |
| Ollama | can't expose `--n-cpu-moe` or KV quant | text works now, but long-context tuning is locked out |
| LM Studio JIT on Q2 at 130K | CPU-spill territory | same model without KV quant spills at 130K |

## 7. Anti-patterns / gotchas (verified on this box)

- **f16 KV at 130K OOMs on the compute buffer, not the KV.** The error is
  `ggml_gallocr_reserve_n_impl: failed to allocate compute pp buffers` — not
  `out of memory` on KV. Shrink `-b` or quantize KV first.
- **`-ngl 999` + `--fit`**: when you set `-ngl` explicitly, llama.cpp aborts
  auto-fitting (`failed to fit params... n_gpu_layers already set by user`) —
  that's expected, not an error; drop `-ngl` if you want `--fit` to decide.
- **Speculative decoding (MTP/DFlash) does NOT help this MoE.** Community
  consensus (InsiderLLM, PR #19493): routing overhead eats the draft-model win
  on A3B models. A separate draft model (e.g. Qwen3.5-0.8B) *drops* throughput.
  The model's own MTP head gives only ~1.2–1.5× if you must (needs an
  MTP-converted GGUF: `unsloth/Qwen3.6-35B-A3B-MTP-GGUF`).
- **CUDA 13.2 gibberish bug**: low-bit 3.6 quants produce garbage under CUDA
  13.2 (cuBLAS path). This box uses NVCC 12.4 / driver 580.173 — fine. If you
  ever rebuild, pin 13.1/13.3 or stay on 12.x.
- **CUDA-13.2-style gibberish / wrong output:** also check context too low and
  try `--cache-type-k bf16 --cache-type-v bf16` as a quality fallback.

## 8. How to make it faster (ranked by expected gain on THIS box)

> Measured limiters, not folklore. The bench hit **87–93 W** during prefill and
> the GPU's max power limit is **110 W** — it is power-cap-bound. The clone is
> HEAD (`6703d78`, 2026-09-03), so a rebuild is NOT a lever. Decode is
> memory-bandwidth-bound (~448 GB/s A5000 vs 717 GB/s RTX 4080 = why the 4080
> hits ~147 t/s and we get ~64).

| Lever | Expected gain | Cost | Status |
|---|---|---|---|
| **Raise power cap 90→110 W** | +15–20% (cap-bound during prefill) | `sudo nvidia-smi -pl 110` | ⏳ needs TTY sudo, re-bench |
| **`--reasoning off`** | **MEASURED 3× wall-clock on coding QA** (trace ate the 500-token budget; 7.4 s→2.5 s) | free — set as default | ✅ verified |
| **MTP speculative decoding** | +20–50% decode (`--spec-type draft-mtp --spec-draft-n-max 2`) | download `unsloth/Qwen3.6-35B-A3B-MTP-GGUF` (~12 GB) | ⏳ untested |
| **KV q4_0 instead of q8_0** | +5–10% decode at 130K (KV ≈ 2.6 GB is bandwidth) | free, re-test quality | ⏳ untested |

Details / why each one works:

1. **Power cap.** `nvidia-smi --query-gpu=power.limit` shows 90 W, max limit
   110 W. The GPU drew 87–93 W during prefill → it is **clamped at the cap**,
   so SM clocks sag below the 1,635 MHz max. `sudo nvidia-smi -pl 110` (or
   `-lgc 1900`/`-lmc 7000` for pinning) gives sustained boost. **Re-bench after.**
2. **Reasoning off.** Qwen3.6 thinks by default and emits a thinking trace
   before the answer — that's extra tokens the CPU/GPU must generate. For
   coding requests where you want the answer, `--reasoning off` reaches it in
   fewer tokens. Trade-off: harder/agentic tasks lose the reasoning chain.

   **Measured (2026-09-04, same server/ctx, temp 0):**

   | Question | Reasoning ON | Reasoning OFF |
   |---|---|---|
   | "Merge two sorted linked lists, return code" | 7.30 s — **trace YES (1,936 ch), answer EMPTY** (trace ate the 500-token budget) | **2.54 s — no trace, 533-char answer** |
   | "Time complexity of binary search" | 7.40 s — trace YES (1,968 ch), answer EMPTY | **0.43 s — no trace, full answer** |

   **Verdict: on this model, thinking mode is dangerously token-hungry** — a
   ~2K-char trace per answer, and it can exhaust `max_tokens` before producing
   any content. For coding work, **`--reasoning off` is the default**; re-enable
   only for genuinely hard tasks and bump `max_tokens`/`n_predict` accordingly
   (e.g. 2–4K). (Note: `--reasoning on` is default; the server also logs a
   "preserving reasoning" warning — that's cross-turn preservation, a different
   knob.)
3. **MTP.** The model has built-in multi-token-prediction heads; llama.cpp
   merged support (PR #22673). Standard GGUFs (incl. our `UD-Q2_K_XL`) do NOT
   contain the heads — you need the MTP-converted GGUF
   (`unsloth/Qwen3.6-35B-A3B-MTP-GGUF`). Community reports ~1.2–1.5× on this
   MoE (NOT the 2× of dense models). A separate draft model does NOT help MoE —
   routing overhead eats the win, verified across reports (PR #19493).
4. **KV quant deeper.** At 130K the KV cache is ~2.6 GB of the 14.9 GB
   resident — the decode step reads K/V for every token, so smaller KV = less
   bandwidth per decode step. `q8_0` is the safe default; `q4_0` trims further
   with a small quality cost (acceptable for code autocomplete/edits). Test
   before committing past 130K.

**Not worth it on this model:** speculative decoding with a separate draft
model (slower), `--n-cpu-moe` (already fits, offloading = PCIe reads = slower),
a llama.cpp rebuild (already HEAD). MTP is the one real decode win if the
download is acceptable.

## 9. `~/.pi/agent/models.json` — what pi should show for this model

`providers.ollama.models[]` (or the serving provider you wire it to) should get:

```json
{
  "name": "qwen3.6-35b-a3b-ud-q2_k_xl",
  "contextWindow": 130048,
  "processor": "100% GPU",
  "vramMiB": 14885,
  "notes": "llama.cpp CUDA 6703d78; hybrid linear-attn MoE; KV q8_0; prefill ~1866 t/s, decode ~64 t/s"
}
```

If you serve it via llama.cpp directly, add it under the `llamacpp`/local
provider with the `:8125` endpoint and the contextWindow above (do NOT set the
train 262,144 unless the serving config actually runs 262K).

## 10. Serving it day-to-day (`model-host` + `llama-menu`)

The native servers are managed by **`~/Ymir/scripts/model-host.sh`** (the
launcher) and **`~/.local/bin/llama-menu`** (the interactive number-menu):

```
llama-menu        # pick with a keypress: [a] Q2 ⚡ [b] IQ3 [c] Q4 [d] Q5 … [e] stop
model-host status # or the CLI: start/stop/status/list per model
```

Both map the qwen3.6 quants to **port 8125** (the pi `llamacpp` provider) and
the classic roles to 8081–8084. Adding a new model to the menu is documented in
`llamacpp/TESTING.md` **§10** — bench it, pick a free port, add a `register()`
line, the model loops, `list()`, and a menu arm, then verify. Never register a
model with an unverified context or VRAM number.