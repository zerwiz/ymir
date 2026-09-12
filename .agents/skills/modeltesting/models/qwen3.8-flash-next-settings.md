# Qwen3.8-Flash-Next — GGUF run settings

Settings doc for running **Qwen3.8-Flash-Next** on zerwiz via llama.cpp.
Compiled 2026-09-07 from the model card, arXiv:2608.30320, and the llama.cpp
MoE CPU+GPU offload guides (Doctor Shotgun, bmdpat, sergiiob).

- Machine: zerwiz (RTX A5000 **16 GB VRAM**, 122 GiB RAM)
- Quant: `Q3_K_XL` — GGUF `unsloth/Qwen3.8-Flash-Next-GGUF` (3 shards, ~90 GB)
- Status: **verified working** on this box (2026-09-07)

---

## 1. Model facts (why the settings below)

| Aspect | Value |
|---|---|
| Type | Sparse MoE (preview of Qwen4 arch) |
| Total params | 125B + 51B n-gram (PLE) table + 4B MTP head |
| Active per token | **6B** |
| Experts | 512 routed, top-10 + 1 shared per token |
| Layers | 48 (36 GDN linear-attn + 12 QSA sparse-attn) |
| Context | 262K native (extendable to 1M); 100K is comfortable |
| Attention cache | **~25 KB/token** (hybrid GDN+QSA) → 100K ≈ **~2.5 GB** |
| Modality | text + image (+video) |

The **n-gram/PLE table (51B)** is designed for **host-RAM offload** and
deterministic lookup — it should stay pageable (mmap), not forced to GPU.

---

## 2. The offload strategy — "the right way"

The GPU is 16 GB; the GGUF is ~90 GB. You **cannot** put the whole model on GPU
(`-ngl 999` with `cpu_moe:false` → `cudaMalloc failed: out of memory`).

Because only **6B of 125B params are active per token**, the optimal split is:

> **GPU** = always-active path: attention/GDN, shared expert, KV cache, compute
> buffer.
> **CPU** = the 512 **routed experts** (bulk of the 90 GB, only ~6B read/token).

```
-ngl 999          # offload ALL always-active layers to GPU
--n-cpu-moe 999   # keep ALL routed-expert FFN on CPU (or -ot "exps=CPU")
```

This is the canonical MoE partial-offload pattern. On 16 GB it leaves the
routed experts in system RAM (122 GiB — plenty) while the GPU owns the hot
path. Expect slow-but-usable decode (experts read from RAM each token).

---

## 3. Verified working settings (llama-models.yaml)

Registry block (`scripts/llama-models.yaml`, id `q3-flash` / `q3-flash-swap`):

```yaml
- id: q3-flash
  gguf: unsloth/Qwen3.8-Flash-Next-GGUF/Qwen3.8-Flash-Next-UD-Q3_K_XL-00001-of-00003.gguf
  mmproj: unsloth/Qwen3.8-Flash-Next-GGUF/mmproj-F16.gguf
  ctx: 100000        # user target
  port: 8095
  cpu_moe: true      # -> --n-cpu-moe 999 (all experts to CPU)
  ngl: 999           # all always-active layers to GPU
  kv: q8_0           # quantized KV for the attention cache
  parallel: 1
  vram_mib: 9000
```

Served from the machine registry as `q3-flash` / `q3-flash-swap` (see `../HOST-RUNBOOK.md`).

Equivalent raw command:

```bash
llama-server \
  -m /home/zerwiz/Models/unsloth/Qwen3.8-Flash-Next-GGUF/Qwen3.8-Flash-Next-UD-Q3_K_XL-00001-of-00003.gguf \
  --mmproj /home/zerwiz/Models/unsloth/Qwen3.8-Flash-Next-GGUF/mmproj-F16.gguf \
  -ngl 999 --flash-attn on \
  --cache-type-k q8_0 --cache-type-v q8_0 \
  -c 100000 -b 4096 -ub 4096 -t 16 --jinja --temp 0 --seed 42 \
  -np 1 --reasoning off --n-cpu-moe 999 \
  --port 8095
```

> **`-t 16` (not 8) is important here.** All 512 routed experts sit in system
> RAM (~14 GB, mmap'd) and every decode step reads them over the memory bus —
> that's CPU-bound, so use all 16 host cores. The registry field `threads: 16`
> is wired into both `model-host.sh` and the router generator. With `-t 8` the
> model is artificially decode-starved; `-t 16` lets it use every core.

---

## 4. Measured on zerwiz (2026-09-07)

| Metric | Value |
|---|---|
| Load time | ~20 s |
| GPU VRAM | **~14.2 GB** (fits 16 GB A5000) |
| System RAM | ~14 GB for model weights (mmap'd GGUF) |
| Context | 100,000 (attn cache ~2.5 GB, included in VRAM above) |
| Prefill | ~5–8 t/s |
| Decode | ~4.8 t/s |

Decode is slow because all routed experts live in RAM and are fetched per
token — expected for a 125B MoE on a 16 GB card. Usable for offline/agentic
work, not for interactive real-time.

---

## 5. Tuning knobs (if you want faster / different)

- **CPU threads `-t 16`** ✅ **APPLIED (2026-09-08)** — the biggest free win.
  All experts are on CPU, so 16 threads (vs 8) roughly doubles decode
  throughput (up to the RAM-bandwidth cap). Registry `threads: 16`; wired into
  `model-host.sh` + the router generator.
- **More GPU experts**: lower `--n-cpu-moe` from 999 to e.g. 40–60 layers of
  experts on GPU — but with only ~1.7 GB free VRAM above the current load,
  there's almost no headroom on 16 GB. Skip unless you shrink ctx.
- **Shorter context**: `-c 32768` frees ~1.7 GB → could offload a few expert
  layers to GPU for faster decode.
- **KV type**: `q4_0` shrinks the cache further than `q8_0`, freeing VRAM for
  expert offload (small quality cost at long context).
- **Batch**: keep `-b 4096 -ub 4096` for CPU+GPU prefill (Doctor Shotgun).
- **Think off**: `--reasoning off` (as above) unless you need CoT.

---

## 6. Memory checklist (before you bump ctx)

- Weight file: ~90 GB (mmap — counts against system RAM as touched pages).
- Attention cache @100K: ~2.5 GB.
- Free system RAM must cover the model pages + OS + anything else (zerwiz has
  ~74 GB available; fine).
- VRAM must fit always-active weights + KV + compute buffer (measured 14.2 GB).

---

## 7. Sources

- github.com/QwenLM/Qwen3.8-Flash-Next — model card
- arXiv:2608.30320 — Qwen3.8-Next architecture paper
- unsloth.ai/docs/models/qwen3.8-next — GGUF + run guidance
- atomic.chat/blog — GGUF/hardware guide (context cache math)
- Doctor Shotgun — "Performant local MoE CPU inference with GPU acceleration" (llama.cpp MoE offload)
- bmdpat.com / sergiiob.dev — `--n-gpu-layers` partial-offload guidance

## Related

- [`../llamaswap/how-llama-swap-works.md`](../llamaswap/how-llama-swap-works.md) — auto-swap proxy that serves this model
- [`../llamacpp/TESTING.md`](../llamacpp/TESTING.md) — the CUDA llama-server build
