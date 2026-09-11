# TabbyAPI / YALS Testing — fast ExLlama server + its GGUF twin (secondary)

Per-backend testing guide for **TabbyAPI** (theroyallab) and **YALS** (its GGUF
twin). Both are **secondary** model-switching services (§12.5.1). Neither is
installed on this box.

- Date: 2026-09-04
- Machine: zerwiz (RTX A5000 **16 GB VRAM**, 122 GiB RAM)
- Status: **blocked on GGUF today; only becomes relevant if weights go non-GGUF (TabbyAPI) or if router-mode scripting loses (YALS)**

---

## 1. What they are (§12.5.1)

| | TabbyAPI | YALS |
|---|---|---|
| Engine | **ExLlamaV2/V3** | llama.cpp (GGUF twin of TabbyAPI) |
| Formats | **EXL2/EXL3 only — NO GGUF** | **GGUF** ✅ |
| On-demand swap | `POST /v1/model/load` / `.../unload` (admin key); switch by setting `model` on any completions call | same API surface on llama.cpp |
| Concurrency | asyncio, paged attention, tensor parallel | llama-server-based |
| Speed | **EXL2/3 beats llama.cpp 30–60%** same quant on RTX 4090-class | llama.cpp-class |
| Key split | admin/API key split | — |

**Key fact:** TabbyAPI is **very fast** on consumer GPUs — but **ExLlama can't
read GGUFs**, and all our four bench targets are GGUFs. Hence it's **blocked for
us today**. YALS is the GGUF-capable twin with the same API + TTL scripting.

## 2. Why each matters (or doesn't)

- **TabbyAPI — blocked by format.** Only becomes a candidate if the bench forces
  us to abandon GGUF (or we acquire EXL2 epsilon-weights of a target). Its speed
  is the peak, but the format wall is decisive now.
- **YALS — a real (secondary) candidate.** If llama.cpp router-mode scripting
  (TTL / idle-unload automation) proves weaker than YALS's same-surface
  `load`/`unload` + idle-unload, YALS could take the serving slot — it reads
  GGUF and holds the fast llama.cpp-class speed.

## 3. When to test (gating)

Follow the §12.5 ranking: **native llama.cpp router mode → LM Studio JIT →
Ollama → llama-swap** first. YALS only enters as a *replacement* candidate if:

- llama.cpp router mode's config/API proves too unstable or its swap too slow
  vs a dedicated `load`/`unload` HTTP surface, **and**
- we prefer a llama.cpp-class engine over LM Studio's bundled (~ slower) one.

TabbyAPI only enters if we move off GGUF.

## 4. Proposed test (YALS — if triggered)

```bash
# 1. install YALS (GGUF twin), point it at the CUDA llama.cpp build + §10 GGUFs
#    (same files as llamacpp/ TESTING.md)
# 2. drive load/unload via the admin key:
curl -X POST http://127.0.0.1:<port>/v1/model/load   -H "Authorization: Bearer $ADMIN_KEY" -d '{"model": "qwen3.5-9b"}'
curl -X POST http://127.0.0.1:<port>/v1/model/unload -H "Authorization: Bearer $ADMIN_KEY" -d '{"model": "qwen3.5-9b"}'
# 3. benchmark through it (model set on the completions call) with §3 methodology.
```

Validate on-demand swap via the API surface, idle-unload/VRAM release, and the
§10.5 metrics.

## 5. Decision gate

> **After every accepted test, always update `~/.pi/agent/models.json`:**
> set the model's `contextWindow` to the verified value and reflect the
> processor/VRAM findings, so pi's registry is never stale (§ shared rule 8).

- **Today: NOT a build target.** GGUF format wall (TabbyAPI) + secondary status
  (YALS).
- Re-open TabbyAPI only on a GGUF-abandon decision; re-open YALS only if router
  mode's scripting/unload surface is a concrete blocker.

---

## Related

- [`../backends-benchmark.md`](../backends-benchmark.md) — §12.5.1 TabbyAPI/YALS rows + the GGUF-vs-EXL2/3 axis + ranking
- [`../llamacpp/TESTING.md`](../llamacpp/TESTING.md) — the CUDA `llama-server` build + GGUF files YALS would reuse