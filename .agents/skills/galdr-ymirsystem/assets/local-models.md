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

### The traps that produce believable, useless numbers

| Trap | Reads as | Is |
|---|---|---|
| **Silent backend fallback** | device busy, high wattage, CPU-class throughput | the requested KV cache type had no kernel for that build, so an op moved to the CPU — no error, no log line |
| **Load is not run** | a model that loads, written down as working | it may die on the first real request |
| **Context-blind comparison** | two runs "differing by config" | they also differed in context; attention cost tracks the context in use |
| **Asserted > observed** | a tidy explanation for a slow run | the explanation was never tested against an alternative |
| **Anonymous load on unified memory** | a model that loads fine, and later "the machine crashed" | on a unified-memory host the GPU's memory **is** system RAM. An anonymous (non-`mmap`) load makes the weights unreclaimable, so under pressure the kernel OOM-kills **something else** — usually the desktop, not the model. Load file-backed. |
| **Backend chosen by reputation** | "ROCm is the AMD backend, so use ROCm" | on some iGPU targets a backend returns **silently wrong** logits — fast, plausible, incorrect. Backend choice is a measurement, not a default. |
| **Reasoning configured through the chat template** | a model that thinks forever, or degenerates, "because the model is weak" | the engine's **native** reasoning budget and the chat-template keyword are different mechanisms with different behaviour. Configure reasoning at the engine. |

### The fifth trap — model-host port drift

| Trap | Reads as | Is |
|---|---|---|
| **Router port ≠ model port** | `:8080` dead or wrong model answers | **model-host** runs each variant (swap/parallel/orchestrator) on its **own port** from `llama-models.yaml`; the router `:8080` may be empty. The catalog (`~/.pi/agent/models.json` or `.pi/agent/models.json`) must point at the **variant's true port**, not the router's. |

**Procedure to align the door:**

1. `model-host status` — read the running variant's port (e.g. `iq3-s` swap → `:8125`).
2. Check `llama-models.yaml` for the canonical port (`port:` under the variant's block).
3. Edit the provider's `baseUrl` in `models.json` to match that port (`http://127.0.0.1:<port>/v1`).
4. Verify: `curl http://127.0.0.1:<port>/v1/models` returns the model; a test completion works.

**Example (this platform, 2026-09-15):**
- `model-host start iq3-swap` → model runs at `:8125`.
- `llama-models.yaml` confirms swap `port: 8125`.
- `~/.pi/agent/models.json` provider `llamacpp-qwen3-6-35b-a3b-iq3_s` had `baseUrl: "http://127.0.0.1:8080/v1"` → corrected to `:8125/v1`.
- The chat's `hi` went from "Connection error" to a real reply.

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
.agents/skills/galdr-ymirsystem/scripts/bench-one.sh /path/to/model.gguf --ctx 32768
.agents/skills/galdr-ymirsystem/scripts/bench-one.sh /path/to/model.gguf --ctx 131072 --kv q8_0
.agents/skills/galdr-ymirsystem/scripts/bench-one.sh /path/to/model.gguf --ctx 8192 --ngl 0   # pure CPU
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

## 10. Driving pi with a local model — what was actually measured

The integration works end to end, tools included. What decides success is **not**
the endpoint — it is how much context the harness injects.

| Test | Model | Context | Result | Time |
|---|---|---|---|---|
| Follow a literal instruction | `qwen3.5-4b@q4_k_s` (GPU) | **none** (run outside the repo) | exact reply | 3.6s |
| The *same* instruction, inside the repo | `qwen3.5-4b@q4_k_s` | full Ymir inject | **ignored it** — answered the context instead | 17.4s |
| Follow a literal instruction, inside the repo | `qwen3.6-35b-a3b@iq2_xxs` | full Ymir inject | exact reply | 30.1s |
| **Use a tool** (read a file, report an unguessable token) | `qwen3.6-35b-a3b@iq2_xxs` | full Ymir inject | exact token back | 3.9s |
| Follow a literal instruction | `qwen3.5-4b@q4_k_s` (iGPU :8097) | none | exact reply | 57.0s |
| The *same* instruction + tool, inside the repo | `qwen3.5-4b@q4_k_s` (iGPU) | full Ymir inject | **ignored it** | — |

```
model_vs_context[3]{finding,evidence,rule}:
  "a small model drowns in the injected prompt","the same 4B obeyed exactly outside the repo (3.6s) and rambled about 'arming supervision' inside it (17.4s)","test a suspect local model OUTSIDE the repo first; it separates 'cannot follow instructions' from 'the context swamped it'"
  "a MoE absorbs it","35B-A3B (~3B active) followed every instruction and drove the read tool to an unguessable token in 3.9s","prefer a sparse MoE for agent work on a local model — the active parameters decide the speed, the total decides the capacity"
  "tool calling needs no special wiring","the tool call succeeded through pi's normal path; nothing local-specific was configured","a local endpoint that answers /v1 is enough; if tools fail, suspect the model's tool syntax, not the transport"
```

**The rule for agents.** When a local model misbehaves in the harness, do not
conclude the model is weak and do not start tuning flags. Run the identical
prompt from outside the repo. If it obeys there, the model is fine and the
*context* is the problem — pick a larger model for that errand, or give it a
leaner instruction set.

**How to run the test yourself** (non-interactive, one prompt):

```bash
pi -p --model "llamacpp/qwen3.6-35b-a3b@iq2_xxs" "Reply with exactly: LOCAL MODEL OK"
pi -p --model "llamacpp-igpu/qwen3.5-4b@q4_k_s" "Reply with exactly: IGPU OK"
```

`--model` takes `provider/id`, matching the static entries in
`.pi/agent/models.json` (§2). Screen the result by hand — a model that answers a
question you did not ask has told you more than one that answers yours.

## 11. Reasoning is a resource you must configure — not a feature you inherit

A reasoning model left to think without bound does not fail gracefully. It fails
**totally**: no answer at all, after minutes of device time. Three outcome classes
have been observed from the same model on the same request, differing *only* in how
reasoning was configured:

| Outcome | Shape |
|---|---|
| **Clean** | bounded reasoning, then a correct answer |
| **Degenerate** | reasoning collapses into repetition — plausible-looking, worthless |
| **Unterminated** | the model never leaves its reasoning; the response body is empty |

Three rules follow.

1. **Prefer the engine's native reasoning-budget flag.** Where an engine exposes
   both a native budget and a chat-template keyword, they are **not** the same
   mechanism. One bounds the thought; the other can truncate it mid-flight and
   derail the model. Use the native one.
2. **A budget is a correctness control, not merely a cost control.** The clean
   outcome above was *caused* by the budget. Without it the model is not slower —
   it is **wrong, or silent**.
3. **Read the output, not the counter.** A generation can report a healthy
   tokens-per-second figure while emitting multilingual noise or a repetition
   loop. Verify by reading the text.

**Test procedure.** Same prompt, three configurations — unbounded, budgeted,
and reasoning-off. Score what came back, not how fast it came. A model that is fast
and empty is not faster.

**For agents that need an answer, not a monologue:** when a harness reports an
empty completion or a repetition loop from a reasoning model, the first suspect is
the reasoning configuration, not the model's capability.

## 12. A model service unit must never raise itself

A service unit that loads large weights must be started **by explicit hand**, never
by login. This is a systemd-and-quadlet lesson, not a vendor one.

- **`[Install] WantedBy=default.target` is the switch** — not the restart policy.
  A unit carrying it is started when the target is reached, which for a user unit
  means **every login**. `Restart=` says nothing about this.
- **Podman quadlet units are *generated* units**, and `systemctl --user disable`
  is a **no-op** on them. So an autostart armed this way **cannot be turned off
  afterwards** — not by `disable`, and not by any wrapper script that calls it.
  Confirm by checking the unit's state (`generated`) before trusting a disable.
- **The fix is in the file, not the command line:** omit the `[Install]` section
  entirely, then `daemon-reload`. Start the unit on demand.
- **Always cap the unit.** `MemoryMax=` (with `MemorySwapMax=0`, `OOMPolicy=stop`)
  makes a bad load die **inside its own cgroup** instead of taking down the user
  session — which is what happens when the kernel's global OOM killer picks the
  victim.
- **`Restart=never` is not a valid systemd value.** The correct value is
  `Restart=no`. An invalid value is silently ignored, which makes the
  configuration a lie even when the effect happens to match the intent.

**Verification, not assumption.** After disarmament, list the generator's
`default.target.wants` directory and confirm the heavy units are **absent by name**.
A unit that still appears there can still raise itself.

```bash
ls /run/user/1000/systemd/generator/default.target.wants/
```

**Light infrastructure is a legitimate exception** — an embedding server that runs
on the CPU and cannot exhaust device memory may be allowed to start at login. Record
the exception and its reason beside the unit; an undocumented exception is drift.
