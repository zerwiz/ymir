# Colibri Testing — disk-streamed MoE (a different mechanism)

Per-backend testing guide for **Colibri** (`JustVugg/colibri`, Apache-2.0).
Unlike the other backends, Colibri does **not** swap which model is resident —
it **streams MoE experts from disk on demand**, so a model that couldn't fit in
fast memory still runs, treating VRAM/RAM/NVMe as one placement hierarchy.
Numbered sections map to [`../backends-benchmark.md`](../backends-benchmark.md)
(§12.6).

- Date: 2026-09-04
- Machine: zerwiz (RTX A5000 **16 GB VRAM**, 122 GiB RAM)
- Clone: `/home/zerwiz/colebri/colibri/` (with `c/` engine, `Makefile`, PyPI `colibri`)
- Engine: pure C, zero runtime deps (needs only `gcc`/`clang` + OpenMP)
- Status: **candidate CPU-big / long-context alternative; docs the build + test path**

---

## 1. Why this folder matters to the bench

From §12.6 — this is a genuine **CPU-big alternative** for the MoE families
(esp. `Qwen3.6-35B-A3B`), turning the "does 16 GB VRAM hold it?" question into
a "how fast is disk streaming" question:

- A 744B-class MoE activates ~40B params/token; only ~11 GB of routed experts
  change per token. Dense part stays resident; routed experts streamed in with
  per-layer LRU + learned pinned hot-store + one-layer-ahead prefetch (`PILOT`).
- **Placement decides speed, never semantics** — output is bit-identical CPU vs
  CUDA (verified).
- **Speed reality:** decode is *disk/bandwidth-bound*, not VRAM-bound. A few
  tok/s warm on fast NVMe, fraction of a tok/s cold.
- It is **not** a competitor to llama.cpp router mode for the fast/mid builds —
  a throughput trade-off, not a speed play on this box. Lower priority than
  building/benching the CUDA llama.cpp router mode, but worth a slot if a very
  long-context CPU-resident mode wins out.

---

## 2. Why Qwen3.6-35B-A3B (our target) matters here

One of our four targets has a **dedicated Colibri engine** (§12.6):

- Family supported as its own engine: `make -C c qwen36` (`CUDA=1` for the VRAM
  expert tier).
- Needs ~20 GB int4-gs64 container, **24 GB full RAM residency** (not a
  disk-streamed "small box" case — qwen36 needs full residency).
- Optional CUDA VRAM expert tier measured **1.44 → 10.05 tok/s (7.0×)** on two
  8 GB cards, output bit-identical to CPU.
- This sidesteps the "fits in 16 GB VRAM?" question via streaming + CPU.

---

## 3. Build the engine (per repo README / §12.6)

```bash
cd /home/zerwiz/colebri/colibri
make -C c qwen36            # base engine (CPU / full-RAM residency)
# optional VRAM expert tier:
make -C c qwen36 CUDA=1
```

Build needs only `gcc`/`clang` + OpenMP; zero runtime deps. Verify the binary:

```bash
./c/coli --help          # exact binary name per repo build
```

---

## 4. Front-ends (OpenAI-compatible gateway)

Colibri ships `coli chat` / `coli serve` / `coli web` — `serve`/`web` provide an
OpenAI-compatible HTTP gateway + dashboard, so it can sit behind aizerwiz like
LM Studio / llama-server (§12.6).

- `coli serve` — headless OpenAI-compatible endpoint
- `coli web` — gateway + dashboard
- `coli chat` — interactive

---

## 5. Benchmark approach for Colibri (per §12.6 + §3)

Colibri's decisive metrics differ from the standard bench:

- **Decode tok/s** — the headline number; expect a **few tok/s warm** on fast
  NVMe, not llama.cpp GPU-class numbers. It's a CPU-big play, not a speed play.
- **Disk bandwidth** — this is the binding resource. Dual-SSD mirror
  (`COLI_MODEL_MIRROR`) sums read bandwidth and is often the biggest single win
  on a real box (§12.6).
- **Warm vs cold** — a freshly-idle model streams cold (fraction of a tok/s);
  warmed layers are faster. Test both states.
- Confirm target is resident-compatible: qwen36 needs **24 GB full RAM
  residency** — verify this box's 122 GiB has it free and record RAM used.
- Compare the **VRAM expert tier** (`CUDA=1`) tok/s vs CPU on the same target.
- Guard: Colibri's speed has **no SLA** — correctness is guaranteed
  (token-exact) but speed is entirely hardware-bound.

Still apply the parent's cross-backend hygiene where relevant (§3): unload
before/after (no competing VRAM/RAM), capture GPU/RAM during run, same seed,
warmup.

---

## 6. What to record / outcomes

> **After every accepted test, always update `~/.pi/agent/models.json`:**
> set the model's `contextWindow` to the verified value and reflect the
> processor/VRAM findings, so pi's registry is never stale (§ shared rule 8).

- **Decision input for §12.6:** does streamed decode give a usable CPU-big /
  long-context alternative for `qwen3.6-35b-a3b` (or GLM-5.2/etc.) on this box,
  or is 0.05-Hz-cold / few-Hz-warm too slow to justify vs llama.cpp CPU spill?
- Record: warm & cold decode t/s, RAM used, disk read bandwidth
  (with/without `COLI_MODEL_MIRROR`), VRAM-tier vs CPU tok/s, TTFT.
- Keep it **lower priority** than the CUDA llama.cpp router mode build + bench
  (§12.6) — this folder is the fallback lane.

---

## 7. Caveats / cost

- Converts to its own **int4 container** (one-time, Python converter).
- Correctness hard-guaranteed vs a transformers oracle; speed very hardware-bound.
- A GPU only makes it faster — it **never changes output**.

---

## Related

- [`../backends-benchmark.md`](../backends-benchmark.md) — §12.6 Colibri deep-dive (idea, speed reality, qwen36 engine, CUDA tier, `COLI_MODEL_MIRROR`, caveats)
- `/home/zerwiz/colebri/colibri/` — the clone (`c/` engine + `Makefile`, `GPU_BACKENDS.md`)