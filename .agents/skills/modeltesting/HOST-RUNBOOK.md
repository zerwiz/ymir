# HOST-RUNBOOK — how this host is set up for TESTING models

What a tester must know about this computer for a measurement to be *real*, and
how to tell a good run from a bogus one. It is deliberately **not** a guide to
running the model service: the service is machine property, its own manuals live
with it, and this skill never starts it.

> **This skill tests. It does not run the service.**
> `bench-one.sh` starts its own throwaway single-model `llama-server` on a
> scratch port, measures it, and kills it. The machine's serving stack
> (`llama-router`, `model-host`, `swap-proxy`) is never invoked from here.

Last verified end-to-end: **2026-09-12**.

---

## 1. What this host is

| | |
|---|---|
| GPU | **NVIDIA GeForce RTX 3080 Laptop GPU, 16384 MiB**, driver 610.57.04 |
| Idle GPU clock | **210 MHz** — it boosts lazily, and that ruins naive timing (§4) |
| Models on disk | `/home/zerwizomar/.lmstudio/models` (LM Studio's `downloadsFolder`) |
| CUDA runtime | shipped by LM Studio, **not** by the distro (§2) |

## 2. Prerequisite: a CUDA-capable server, or your numbers are fiction

The distro's `/usr/bin/llama-server` on this box is a **CPU-only** build. It does
not fail — it loads a model happily and runs roughly 10× slow, which produces a
believable, useless table:

```bash
/usr/bin/llama-server --list-devices     # -> Available devices: (none)
llama-server-cuda --list-devices         # -> CUDA0: NVIDIA GeForce RTX 3080 Laptop GPU (15981 MiB, ...)
```

`bench-one.sh` refuses to run against a server with no CUDA device, for exactly
this reason. The CUDA build itself is LM Studio's, plus the CUDA12 runtime it
needs — wired by the machine's `llama-server-cuda` shim, which lives with the
service (see §7).

## 3. How to run a bench here

```bash
.agents/skills/modeltesting/scripts/bench-one.sh <model-id> [prompt.json] [max-tokens]
.agents/skills/modeltesting/scripts/stop-all.sh      # clean the GPU, report the baseline
.agents/skills/modeltesting/scripts/gpu-sample.sh 2 10 -- <cmd>   # catch CPU spill
```

`<model-id>` is an id in the machine's registry (`llama-models list`). The
registry is read **read-only** — it is how the bench learns a model's `gguf`,
`ctx`, `ngl`, `kv`, `cpu_moe`, and `threads`, so the measurement matches what the
service would actually serve, without the bench touching the service.

## 4. The clock-ramp trap (this cost a bogus published number)

The first timed run of the 27B read prefill 28.2 / decode 8.2 t/s with
`nvidia-smi` showing **0 % util**. The same model, warmed: **92-95 % util, 114 W,
1755 MHz**, decode **21.1 t/s**. This GPU sits at 210 MHz idle and boosts lazily;
a request fired straight after loading measures the clock ramp, not the model.

`bench-one.sh` therefore issues a throwaway request to warm the GPU *before* the
timed run, and reports peak util and power so a cold run is visible rather than
believed.

Two more rules this came from:

- **Never quote prefill t/s from a ~30-token prompt.** That is fixed overhead,
  not throughput. Use a multi-thousand-token prompt.
- **`cache_n` must be 0** for a true cold prefill — a fresh prompt, not a prefix
  the server already has.

### 4.1 Context length dominates decode speed — measured here

Same model, same server, same power state (AC online, 115 W limit); only the
prompt length changed:

| Run | prompt_tok | prefill t/s | decode t/s | peak util | peak W |
|---|---|---|---|---|---|
| short context | 19 | 64.7 | **21.2** | 9% | 53.4 |
| long context | 7,940 | 14.5 | **4.6** | 100% | 112.7 |

Decode falls **4.6x**, prefill **4.5x**, and the slow run drew **more** power —
so this is KV-cache traffic, not a power or thermal cap.

Two consequences for the record:

- A "decode t/s" figure taken with a tiny prompt is an **upper bound**, not the
  speed you will see in a real long-context session. Always state the context
  the number was measured at.
- Decode or prefill numbers from different context lengths are not comparable.
  This is the real explanation of the 46.6 t/s vs 6.2 t/s spread recorded on
  2026-09-12 — an earlier note blamed the battery, and was wrong.

Power state is still worth watching as hygiene (`bench-one.sh` notes a
discharging battery), but it was **not** the cause here: the short-context run
peaked at 53 W and the long-context run, 4.6x slower, peaked at 113 W.

## 5. Reference windows on this card

Use these as test targets; they are the verified values this skill recorded, not
aspirations. Both are pure GPU (`ngl 999`), KV `iq4_nl`, `-np 1`.

| Model | ctx | VRAM | decode t/s (warm) |
|---|---|---|---|
| Qwen3.8-27B IQ3_XXS (dense) | 81,920 | 13,602 MiB | 21.1 |
| Qwen3-Coder-30B-A3B IQ2_M (MoE) | 81,920 | 13,140 MiB | 46.6 |

Detail and method: [`backends-benchmark.md`](./backends-benchmark.md) §10.5.9 and
[`llamacpp/TESTING.md`](./llamacpp/TESTING.md) §15.

Before testing a model you believe is present, check for an unfinished download —
a `.part` file is not a model:

```bash
find ~/.lmstudio/models -name "*.part" -printf "%10s %p\n"
```

## 6. What to record after every accepted run

1. `backends-benchmark.md` §10.5.x — the dated table + a filled matrix row
   (ctx, quant, engine, gen t/s, prefill t/s, TTFT, VRAM GB, GPU/CPU%, notes).
2. `llamacpp/TESTING.md` — a dated per-model section.
3. `~/.pi/agent/models.json` — the model's `contextWindow`, set to the value
   **read back from `/props`**, never the value you asked for.

Record `n/m` for anything you did not measure. An honest gap beats a guessed
number.

## 7. Running the service is not this skill's business

The machine's serving stack — the router, the launcher, the registry, the TUI,
the gateway, and the CUDA shim — lives **outside every git repo** in the
machine's own home, `~/.local/share/llama-router/`, with its manuals beside it:

- `~/.local/share/llama-router/docs/LLAMA_CPP_SERVER.md` — the full system doc
- `~/.local/share/llama-router/docs/SYSTEM.md` — architecture, client wiring, ports
- `~/.local/share/llama-router/docs/llama-menu.md` — TUI + swap model reference
- `~/.local/share/llama-router/docs/swap-proxy.md` — legacy gateway

To start, stop, reconfigure, or add a model to the service, work **there**. When
you have a verified number, come back and record it here.

## 8. Traps that have already bitten

| Symptom | Cause | What a tester does |
|---|---|---|
| Model loads, then runs ~10× slow | CPU-only `/usr/bin/llama-server` | `--list-devices` first; use the CUDA build |
| 0 % GPU util and a low t/s, fast later | 210 MHz idle clock, no warm-up | warm the GPU before timing (bench-one.sh does) |
| Throughput well below a recorded value | the recorded number was measured at a shorter context | compare at equal context; short-context figures are upper bounds |
| Absurd prefill number | quoted from a tiny prompt | multi-thousand-token prompt |
| OOM on a model that fits on paper | weights + KV + compute buffer; or something else is already resident | check VRAM first; `stop-all.sh` reports who holds it |
| "missing gguf" for a model you downloaded | `models_dir` is not LM Studio's folder, or a `.part` | `llama-models defaults`; look for `.part` |
| pi auto-compacts at ~8K | the router reports `meta.n_ctx` only for the *resident* alias | static `contextWindow` per model in `models.json` |


## 9. The KV-type trap that made everything slow

Recorded live on this host: prefill of **14.5 t/s** on a 7,940-token prompt and
decode falling from **21.2 t/s** (19-token context) to **4.6 t/s** (~8K), with
the GPU at 100% utilisation and near its 115 W cap. The cause was not the card,
the driver, the eGPU link, or the power supply: the registry said
`kv: iq4_nl`, and a default CUDA build's flash-attention kernel **rejects
IQ4_NL**, so the scheduler silently ran the whole attention op on the CPU
(llama.cpp issue #27109).

```
kv_type_rule[3]{rule}:
  "accepted by the CUDA FA kernel in a default build","f16, q8_0, q4_0, bf16 (q4_1/q5_0/q5_1 only with -DGGML_CUDA_FA_ALL_QUANTS=ON)"
  "K and V must match","a mixed pair (K=q4_1, V=q8_0) also returns no kernel and falls back to CPU"
  "never","iq4_nl — it is not in the accepted set at all, and the fallback is silent"
```

Verify what is actually running, any time:

```bash
grep -E "cache-type-k|cache-type-v" /tmp/opencode/llama-router.log | tail -4
```

Full detail, the upstream quotes, and the KV-memory-vs-context table:
`.agents/skills/modeltesting/backends-benchmark.md` §10.5.10.

For a smaller KV (more context) at full speed you need the flag-that-adds
kernels: build llama.cpp with `-DGGML_CUDA_FA_ALL_QUANTS=ON`. This host cannot
do that yet — no CUDA toolkit and no passwordless sudo, and the packaged
`extra/llama-cpp` is CPU-only.

## 10. The INTERNAL GPU (AMD iGPU) — serving when the eGPU is not the target

Do not assume this box has a 3050 or a 1080: it does not. `lspci` shows exactly
two display devices.

```
gpus[2]{card,device,role}:
  "card0","NVIDIA GA104M (10de:249c) RTX 3080 Laptop 16 GB","the XG Mobile eGPU — PCIe 3.0 x4; this is what the router uses"
  "card2","AMD Cezanne (1002:1638) Radeon Vega iGPU","the INTERNAL GPU — shares system RAM, no VRAM of its own"
```

The CUDA build cannot touch the AMD iGPU. LM Studio ships a **Vulkan** llama.cpp
build that can, and it sees both devices — so the device must always be pinned:

```
Vulkan0: AMD Radeon Graphics (RADV RENOIR)  16254 MiB (shared RAM)  <- internal
Vulkan1: NVIDIA GeForce RTX 3080 Laptop GPU 16384 MiB               <- the eGPU
```

Serving path (`llama-igpu`, machine property, its own endpoint on `:8097`):

```bash
llama-igpu start 4b     # the 4B on Vulkan0, its own port and alias
llama-igpu status
llama-igpu stop
```

It is deliberately **not** part of the router: router mode spawns one binary for
all presets, and that binary is the CUDA build. Because the two servers sit on
different devices they run **side by side** — verified: the router held 6 aliases
on the 3080 while `llama-igpu` served the 4B on the AMD iGPU.

**Measured on the internal GPU** (Qwen3.5-4B Q4_K_S, q8_0 KV, `ngl 999`):

| ctx configured | prefill t/s | decode t/s | RAM in use |
|---|---|---|---|
| 32,768 | 129.3 | 11.7 | — |
| 262,144 (native max) | 128.0 | 11.7 | 15 GiB of 30 GiB |

Context is nearly free here — the iGPU borrows system RAM — so the useful setting
is the model's full native window; the cost is speed, roughly **8x slower decode
and 21x slower prefill** than the same model on the XG Mobile 3080 (91.3 t/s
decode / 2,705 t/s prefill). Numbers are flat across configured context because
attention cost follows the context actually in use.

pi reaches it through a second provider, `llamacpp-igpu` -> `:8097/v1`.

### 10.5 Keeping it up — systemd, on demand

`llama-igpu start` detaches with `setsid`, but a launcher started from a shell
that is later torn down (an agent session, a closed terminal) can be reaped
together with its process group — observed here: the server logged
`cleaning up before exit` and the endpoint went dead between two commands.
Manage it under systemd instead:

```bash
systemctl --user start llama-igpu        # on demand
systemctl --user status llama-igpu
systemctl --user stop llama-igpu
```

The unit lives at `~/.config/systemd/user/llama-igpu.service` and is deliberately
**left disabled** — it does not start at login, because while it runs it holds the
model's weights plus its entire KV allocation in system RAM (~7 GiB at 262,144
ctx on a 30 GiB box). Start it when you want the internal GPU, stop it when done.

## 11. All models verified on this host (2026-09-12)

Every row was measured with a real ~8K-token request, `n_ctx` read back from
`/props`, on the RTX 3080 eGPU unless the row says otherwise. `q8_0` KV for all
of them, K == V, `ngl 999`, `-np 1`, batch 2048 (512 for the iGPU rows).

| Model | weights | KV/token | ctx | prefill t/s | decode t/s | memory | router alias |
|---|---|---|---|---|---|---|---|
| Qwen3.5-4B Q4_K_S | 2.41 GiB | 17.0 KiB | **262,144** | 2,693 | **90.9** | 9,316 MiB | `qwen3.5-4b@q4_k_s` |
| Qwen3.5-4B Q4_K_S (light) | 2.41 GiB | 17.0 KiB | 100,000 | 2,703 | 90.9 | 5,358 MiB | `qwen3.5-4b-100k@q4_k_s` |
| Qwen3.5-9B Q4_K_S | 5.02 GiB | 17.0 KiB | **262,144** | 1,798 | **61.5** | 11,470 MiB | `qwen3.5-9b@q4_k_s` |
| Qwen3.5-9B Q4_K_S (light) | 5.02 GiB | 17.0 KiB | 100,000 | 1,783 | 61.8 | 7,512 MiB | `qwen3.5-9b-100k@q4_k_s` |
| Qwen3.6-35B-A3B IQ2_XXS (MoE) | 10.02 GiB | 10.6 KiB | **262,144** | 2,057 | **89.4** | 14,763 MiB | `qwen3.6-35b-a3b@iq2_xxs` |
| Qwen3-Coder-30B-A3B IQ2_M (MoE) | 10.09 GiB | 51.0 KiB | **90,112** | 2,251 | **67.0** | 15,673 MiB | `qwen3-coder-30b-a3b@iq2_m` |
| Qwen3.8-27B IQ3_XXS (dense) | 11.05 GiB | 32.0 KiB | **114,688** | 495 | **20.7** | 15,345 MiB | `qwen3.8-27b@iq3_xxs` |
| Qwen3.5-4B — INTERNAL iGPU | 2.41 GiB | 17.0 KiB | 262,144 | 128 | 11.7 | ~7 GiB RAM | `:8097` (llama-igpu) |
| Qwen3.5-9B — INTERNAL iGPU | 5.02 GiB | 17.0 KiB | 262,144 | 80.8 | 7.1 | ~9 GiB RAM | `llama-igpu start 9b` |

**Read this table with the two rules it produced:**

- **The context ceiling does not change speed.** The 4B measured 90.9 t/s decode
  at both 100,000 and 262,144; the 9B measured 61.5 and 61.8. A smaller ceiling
  buys memory — roughly 4 GiB — and nothing else. Attention cost follows the
  context actually in use.
- **KV size, not weight size, decides how much context fits.** The 35B-A3B
  (10.02 GiB of weights) reaches 262,144 because only 10 of its 40 blocks are
  full-attention (10.6 KiB/token); the dense 27B (11.05 GiB) stops at 114,688 at
  32 KiB/token; the pure-attention 30B coder at 51 KiB/token stops at 90,112.
  Budget as `KV_layers x 2 x kv_heads x head_dim x bytes x ctx`, then fit that
  plus weights plus ~0.9 GiB of compute buffer inside ~15,812 MiB.

Ceilings here are the largest value that **survived a real request**. The 27B
loads at 131,072 and then dies; the 30B coder will not load at 98,304 at all.
