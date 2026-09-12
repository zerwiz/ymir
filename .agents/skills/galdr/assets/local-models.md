# Vog — local models: operating the runtime on models that run on this machine

**Vog** is the scales: the capability that weighs a local model on this machine
and reports what it truly weighs. Load this when the setup serves **local** models: when pi, opencode, or an agent
roster points at a local endpoint, when a model's context window or speed has to
be decided, or when a local backend is chosen, installed, or suspected of
misbehaving. If every model in the setup is hosted, this asset does not apply.

> **Two laws.**
> 1. **Measure, never assume.** A local model's usable context and speed are
>    facts about *this* machine. Take them, do not inherit them.
> 2. **The numbers are private.** Devices, model inventories, memory and speeds
>    describe the operator's hardware. They belong in **Hodd**
>    (**Hodd**, `hodd/docs/vog/`, `RULES/04-hoard.md`), never in a tracked skill.

## 1. The engines galdr must recognise

| Engine | Endpoint it usually holds | How to recognise it | What it hides |
|---|---|---|---|
| **llama.cpp** (`llama-server`) | `:8080` (or per-model ports) | `llama-server` in the process list; a `--models-preset`/`--models-dir` flag means **router mode** (many models, one endpoint) | nothing — but you own every flag. The reference for GGUF. |
| **LM Studio** | `:1234` (its HTTP server) | `lm-studio` process; `~/.lmstudio/` on disk; its own model folder | bundles an **older** llama.cpp than upstream, and its defaults are conservative — they can push work onto the CPU |
| **Ollama** | `:11434` | `ollama` process; models under `~/.ollama/models` | hides the MoE expert-offload knobs; a plain model loads at a **low default context** unless `num_ctx` is set |
| **vLLM / SGLang** | `:8000` | `vllm` process | needs fp8/bf16 rather than GGUF, and a large device — the wrong shape for a single-user desktop |
| **ExLlama (TabbyAPI)** | `:5000` | `tabbyAPI` process | EXL2/EXL3 only; **cannot read GGUF** |

Detection, in one line each:

```bash
curl -s http://127.0.0.1:8080/v1/models   # llama.cpp (router or single)
curl -s http://127.0.0.1:1234/v1/models   # LM Studio
curl -s http://127.0.0.1:11434/v1/models  # Ollama
```

All three answer the same OpenAI-shaped `/v1` API, which is why the harness does
not care which one is behind the URL — and why a wrong assumption about *which*
one is behind it is easy to make and expensive to debug.

## 2. Pointing the runtime at a local model

- **pi** — models come from `.pi/agent/models.json` (providers + models) or the
  built-in local providers. Prefer **static** entries with an explicit
  `contextWindow`: in router mode a server may report the true `n_ctx` only for
  the model that is currently resident, and any client that falls back to its own
  default will silently compact far too early.
- **opencode** — a provider block with `baseUrl` pointing at the local `/v1`.
- **Environment** — a local server can be selected without config where the
  harness supports it (e.g. a base-URL variable); prefer config, which is
  reviewable.
- Harness specifics: `assets/harness-integration/pi.md` and
  `assets/harness-integration/opencode.md`.

**Always write an explicit context window** per local model. The server's own
advertisement is not a contract.

## 3. Choosing an engine

- **GGUF work → llama.cpp.** Everything tunable, and router mode gives one
  endpoint for many models.
- **Convenience → LM Studio or Ollama.** Good download and run experience; accept
  that you must verify the engine version, the defaults, and the context.
- **Throughput serving for many users → vLLM/SGLang**; **maximum speed on one
  consumer GPU → ExLlama**, at the cost of GGUF.

## 4. Measuring a local model honestly

Five numbers decide usability:

```
five_numbers[5]{metric,decides}:
  "prefill t/s","time-to-first-token on a realistic prompt"
  "decode t/s","whether it is usable at all"
  "TTFT","wall time to the first token at the size of prompt you really use"
  "peak device memory","what else can run beside it"
  "GPU/CPU split","whether the device did the work"
```

Procedure: start from a known baseline → warm up and discard → **warm the GPU
itself** (many hosts idle at a low clock and boost lazily) → pin seed and
temperature → verify the loaded context *from the server* → use a multi-thousand
token prompt → sample the device during the run → finish with a real request at
the configuration you intend to keep.

Always record **the context the run was measured at**. A decode figure without
its context is not a measurement.

### The four traps that produce believable, useless numbers

| Trap | Reads as | Is |
|---|---|---|
| **Silent backend fallback** | device busy, high wattage, CPU-class throughput | the requested KV cache type had no kernel for that build, so an op moved to the CPU — no error, no log line |
| **Load is not run** | a model that loads, written down as working | it may die on the first real request |
| **Context-blind comparison** | two runs "differing by config" | they also differed in context; attention cost tracks the context in use |
| **Asserted > observed** | a tidy explanation for a slow run | the explanation was never tested against an alternative |

### Budgeting context

```
kv_bytes_per_token = kv_layers x 2 x kv_heads x head_dim x bytes_per_element
usable_context     = (free_memory - weights - ~compute_buffer) / kv_bytes_per_token
```

`kv_layers` counts only the blocks that keep a real KV cache — hybrid models
(linear/recurrent blocks mixed with attention) cache a fraction of their blocks
and so afford far more context than their weight size suggests. **Keep the K and
V types identical**, and prefer a modest prompt batch: a batch that is
comfortable at a small context can exhaust the device at a large one, and the
failure appears on a *request*, not at load.

Find the ceiling by bisection and confirm it with a real request. The largest
value that **survives** is the answer, not the largest that loads.

## 5. Tooling

`scripts/bench-one.sh` — one model end to end: it starts its **own** throwaway
single-model server on a scratch port, verifies the loaded context, warms,
times a cold-context run, samples the device, and tears down. It never touches a
running service, and needs only a `llama-server` binary and a `.gguf`.

```bash
.agents/skills/galdr/scripts/bench-one.sh /path/to/model.gguf --ctx 32768
.agents/skills/galdr/scripts/bench-one.sh /path/to/model.gguf --ctx 131072 --kv q8_0
.agents/skills/galdr/scripts/bench-one.sh /path/to/model.gguf --ctx 8192 --ngl 0   # pure CPU
```

Point it at the right server with `--server` (or `$LLAMA_SERVER`); a build that
reports no GPU device will measure the CPU, and the script says so.

`scripts/gpu-sample.sh` samples utilisation and memory while a command runs —
the way to catch a CPU spill. `scripts/stop-all.sh` clears leftover throwaway
servers and reports what holds the device.

## 6. Where the results go — Hodd

A host record keeps: the machine and its devices, the model inventory with
verified windows, every measured table **including the rejected configurations**,
the host-specific traps, and the operational notes for that stack.

```bash
export YMIR_HOARD="${YMIR_HOARD:-$PWD/hodd}"
ls "$YMIR_HOARD/docs/vog/"
```

Shape to follow: `assets/local-models/HOST-DATA.example.md`.

## 7. Installing a local stack

Installing and running a local model service is the operator's business on their
own machine, not part of a shared tree. What galdr guarantees is the *knowledge*:
which engine, how to reach it, how to point a harness at it, and how to measure
it. Keep the service's own scripts, registry and configuration on the machine —
outside every repository — and keep only the framework here.

## 8. Upstream documentation — the authoritative addresses

Verified **2026-09-12**. These are the *sources of truth*; galdr reads them
rather than recalling a flag from memory.

| Engine | Documentation | Server / API reference |
|---|---|---|
| **llama.cpp** | <https://github.com/ggml-org/llama.cpp> | server: <https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md> · build & backends (CUDA/Vulkan/ROCm/Metal): `…/docs/build.md` |
| **LM Studio** | <https://lmstudio.ai/docs> | developer/API: <https://lmstudio.ai/docs/developer> · REST: <https://lmstudio.ai/docs/developer/rest> · CLI: <https://lmstudio.ai/docs/cli> |
| **Ollama** | <https://docs.ollama.com> | Modelfile: <https://docs.ollama.com/modelfile> · **machine-readable index: <https://docs.ollama.com/llms.txt>** |
| **vLLM** | <https://docs.vllm.ai> | — |
| **SGLang** | <https://docs.sglang.ai> | — |
| **ExLlamaV2 / TabbyAPI** | <https://github.com/theroyallab/tabbyAPI> | — |
| **llama-swap** (external router) | <https://github.com/mostlygeek/llama-swap> | — |

Read this table with four facts in mind:

- **llama.cpp has no separate documentation site — the repository *is* the
  documentation.** The server flags live in `tools/server/README.md`, the
  backends in `docs/build.md`, and the router/preset behaviour there plus the
  server README. When a flag's meaning matters, read it at the source.
- **Ollama publishes a machine-readable page index** at `/llms.txt`. Fetch it to
  discover the current page instead of guessing a path that has moved.
- **LM Studio's docs are per-page, not per-release**, and it bundles its own
  llama.cpp build. Check the *bundled engine version* separately from the app
  version; an old engine explains most "impossible" numbers from that backend.
- **Release notes and issue trackers are documentation.** For llama.cpp
  especially, a behaviour that surprises you is usually an open issue with the
  root cause already written down — including the silent ones.

## 9. When a local model misbehaves — research it upstream, then record it

A local stack fails in ways that look like hardware limits and are not: a build
quietly doing an operation on the CPU, a KV cache type with no kernel, an engine
version too old for a feature, a quant the loader misreads. **Guessing at these
wastes hours and produces plausible wrong conclusions.** When a local-model
service misbehaves, galdr researches it rather than theorising:

1. **Capture the exact string.** The precise error line, or the precise absence
   of one. "It is slow" is not a symptom; "prefill 14 t/s with the GPU at 100 %
   and 115 W" is.
2. **Search the project's issues for that string**, not for your theory. Use the
   tracker at the address in §8, and the web more broadly. Include the build
   version and the flags in the query.
3. **Quote the root cause with a date and a link** — and note whether it is
   fixed, open, or silently unacknowledged. Distinguish "the vendor says" from
   "someone's blog says".
4. **Check the engine version before anything else.** A bundled or packaged
   engine that is months behind explains most anomalies, and a pinned version is
   a repeatable, comparable thing — a moving one is not.
5. **Test the candidate cause on this machine.** Reproduce with the fix, or
   disprove the theory. An explanation that has not been tested against an
   alternative is not a diagnosis.
6. **Record the finding where it belongs.** A general lesson — a trap, a check,
   a flag that matters — goes in this asset. Anything describing *this* machine's
   devices, models and numbers goes to Hodd (§6).
7. **Never paper over a silent fallback.** If the fix is "use a different flag
   until upstream lands the kernel", write that down with the reason, so the
   next operator does not rediscover it as a machine limit.

An example of the shape, from this platform's own history: a GPU that was
visibly busy at full wattage while throughput sat at CPU level turned out to be
the attention operation being scheduled onto the CPU because the requested KV
cache type had no kernel in that build — no error, no log line. It was found by
reading the upstream issue tracker, not by tuning flags. See §4, first trap.
