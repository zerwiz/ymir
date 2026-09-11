# Qwen3.6-35B-A3B MoE offload — research findings (web, 2026-09-05)

**Source:** web research (llmkube blog, openclawdc blog, Aliteq guide, GitHub
`ggml-org/llama.cpp` `src/models/qwen35moe.cpp`, HF Unsloth/AesSedai discussion,
agentnativedev Medium, AlexChen31337/qwen35-moe-offload PLAN) + this box's
measurements (`llamacpp/TESTING.md` §8). Pairs with
[`qwen36-35b-moe-coding-context.md`](./qwen36-35b-moe-coding-context.md) (which
covers pure-GPU / full offload) — this one is the **tuning guide for partial
expert offload on 16 GB VRAM**.

> **TL;DR:** `--cpu-moe` / `--n-cpu-moe 999` (ALL experts → CPU) is a
> **5× decode-speed trap** on this model — community measured **21.7 t/s with it
> vs 107.8 t/s without** on identical dual-16 GB hardware. It's only worth it
> when the model genuinely does NOT fit in VRAM. The right tool is **`--n-cpu-moe
> N` (partial offload)**: keep ALL attention + DeltaNet "thinking" on GPU, move
> only N layers' expert weights to RAM, tuned by sweep. Plus the two mandatory
> flags for this architecture: `--parallel 1` and `--flash-attn on`.

---

## 1. Why `--cpu-moe` is the 5× trap (community, llmkube — dual RTX 5060 Ti)

| Config | Generation (single-request) | Note |
|---|---|---|
| Qwen3.6-35B-A3B **with** `--cpu-moe` | **21.7 t/s** | experts in RAM, CPU does 40×9 ≈ 360 expert matmuls/token |
| Qwen3.6-35B-A3B **without** `--cpu-moe` | **107.8 t/s** | experts on GPU |

The mechanism: at decode time llama.cpp does **not** move expert weights over
PCIe per token. Instead the small activation vector travels VRAM → DRAM, the CPU
performs the expert matmul with weights already resident in DRAM, and the result
returns to VRAM. GPU still handles attention and everything non-expert. So the
flag buys VRAM by **paying CPU compute per token** — great when the alternative
is not fitting at all, pure overhead when it fits.

**The decision rule (from llmkube):** `--cpu-moe` is a *memory-pressure valve,
not a throughput feature*. Check whether model + context actually overflows VRAM
FIRST. For Qwen3.6-35B-A3B the answer is often "no" even on 16 GB, because its
hybrid DeltaNet architecture keeps the KV cache tiny.

Counterexample that proves the rule: Qwen3-Coder-30B-A3B (classic GQA, 48 full
attention layers, KV grows every layer) **does** overflow 2×16 GB at 90K ctx, so
`--cpu-moe` there is the correct, necessary choice (31 t/s).

## 2. What the model actually is (from `qwen35moe.cpp`, verified)

- **40 layers** in a repeating pattern: `10 × [ 3×(DeltaNet→MoE) + 1×(Gated Attention→MoE) ]`
  = **30 Gated DeltaNet layers + 10 Gated Attention layers**, each followed by
  an MoE FFN with **256 experts**, 9 active per token (8 routed + 1 shared),
  intermediate dim **512** per expert.
- **Only the 10 Gated Attention layers contribute to the KV cache.** DeltaNet
  maintains a compact recurrent state. At 90K ctx with `q8_0` cache, KV
  footprint is modest — that's why this model family fits where others don't.
- **MTP/NextN** extra decoder blocks exist in the GGUF but are not executed in
  the main pass (they're for the speculative head).

## 3. The flag that implements "thinking on GPU, experts on CPU": `--n-cpu-moe N`

```
--n-cpu-moe N   keep the MoE (expert) weights of the first N layers in CPU
                (env: LLAMA_ARG_N_CPU_MOE)
--cpu-moe       ALL experts to CPU (same as --n-cpu-moe <n_layer>)
-ngl 999        keep ALL layers on GPU (attention stays — DO NOT lower this)
```

- **Keep `-ngl` maxed** (`-ngl 999` / `-ngl all`). Lowering `-ngl` pushes whole
  *layers* (attention included) to CPU — the expensive part. With
  `--n-cpu-moe` available, control memory with the MoE flag, not `-ngl`. You
  want attention on the GPU for **every** layer.
- **Sweep `--n-cpu-moe`**, don't copy. The correct value depends on your quant,
  RAM speed, and (crucially) context size. Method: start at a value that
  definitely fits, step DOWN (more experts→GPU), measuring t/s at each stop.
  Speed climbs as N drops, then **falls off a cliff** — a silent VRAM spill
  where allocation quietly falls to system memory and everything slogs (often no
  error, just 2–3× slower). Back off one step above the cliff.
- **Worked community numbers** (16 GB class card, Qwen3.6-35B/A3B): a 5090
  owner swept 20→16→12→(cliff below): 54 / 64.5 / 69.4 t/s then collapse to
  27.5. RX 9060 XT 16 GB owner forces 24 layers to CPU. Neighborhood to start
  sweeping on our A5000: **`--n-cpu-moe 20`–`24`**, step down to find the edge.
- **Our q5 (Q5_K_M, 24.6 GB, 120K) observed at N=999:** 5,462 MiB VRAM,
  ~25.8 GB RAM, prefill 526 t/s, **decode 20.3 t/s** — squarely in the
  collocated slow regime. Expect the partial-offload sweep to lift decode
  several-fold.

## 4. Two MANDATORY flags for this architecture (verified, GitHub DISCOVERY.md)

### `--parallel 1` — a separate 10× slowdown, independent of offload

The default `n_parallel=auto` picks **4 slots**. Each slot allocates its own
Gated DeltaNet **recurrent-state (RS) buffer**, which scales with
`n_parallel`. 4 slots = 251 MB; `--parallel 1` = 62 MB. The larger RS updates
become the bottleneck → **~10× slower regardless of context or offload**.

| `--parallel` | RS buffer | Speed |
|---|---|---|
| 1 (set this) | 62 MB | ~125 t/s (after warmup) |
| 4 (auto default) | 251 MB | ~9 t/s |

> ⚠️ Our `model-host.sh` already uses `-np 1` — keep it. Do NOT "fix" parallel
> slots and assume both fixes are covered; they are separate bottlenecks.

### The 155,904 context cliff (CUDA_Host compute buffer)

There's a hard cliff at **155,904 tokens** for hybrid recurrent MoE on 16 GB
cards: below it ~125 t/s, above it ~9 t/s. Root cause is a `CUDA_Host` buffer
alignment boundary (~313 MB) that saturates PCIe for the recurrent-state
transfers. Not OOM — VRAM fits at 192K (15.5 GB < 16.3 GB). Only affects
contexts ≥ 155,904. Our target 120K stays **safely below** it.

## 5. KV cache type: `q8_0` is a memory feature, not a speed feature

Community consensus (openclawdc): **f16 KV is FASTER than q8_0 when it fits** —
quantizing the cache adds conversion work every token. Quantized KV is for when
f16 doesn't fit and the alternative is a shorter window or a spill. Our host
currently forces `--cache-type-k/v q8_0`; on this model with its tiny KV that
may be leaving speed on the table — **worth an A/B once offload N is fixed.**

---

## 9. Actual launch settings used by our test host (`model-host.sh`)

The `model-host.sh` launcher (data-driven from `llama-models.yaml`) constructs
the command line for our runs. For Qwen3.6-35B-A3B quants on the qwen35 swap
group (`:8125`), the current launch template is:

```bash
# From model-host.sh line ~120 (for q5: cpu_moe=true, ctx=120000, port=8125):
/home/zerwiz/llama.cpp/build/bin/llama-server \
  -m /home/zerwiz/Models/unsloth/Qwen3.6-35B-A3B-GGUF/Qwen3.6-35B-A3B-UD-Q5_K_M.gguf \
  -ngl 999 \
  --flash-attn on \
  --cache-type-k q8_0 --cache-type-v q8_0 \
  -c 120064 -b 4096 -ub 4096 -t 8 --jinja --temp 0 --seed 42 \
  -np 1 --reasoning off \
  --port 8125 \
  --n-cpu-moe 999   # <-- the ONLY knob that changes per sweep step
```

**Current test settings (q5, 120K ctx, slow regime):**

| Flag | Value | Source |
|---|---|---|
| `-ngl` | `999` (all layers GPU) | hardcoded |
| `--flash-attn` | `on` | hardcoded |
| `--cache-type-k/v` | `q8_0` | hardcoded |
| `-c` (ctx) | `120064` (from YAML `ctx: 120000` + auto-align) | registry |
| `-b` / `-ub` | `4096` / `4096` | hardcoded |
| `-t` (threads) | `8` | hardcoded |
| `--jinja` | `on` | hardcoded |
| `--temp` / `--seed` | `0` / `42` | benchmark discipline |
| `-np` (parallel) | `1` | **mandatory**, prevents 10× RS slowdown |
| `--reasoning` | `off` | hardcoded |
| `--n-cpu-moe` | `999` (ALL experts CPU) | registry `cpu_moe: true` → `999` |

**What changes for the sweep (next bench):**

| Parameter | Current (N=999) | Sweep values (next run) |
|---|---|---|
| `--n-cpu-moe` | `999` (all) | **24, 20, 16, 12** |
| `--cache-type-k/v` | `q8_0` | A/B test `f16` once N is fixed |

The registry YAML entry for q5 (`llama-models.yaml`):
```yaml
  - id: q5
    label: Qwen3.6 35B Q5_K_M
    gguf: unsloth/Qwen3.6-35B-A3B-GGUF/Qwen3.6-35B-A3B-UD-Q5_K_M.gguf
    ctx: 120000
    port: 8125
    group: qwen35
    vram_mib: 5000
    cpu_moe: true     # currently boolean → 999; will become numeric N for sweep
    note: experts on CPU, 120K ctx
```

**To run the sweep:** change `cpu_moe: true` → `cpu_moe: 24` (etc.) in the YAML,
restart via `model-host.sh start q5`, benchmark, record.

**Dual-role IQ3_S (`q3` orchestrator, verified 2026-09-05):** the same IQ3_S GGUF
is registered twice in `llama-models.yaml` for two jobs:

| id | port | group | `cpu_moe` | role |
|---|---|---|---|---|
| `iq3` | 8125 | qwen35 (swap) | false (pure GPU) | single-use quant, max speed |
| `q3` | 8093 | — (own port) | true (→999, all CPU) | **orchestrator** — runs in PARALLEL with 9b workers |

Orchestrator measured: 4,682 MiB VRAM + ~9 GB RAM, prefill 885 t/s, decode
26 t/s. Two-model test (q3 :8093 + 9b :8081) = 15,645 MiB total, both healthy —
this is the factory layout (big orchestrator + several 9b GPU workers on
parallel ports).

## 6. The "expert-only offload" option: `-ot "exps=CPU"` (advanced)

Newer llama.cpp supports textbook-graph placement: `-ot "exps=CPU"` keeps
attention, norms, and **shared** experts on the GPU while routing only the
routed-expert FFN weights to RAM — the same idea as `--n-cpu-moe` but at tensor
granularity, and the way people run 100B+ MoE with `-ts` split across multi-GPU
plus RAM. On a single 16 GB card the simpler `--n-cpu-moe` sweep is the
right-first move.

## 7. Recommended next bench on zerwiz (q5, Q5_K_M, 120K) — DONE 2026-09-05

Increment on the Q5 120K row already in `TESTING.md` §8 (N=999: 5,462 MiB VRAM /
20.3 decode):

1. Launch q5 with `-ngl 999 --parallel 1 --flash-attn on` +
   **`--n-cpu-moe 24`** (start safe). ✓
2. Sweep **24 → 20 → 16 → 12**, `llama-perplexity`-style identical prompt,
   record decode t/s + VRAM at each step. ✓ (22 → 24 → 20 tested)
3. At the step where decode collapses (silent spill), back off one. ✓ (N=20 OOM)
4. Re-check prep warnings: JIT warmup invalidates early runs (see DISCOVERY.md —
   measure after warmup, `--parallel 1` needed for full speed anyway). ✓

**Measured sweep (Q5_K_M, 120,000 ctx, KV q8_0, `-np 1`, temp 0 seed 42):**

| `--n-cpu-moe` | VRAM GPU | Prefill t/s | Decode t/s | Status |
|---|---|---|---|---|
| 999 (all CPU) | 5,462 MiB | 526 | 20.3 | slow regime (baseline) |
| 24 | 14,642 MiB | — | 29.7 | fits, ~1.4 GB headroom |
| **22** | **15,767 MiB** | **628** | **30.4** | **BEST — max GPU offload at 120K** |
| 20 | OOM | — | — | KV / compute-pp buffer alloc fails |

**Verdict: `--n-cpu-moe 22` is the optimum** for Q5_K_M @ 120K on 16 GB VRAM —
decode +50% (20.3→30.4 t/s), prefill +19% (526→628 t/s) vs full offload, at the
price of ~10 GB more VRAM (15.8 GB, only ~600 MiB headroom). N=20 is the cliff
(silent spill would follow if it loaded). Registry updated:
`llama-models.yaml` q5 → `cpu_moe: 22`.

## 8. Sources

- llmkube — *Why Qwen 3.6 Doesn't Need --cpu-moe (and Why Qwen3-Coder Does)*, 2026-04-18
- openclawdc — *llama.cpp MoE Offload Flags Explained*, 2026-07-29
- Aliteq / Lena Fischer — *llama.cpp --n-cpu-moe: Run a Big MoE Model on a Small GPU*, 2026-07-27
- `ggml-org/llama.cpp` `src/models/qwen35moe.cpp` — layer layout, `is_recr()`,
  MTP head (verified directly in the repo, HEAD `6703d78` clone at `~/llama.cpp`)
- YashwanthMY15 `Qwen-3.5-16G-Vram-Local` `DISCOVERY.md` — `--parallel` + 155,904 cliff
- agentnativedev Medium — Qwen 3.5 35B-A3B optimized config
- HF `AesSedai/Qwen3.5-35B-A3B-GGUF` discussions (#6) — `--n-cpu-moe` CPU-RAM
  OOM reports on updated quants; `--fuse-gate-up-exp` (PR #19139) improves
  prefill/VRAM on fused gate-up-exps graphs
- zerwiz `llamacpp/TESTING.md` §8 + §9 — this box's measured rows

---

## 9. Cross-validation — Qwen3.8-Flash-Next (2026-09-07)

The same expert-offload technique was applied to **Qwen3.8-Flash-Next**
(125B MoE, 6B active, 512 experts, 48 layers, ~90 GB GGUF) on this 16 GB box.
`cpu_moe:false, ngl:999` → OOM (needs ~58 GB VRAM). Setting
**`cpu_moe:true` → `--n-cpu-moe 999`** (all 512 routed experts to CPU) with
`ngl:999` (always-active layers + KV on GPU) loaded it in ~20 s at **100K ctx,
~14.2 GB VRAM**.

| Metric | Value |
|---|---|
| Load | ~20 s |
| VRAM (100K ctx) | ~14.2 GB |
| Prefill / Decode | ~5–8 / ~4.8 t/s |

Flash-Next's hybrid attention makes its KV cache cheap (~25 KB/token → ~2.5 GB
@100K), so the always-active GPU path is light; the bottleneck is the CPU-bound
routed experts. Full settings: [`../models/qwen3.8-flash-next-settings.md`](../models/qwen3.8-flash-next-settings.md).