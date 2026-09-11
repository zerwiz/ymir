# vLLM Testing — production serving framework (secondary / not-fit)

Per-backend testing guide for **vLLM**. It is a **secondary** model-serving
service researched in §12.5.1. It is **not installed** on this box and, for our
GGUF + single-user 16 GB case, is largely **not a fit**. This folder documents
*why not* and the narrow cases where it *would* matter, so the decision is
recorded rather than rediscovered.

- Date: 2026-09-04
- Machine: zerwiz (RTX A5000 **16 GB VRAM**, 122 GiB RAM)
- Status: **documented as out-of-scope for this box today; re-evaluate only if we abandon GGUF**

---

## 1. What vLLM is (§12.5.1)

| Aspect | Value |
|---|---|
| Engine / quant | **fp8/bfloat16, HuggingFace checkpoints — NOT GGUF** |
| On-demand swap | `/v1/chat/completions` per model; instant load/unload during serving; `--cpu-offload-gb` adds CPU as swap |
| Concurrency | PagedAttention + continuous batching, 100s of concurrent |
| Multi-model | space-shares what fits in VRAM (co-resident, not weight-swap) |

## 2. Why it's out-of-scope for the aizerwiz/pi case (§12.5.1)

1. **GGUF mismatch** — vLLM reads HF fp8/bf16 checkpoints, **not GGUFs**. Our
   four bench targets are GGUFs on disk.
2. **Footprint** — FP16 weights + big VRAM (a 70B ≈ 140 GB FP16), against a
   16 GB single-user.box. `--cpu-offload-gb` uses CPU as swap, but that's a
   *different* mechanism from our full-CPU mode.
3. **Long load times** — large weights load slowly.
4. **Right tool** — when *hundreds* share one endpoint on a big GPU box, not a
   single user behind aizerwiz.

So vLLM falls on the **FP16/fp8-HF + co-resident** axis — the opposite corner
of our GGUF + weight-swap lane (§12.5.1 summary).

## 3. When it WOULD matter (the re-open trigger)

- Only if the bench's speed results **force abandoning GGUF** for the trained /
  served weights (e.g. a non-GGUF-able model), at which point vLLM (or SGLang)
  becomes a real candidate and this folder is promoted from documentation to a
  build+bench target.
- Not before. The parent doc's summary: "the non-GGUF engines (vLLM/SGLang/
  TabbyAPI) are real but only matter if we abandon GGUF — a decision the bench's
  speed results would have to force."

## 4. If the trigger fires (future path)

```bash
# only relevant after the GGUF-abandon decision:
pip install vllm
vllm serve <hf-model> --max-model-len 100000 --gpu-memory-utilization 0.9 \
  --cpu-offload-gb ...        # augment VRAM with CPU swap
```

Bench through it with the §3 methodology; note PagedAttention's benefit is
high-concurrency, irrelevant for single-user pi.

## 5. Decision recorded

> **After every accepted test, always update `~/.pi/agent/models.json`:**
> set the model's `contextWindow` to the verified value and reflect the
> processor/VRAM findings, so pi's registry is never stale (§ shared rule 8).

- **2026-09-04: OUT OF SCOPE** — GGUF mismatch + footprint + single-user case.
  Re-evaluate only on a GGUF-abandon decision or a multi-user hosting need
  (e.g. if aizerwiz scales to many concurrent WayOfTeams users on a bigger box).

---

## Related

- [`../backends-benchmark.md`](../backends-benchmark.md) — §12.5.1 vLLM row + the two-axis GGUF-vs-FP16 / weight-swap-vs-co-resident summary