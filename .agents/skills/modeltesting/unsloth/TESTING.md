# Unsloth Testing — GGUF host + training→export lane

Per-backend testing guide for **Unsloth**. Unsloth has two distinct roles in
this bench (from `../backends-benchmark.md` + the LLM-gateway architecture
plan):

1. **Model host** — `unsloth studio` runs a llama-server-backed,
   OpenAI-compatible endpoint (default `:8888`, binds `127.0.0.1`).
2. **Training → GGUF producer** — a LoRA/QLoRA `train` → `export` pipeline that
   turns trained weights into the very GGUFs the other backends serve.

This folder also owns the **chat-template/EOS caveat** that matters for every
backend.

- Date: 2026-09-04
- Machine: zerwiz (RTX A5000 **16 GB VRAM**, 122 GiB RAM)
- CLI: `~/.local/bin/unsloth` **v2026.8.19**
- GGUF catalog: `~/Models/unsloth/` (8 model families)
- Status: **installed + catalog verified; doc is the run/train/export test plan**

---

## 1. Why this folder matters to the bench

From the architecture plan and the benchmark:

- Unsloth's GGUF files are **standard llama.cpp / GGUF** — nothing slow about
  the format (§11). If they're slow, it's the *engine/config*, not the file.
- The self-hosted catalog **is the source of all four bench targets**
  (`Qwen3.5-9B`, `Qwen3.6-35B-A3B`, `Qwen3.8-27B`, `gemma-4-26B-A4B`) plus
  `DeepSeek-R1-0528-Qwen3-8B`, `GLM-4.7-Flash`, `Qwen3.5-4B`, `gemma-4-12b`.
- As a host it adds an OpenAI-compatible endpoint behind aizerwiz (like
  LM Studio / llama-server).
- As a **producer** it feeds the training→GGUF loop into the §10 bench and the
  §12.2 three-builds-per-model scheme.

---

## 2. Current state on this box

| Item | State |
|---|---|
| CLI | `~/.local/bin/unsloth`, **v2026.8.19** |
| Studio/locate | `unsloth studio run` (host), `train`, `inference`, `chat`, `export`, `studio` (web UI with `--api-only`, `--parallel`/`--n-parallel` 1–64) |
| Default host port | `:8888`, binds `127.0.0.1` |
| GGUF catalog | `~/Models/unsloth/` (8 families, listed above) |
| Backend | llama-server-backed |

---

## 3. Arch classes in the catalog (for the bench §10)

| Family on disk | Size/file | Arch class | Fit 16 GB |
|---|---|---|---|
| `Qwen3.5-4B-GGUF` | — | dense | yes |
| `Qwen3.5-9B-GGUF` | `Qwen3.5-9B-Q4_K_S.gguf` (+mmproj-F32) | dense | yes |
| `Qwen3.6-35B-A3B-GGUF` | `-UD-Q2_K_XL` / `-UD-Q4_K_S` / `iq3_s` | **MoE** | Q4 no; Q2/iq3 mostly |
| `Qwen3.8-27B-GGUF` | `Qwen3.8-27B-UD-Q3_K_XL.gguf` (+mmproj-F16) | hybrid-attn (dense-fit) | yes |
| `gemma-4-26B-A4B-it-GGUF` | `...-UD-Q5_K_XL.gguf` (+mmproj-F32) | **MoE** (A4B) | Q5 no; IQ4/IQ3 yes |
| `gemma-4-12b-it-GGUF` | — | dense | yes |
| `GLM-4.7-Flash-GGUF` | — | — | — |
| `DeepSeek-R1-0528-Qwen3-8B-GGUF` | — | — | — |

The four bench targets (§10 matrix) come from here — they're the exact files
llama.cpp/LM Studio/Ollama serve in the other folders.

---

## 4. Host test (model serving — OpenAI-compatible)

```bash
# lint the model host online (config, then run on :8888, 127.0.0.1)
unsloth studio run --model <family>            # single / default
unsloth studio run --api-only                  # headless, no web UI
# concurrency sweep (1 vs N slots — tests parallel decode on the A5000):
unsloth studio run --model <family> --parallel 1
unsloth studio run --model <family> --n-parallel 8
```

Bench the endpoint the same way as the other OpenAI-compatible backends
(§3 methodology): warmup, same seed, explicit context, capture GPU during
prefill, TTFT on a big prompt. This validates Unsloth as a host behind
aizerwiz if its bundled engine is competitive for the fast builds.

---

## 5. Training → GGUF export loop (the producer lane)

The unique value: train a LoRA/QLoRA, then export a GGUF the rest of the stack
serves.

```bash
# LoRA / QLoRA fine-tune on the 16 GB card
unsloth train --model <base> --dataset <data> --finetune lora|qlora ...

# verify inference with the SAME chat template + EOS used in training
unsloth inference --model <trained> ...

# export to GGUF (feed the other backends / the §10 bench)
unsloth export --model <trained> --format gguf --quant q4_k_s ... --outdir ~/Models/unsloth/<new>
```

### The chat-template / EOS caveat (critical)

`inference` must apply the **same chat template + EOS token used in training**.
When the exported GGUF is later loaded by Ollama / LM Studio, those engines can
**guess wrong** from GGUF metadata — producing wrong/garbage output. To test:

1. Train and infer with the training-time template/EOS.
2. After export, load the GGUF in each target backend and confirm it applies
   the correct template (or set it explicitly) — a cross-backend regression test.
3. The output bit-identity you expect comes from matching template, not just
   weights.

---

## 6. Interaction with the other folders

- **llamacpp/** — the exported GGUF is instructed here (`-m <file> --jinja`).
- **lmstudio/**, **ollama/** — load the same exported file/tag and confirm the
  chat template isn't guessed wrongly (§5 caveat).
- The exported GGUF feeds the §10.5 rows and the §12.2 three-builds-per-model
  scheme (CPU-big / mid / fast via `--n-gpu-layers` / `--n-cpu-moe` /
  `--ctx-size` from the **same** file).

---

## 7. What to record / outcomes

> **After every accepted test, always update `~/.pi/agent/models.json`:**
> set the model's `contextWindow` to the verified value and reflect the
> processor/VRAM findings, so pi's registry is never stale (§ shared rule 8).

- Host: gen t/s, prefill t/s, TTFT, VRAM, GPU% at a few `--parallel` values.
- Producer: fine on a dataset → export → host in llama.cpp/Ollama/LM Studio;
  verify template/EOS correctness across all targets.
- Decision: keep Unsloth as a **host** too, or use it purely as the
  training→GGUF producer while llama.cpp router mode serves? (Production plan:
  Unsloth is primarily the producer; llama.cpp/LiteLLM serve.)

---

## Related

- [`../backends-benchmark.md`](../backends-benchmark.md) — §11 (GGUF slow ≠ format slow), §10 matrix (which catalog files are the bench targets), §12.2 (one GGUF → three builds)
- `~/Models/unsloth/` — the GGUF catalog
- `~/.local/bin/unsloth` — CLI v2026.8.19 (`studio run`, `train`, `inference`, `chat`, `export`)