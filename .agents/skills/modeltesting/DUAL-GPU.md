# DUAL-GPU — running both GPUs of this box at the same time

This machine has **two usable compute GPUs**, and they can serve simultaneously.
This document records what each one is, how both run at once, what it costs, and
the trap that this configuration exposed.

> Boundary, as ever: this skill **tests**. Standing the stack up is
> [`INSTALL.md`](./INSTALL.md); the machine's own manuals live at
> `~/.local/share/llama-router/docs/`. This document exists because "can both
> GPUs work together?" is answered by *measurement*, and the measurements belong
> here.

Last measured: **2026-09-12**.

---

## 1. The two GPUs

```
lspci shows exactly two display devices — there is no 3050 and no 1080 here.

card0  NVIDIA GA104M (10de:249c) RTX 3080 Laptop 16 GB
       role : the XG Mobile eGPU, on a PCIe 3.0 x4 link
       backend: CUDA   — LM Studio's cuda12 pack, via llama-server-cuda
       endpoint: :8080 (the router, one model resident at a time)

card2  AMD Cezanne (1002:1638) Radeon Vega iGPU
       role : the INTERNAL GPU, no VRAM of its own, borrows system RAM
       backend: Vulkan — LM Studio's vulkan pack, via llama-server-vulkan
       endpoint: :8097 (llama-igpu, one model)
```

The two speak different backends, which is the whole reason this works: the
CUDA build cannot see the AMD iGPU, and the Vulkan build sees both. **Two
endpoints, two binaries, two devices.**

```
                 ┌─────────────────────── pi (two providers) ──────────────────────┐
                 │                                                                │
      provider llamacpp  ──>  http://127.0.0.1:8080/v1            :8097/v1  <── provider llamacpp-igpu
                 │                       │                                  │
        ┌────────▼────────┐     ┌────────▼─────────┐                ┌───────▼────────┐
        │ llama-router    │     │ (evicts on swap) │                │ llama-igpu     │
        │ --models-max 1  │     └──────────────────┘                │ one model      │
        └────────┬────────┘                                         └───────┬────────┘
                 │ CUDA                                                     │ Vulkan
        ┌────────▼────────┐                                         ┌───────▼────────┐
        │ RTX 3080 (eGPU) │                                         │ AMD Vega (iGPU)│
        │ own 16 GB VRAM  │                                         │ system RAM     │
        └─────────────────┘                                         └────────────────┘
```

## 2. Running both

```bash
systemctl --user status llama-router      # eGPU, CUDA,   :8080
systemctl --user status llama-igpu        # iGPU, Vulkan, :8097

systemctl --user start llama-igpu         # on demand (see §5)
systemctl --user stop  llama-igpu
```

`llama-igpu` is deliberately **not** part of the router: router mode spawns one
binary for all of its presets, and that binary is the CUDA build. Because the
servers sit on different devices, both run at once — no eviction between them.

## 3. Measured — solo and concurrent

The same ~1.5K-token prompt, sent to both endpoints **at the same instant**:

| Where | model | prefill t/s | decode t/s | notes |
|---|---|---|---|---|
| eGPU :8080 | Qwen3.6-35B-A3B IQ2_XXS @ 262,144 | 1,858 | **92.7** | peak 14,764 MiB of 16,384, 95% util |
| iGPU :8097 | Qwen3.5-4B Q4_K_S @ 262,144 | 8.2 | **9.0** | concurrent with the above |

Solo, for comparison:

| Where | model | prefill t/s | decode t/s |
|---|---|---|---|
| eGPU | 35B-A3B | 2,057 | 89.4 |
| iGPU | 4B | 128.0 | 11.7 |

**The honest reading: decode coexists well, prefill contends badly.** Running
together, the eGPU's decode did not suffer (92.7 vs 89.4), but the iGPU's
**prefill collapsed from 128 to 8.2 t/s** — a 15x loss — while its decode held
at 9.0 (down modestly from 11.7). The iGPU has no VRAM of its own: it computes
and reads its weights and KV straight out of system RAM, so it competes with the
eGPU model's CPU threads and host memory bandwidth. The eGPU is unaffected
because its weights and KV live in its own 16 GB.

Practical rule: **run long prompts on the eGPU, and treat the iGPU as a
background/low-priority server.** A big prefill on the eGPU will starve it.

## 4. The trap this configuration exposed — batch size vs VRAM

While proving concurrency, the eGPU child died mid-request:

```
ggml/src/ggml-cuda/ggml-cuda.cu:108: CUDA error
CUDA error: out of memory
instance name=qwen3.6-35b-a3b@iq2_xxs exited with status 1
```

The model was not at fault, and neither was concurrency: the router's preset
INI carried a **default `batch-size = 4096 / ubatch-size = 4096`**, while every
verified configuration had been measured at **2048**. At 262,144 context the
wider batch's compute buffer no longer fit: peak VRAM reached 15,976 MiB of
16,384 and the allocator failed under load.

Fixed at both levels:

- the INI `[*]` defaults are now `batch-size = 2048`, `ubatch-size = 2048`,
  `threads = 16`;
- the entries for the models measured here carry explicit
  `batch: 2048` and `threads: 16`.

Verified after the fix: the same concurrent pair completed, the 35B answered
`OK`, peak VRAM settled at 14,764 MiB.

**Lesson for the bench:** a model that loads is not a model that runs. Push a
real request at the configuration you intend to ship, and treat the router's
preset defaults as part of the configuration under test.

## 5. Costs and limits

- The iGPU server holds the model's weights **plus its entire KV allocation** in
  system RAM while it runs — about **7 GiB at 262,144 ctx on a 30 GiB box**.
  That is why `llama-igpu.service` is left **disabled** and started on demand,
  unlike `llama-router.service`, which is enabled at login.
- The router keeps **one** model resident on the eGPU (`--models-max 1`); a
  second request for a different model swaps it.
- The internal GPU is roughly **8x slower in decode and ~21x slower in prefill**
  than the eGPU for the same 4B, so it is a fallback or a background worker, not
  a throughput multiplier.
- pi reaches both through two providers: `llamacpp` → `:8080` and
  `llamacpp-igpu` → `:8097`, each with the model's verified `contextWindow`.

## 6. Verify it yourself

| # | Command | Expected |
|---|---|---|
| 1 | `llama-server-cuda --list-devices` | `CUDA0: … RTX 3080 …` |
| 2 | `llama-server-vulkan --list-devices` | `Vulkan0` (AMD iGPU) **and** `Vulkan1` (RTX 3080) |
| 3 | `systemctl --user is-active llama-router llama-igpu` | `active active` |
| 4 | `curl -s 127.0.0.1:8080/v1/models` | the router's aliases |
| 5 | `curl -s 127.0.0.1:8097/v1/models` | the iGPU model's alias |
| 6 | both requests at once | both answer; the eGPU stays fast, the iGPU's prefill slows sharply |

Step 2 is the one people skip. The Vulkan build lists **both** devices, so a
model meant for the iGPU must be pinned with `--device Vulkan0` — otherwise
llama.cpp picks for you and the "internal" model lands on the eGPU's memory.

---

## 7. The internal GPU today — and the 9B as a better fit than the 4B

The 9B was also measured on the internal AMD iGPU at its native window:

| model on Vulkan0 | ctx | prefill t/s | decode t/s | RAM |
|---|---|---|---|---|
| Qwen3.5-4B Q4_K_S | 262,144 | 128.0 | 11.7 | ~7 GiB |
| **Qwen3.5-9B Q4_K_S** | 262,144 | **80.8** | **7.1** | ~9 GiB |

For the internal GPU the 9B is the better trade: roughly 40% slower in decode
than the 4B, for a materially better model, and still only ~9 GiB of the 30 GiB
it borrows. Start it with `llama-igpu start 9b`.

Note the RAM figure is the *whole* box: with both the 4B and the 9B resident on
the iGPU at once, measured use was **22 GiB of 30 GiB**. The internal GPU holds
its weights *and* its full KV allocation in system RAM for as long as it runs —
which is why `llama-igpu.service` is disabled at login and started on demand,
and why running two models there at once is not advisable on a 30 GiB box.
