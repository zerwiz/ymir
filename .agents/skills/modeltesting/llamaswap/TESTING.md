# llama-swap Testing — external per-model orchestrator (secondary)

Per-backend testing guide for **llama-swap** — an external Go orchestrator that
sits in front of `llama-server` / vLLM etc. It is a **secondary** model-switching
service (§12.5), best when per-model process isolation is wanted. It is
**not installed/built** on this box.

- Date: 2026-09-04
- Machine: zerwiz (RTX A5000 **16 GB VRAM**, 122 GiB RAM)
- Status: **research/scenario only — pick up only if llama.cpp router mode proves insufficient**

---

## 1. What llama-swap is (§12.5)

| Aspect | Value |
|---|---|
| Type | external orchestrator (Go) |
| On-demand swap | per-request ✅ |
| Multi-model | spawns a `llama-server` **per** model ✅ |
| In-memory eviction | idle unload after timeout |
| Engine | sits in front of llama-server / vLLM / others; **GGUF**-capable via llama-server |

It watches the `model` field on each request, starts the right backend process,
routes to it, and unloads it when idle.

**vs native router mode (§12.5):** llama.cpp router mode does the same residency
management inside one server (no extra process); llama-swap adds an external
moving part but gives **per-model process isolation**. Best when isolation is
the priority.

---

## 2. When to test this (secondary)

The backend ranking to validate in the bench (§12.5) is:

1. **native llama.cpp router mode** ← preferred
2. LM Studio (JIT + Auto-Evict)
3. Ollama
4. **llama-swap** (for per-model isolation)

So the gating question: does llama.cpp router mode's one-resident-per-worker
model + 3–10 s swap meet the requirement? If **yes**, llama-swap stays unneeded.
It only becomes the test target if router mode's concurrency/isolation model is
a blocker.

---

## 3. Proposed test (if triggered)

```bash
# 1. install llama-swap (Go binary) and configure a per-model config
#    mapping the §10 GGUF files to per-model llama-server launch args
# 2. start llama-swap in front of the llama-server build (same CUDA build as llamacpp/)
# 3. run the §3 benchmark through it with explicit model field + num_ctx
# 4. confirm idle-unload after the configured timeout, then VRAM is freed
```

Validate: on-demand swap, per-model isolation, idle unload (VRAM released), and
the same §10.5 metrics (gen t/s, prefill t/s, TTFT, VRAM, GPU%).

---

## 4. Decision gate

> **After every accepted test, always update `~/.pi/agent/models.json`:**
> set the model's `contextWindow` to the verified value and reflect the
> processor/VRAM findings, so pi's registry is never stale (§ shared rule 8).

- Keep it on the shelf unless router mode's isolation model fails.
- If adopted, it replaces the router-mode INI by managing each `llama-server`
  process itself, reusing the same CUDA build and GGUF files from the
  **llamacpp/** testing.

---

## Related

- [`../backends-benchmark.md`](../backends-benchmark.md) — §12.5 model-switching services table (llama-swap row + ranking), §12.4 build flags for the llama-server it would orchestrate
- [`../llamacpp/TESTING.md`](../llamacpp/TESTING.md) — the CUDA `llama-server` build + engine it wraps