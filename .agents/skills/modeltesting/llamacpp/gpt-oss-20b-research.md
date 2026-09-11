# GPT-OSS 20B (F16 GGUF) — research + bench on zerwiz

Settings + measured results for OpenAI's **gpt-oss-20b** running via llama.cpp
on zerwiz (RTX A5000 **16 GB VRAM**, 16 cores / 122 GiB RAM).

- GGUF: `~/Models/unsloth/gpt-oss-20b-GGUF/gpt-oss-20b-F16.gguf` (**13.8 GB, F16**)
- llama.cpp CUDA build `6703d78`
- Status: **verified working 2026-09-08**, pure GPU at 100K ctx
- Companion: `../backends-benchmark.md` §9/§10, `TESTING.md`

---

## 1. What gpt-oss-20b is (from config.json, not guessed)

| Key | Value | Why it matters |
|---|---|---|
| Architecture | `gpt-oss` | **MoE** (sparse) |
| Total / active params | **~21 B / 3.6 B** | only 3.6 B active per token |
| Experts | **32 per layer**, **4 active/token** | routed expert FFN = bulk of weights |
| Layers | **24** (12 sliding-attn + 12 full-attn) | sliding window halves attention cost |
| Train context | **131,072 (131K)** | 100K is comfortable |
| `n_head` / `n_head_kv` | 64 / 8 | GQA |
| `n_embd` | 2880 | — |
| FFN | expert (MoE) | — |

Because only ~3.6 B of ~21 B params are active per token, the routed experts
are the same CPU-offload story as the other MoEs on this box — but **unlike
Qwen3.8-Flash-Next, gpt-oss-20b is small enough that it fits pure GPU** on the
A5000, so it runs at GPU speed.

---

## 2. Measured results (this box, 2026-09-08)

Build: CUDA llama.cpp `6703d78`, `-ngl 999 --flash-attn on -t 8`, temp 0,
seed 42, `-np 1`, `--reasoning off`.

| Context | KV cache | Offload | VRAM GPU | Prefill t/s | Decode t/s | GPU util |
|---|---|---|---|---|---|---|
| 60,000 | f16 | pure GPU | 14,534 MiB | **157** | **29.1** | 91% |
| **100,000** | **q8_0** | pure GPU | **15,496 MiB** | **141.9** | **28.4** | 93% |
| 100,000 | f16 | pure GPU | — | **OOM** (weights + f16 KV) | — | — |
| 131,072 | q8_0 | pure GPU | — | tight/untested | — | — |

**Key findings:**
- **Pure GPU at 100K ctx is the sweet spot** with `--cache-type-k/v q8_0`
  (~15.5 GB, ~500 MB headroom). f16 KV OOMs at 100K (weights eat the VRAM).
- **Fast and GPU-bound**: prefill ~142 t/s, decode ~28 t/s, GPU util ~93% —
  nothing like the CPU-bound Flash-Next (~5 t/s).
- This is a genuinely **GPU-usable 100K-context model** — the first of its kind
  on this box (the 35B/27B MoEs were all CPU-bound or ctx-limited).

---

## 3. Launch recipe (llama-server)

```bash
/home/zerwiz/llama.cpp/build/bin/llama-server \
  -m /home/zerwiz/Models/unsloth/gpt-oss-20b-GGUF/gpt-oss-20b-F16.gguf \
  -ngl 999 --flash-attn on \
  --cache-type-k q8_0 --cache-type-v q8_0 \
  -c 100000 -b 4096 -ub 4096 -t 8 --jinja --temp 0 --seed 42 \
  -np 1 --reasoning off --port 8096
```

Point any OpenAI-compatible client at `http://localhost:8096/v1`.

### Context presets on 16 GB (F16 GGUF)

| Target ctx | KV | Notes |
|---|---|---|
| 60K | f16 | safest, ~1.5 GB headroom |
| **100K** | **q8_0** | **recommended** — ~500 MB headroom |
| 131K (max) | q4_0 | untested, very tight |

Rule: at 100K the compute buffer (batch 4096) + weights leave little room, so
**quantize KV to q8_0 before raising ctx**. Lower `-b`/`-ub` to 2048 if 100K
is tight.

---

## 4. Why this beats Flash-Next on this box

| Model | ctx | VRAM | Decode t/s | GPU util | Verdict |
|---|---|---|---|---|---|
| **gpt-oss-20b F16** | **100K** | 15.5 GB | **~28** | **93%** | GPU-bound, fast, 100K |
| Qwen3.8-Flash-Next Q3 | 100K | 13.5 GB | ~4–5 | 6% | CPU-bound (90 GB MoE) |

gpt-oss-20b is ~6× faster decode at the same 100K ctx because it **fits the
GPU**. Prefer it over Flash-Next for any GPU-speed 100K need on this card.

---

## 5. Tuning knobs

- **Context 100K is the practical max** on 16 GB (F16 weights). For 131K, drop
  KV to q4_0 and/or batch to 2048 — untested, verify with nvidia-smi.
- **`--n-cpu-moe`** is NOT needed (fits pure GPU). If you must go past 100K,
  offloading a couple expert layers (`--n-cpu-moe 2-3` per the llama.cpp guide)
  frees VRAM for KV at a small decode cost.
- **`-t 16`** (vs 8) may help the CPU parts; GPU-bound so gain is small.
- **`--reasoning off`** unless you need CoT (saves tokens, like the Qwen MoEs).

---

## 6. Sources

- ggml-org/llama.cpp Discussion #15396 — official gpt-oss run guide
  (`--n-cpu-moe` examples for 8/12/16 GB cards)
- unsloth/gpt-oss-20b-GGUF — the F16 GGUF used here
- machineoftworks.com — "Running MoE LLMs on 16GB VRAM" (gpt-oss-20b is the
  clean 16 GB fit; MXFP4 12.1 GB fits 60K with zero offload)
- runaihome / smeltcore — gpt-oss-20b local guides (ctx caps by card)

## 7. Wiring it in (2026-09-08)

- **Registry**: `gptoss20b` + `gptoss20b-swap` in `llama-models.yaml`
  (port **8096**, ctx **100000**, `kv: q8_0`, `ngl: 999`).
- **Router**: generator maps it to `gpt-oss-20b@f16` (full name). Verified
  loading through `:8080` at 100K ctx, pure GPU (15.5 GB).
- **pi**: `llamacpp-gptoss20b` provider → `http://127.0.0.1:8080/v1`,
  model `gpt-oss-20b@f16`, `contextWindow: 100000`.
- **Zed IDE**: `language_models.llama.cpp` set `auto_discover: true` (pulls the
  router's 23-model catalog instead of 4 stale hardcoded ids); the 13 dead
  `openai_compatible.llamacpp-*` sub-providers (old direct ports 8081/8084/...)
  repointed to the router `:8080`.

## Related

- [`./TESTING.md`](./TESTING.md) — the bench record + how to add models
- [`./qwen36-35b-moe-coding-context.md`](./qwen36-35b-moe-coding-context.md) — the 35B MoE (pure GPU at 130K)
- [`../models/qwen3.8-flash-next-settings.md`](../models/qwen3.8-flash-next-settings.md) — the CPU-bound 125B MoE (contrast)