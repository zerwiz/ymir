# swap-proxy — the auto-swap proxy (built, verified)

Operational doc for the **real auto-swap proxy** that powers "swap model in
pi.dev/opencode → stop the running model, start the one I chose."

- Status: **BUILT + VERIFIED** (2026-09-07)
- Files: `~/command/scripts/swap-proxy.cjs`, launcher `~/command/scripts/swap-proxy`
- Companion: [`how-llama-swap-works.md`](./how-llama-swap-works.md) (research background)

---

## 1. What it does

One stable endpoint (`http://127.0.0.1:8090`). When a request names a model:

1. **Resolve** the model → port + `model-host start <id>-swap` launch command
   (map auto-derived from `~/.pi/agent/models.json`).
2. **Fast path**: if that model is already the loaded one on its port, forward
   (no reload).
3. **Swap path**: call `model-host start <id>-swap`, which **stops ANY model
   sharing that port** (the patched swap logic) and starts the requested one.
4. **Wait** for the port to accept, then forward the request.

Client sees one URL; swapping the `model` field triggers the backend swap.

---

## 2. Quick start

```bash
# start (detached, survives shell exit)
~/command/scripts/swap-proxy start

# status / stop / restart
~/command/scripts/swap-proxy status
~/command/scripts/swap-proxy stop
~/command/scripts/swap-proxy restart
```

- PID: `/tmp/opencode/swap-proxy.pid`
- Log: `/tmp/opencode/swap-proxy.log`

---

## 3. Config

- Port: `--port 8090` (or `SWAP_PROXY_PORT`).
- Models file: `~/.pi/agent/models.json` (or `--models`).
- model-host: `~/command/scripts/model-host.sh` (or `--host`).

**Aliases** (`ALIASES` in `swap-proxy.cjs`): client-facing short IDs
(`qwen3.6-35b-q2_k_xl`) map to pi IDs (`qwen3.6-35b-a3b@q2_k_xl`). Direct pi
IDs work too.

---

## 4. Verified behaviors (RTX A5000, 2026-09-07)

| Test | Result |
|---|---|
| Auto-start on request (nothing running) | ✅ minicpm started on :8092, served |
| Same-port swap stops previous | ✅ 12b-q3 → 12b-q4 on :8088; old pid killed |
| Already-loaded fast path | ✅ no reload, immediate response |
| opencode alias routing | ✅ `minicpm5-1b-agentic-tooluse` → `...@q8_0` |
| Launcher start/stop/status | ✅ |
| Qwen3.8 Flash Next (CPU-expert offload) | ✅ loaded :8095, ~14.2 GB VRAM, 100K ctx |

---

## 5. How it wires in

- **Catalog = llama.cpp registry + pi (60 models)**. `buildModelMap()` merges
  the llama.cpp registry (`llama-models.yaml` via the `llama-models` CLI) with
  pi's launchable models (`~/.pi/agent/models.json`). `/v1/models` serves all
  **60** — the 40 registry ids (`q2`, `9b-swap`, `dualchat-gemma`, …) plus the
  20 pi @-variants (`qwen3.6-35b-a3b@q2_k_xl`, …). Any id routes to
  `model-host start <id>`.
- **pi**: `~/.pi/agent/models.json` has 60 llama.cpp launchable models — all 40
  registry ids (as `llamacpp-<id>` providers) + the 20 @-variants.
- **opencode (4 accounts)**: `~/.config/opencode{,rd,work,oczer}/opencode.json`
  llama.cpp `baseURL` → `http://127.0.0.1:8090/v1` (the proxy). Includes
  `qwen3.8-flash-next@q3_k_xl` (100K ctx).

So swapping in any opencode account or pi hits the proxy, which swaps the
backend — and `/login llama.cpp` validates against the full 60-model catalog.

---

## 6. Troubleshooting

- **`swap failed: model failed to start`** → check `/tmp/opencode/llama-<id>.log`.
  Common cause: model too big for the offload config (see the Flash Next
  settings doc — use `cpu_moe:true` for 90 GB MoE on 16 GB).
- **`/login llama.cpp` → "fetch failed" / models missing** → the gateway serves
  `/v1/models` from llama-models.yaml + pi. Ensure `swap-proxy start` is
  running; if ids are missing, check pi's models.json has the model (add via
  the `llamacpp-<id>` pattern) and restart the proxy.
- **Proxy died** → restart via launcher; ensure you use `swap-proxy start` (it
  detaches with `setsid`).
- **Wrong model served** → confirm the alias map in `swap-proxy.cjs`; the
  client ID must resolve to a pi ID with a `-swap` launch.

---

## Related

- [`how-llama-swap-works.md`](./how-llama-swap-works.md) — research + architecture decision
- [`../models/qwen3.8-flash-next-settings.md`](../models/qwen3.8-flash-next-settings.md) — offload settings for the big MoE
- [`../llamacpp/TESTING.md`](../llamacpp/TESTING.md) — the underlying llama-server build

---

## 7. Operative log — router + pi context trace (appended 2026-09-09)

### 7.1 pi + all opencode switched to the native router (:8080)

- `~/.pi/agent/models.json`: all 22 `llamacpp-*` providers repointed
  `baseUrl` → `http://127.0.0.1:8080/v1`, `_launch: false` (router owns the GPU;
  do NOT spawn `model-host` servers beside it — VRAM OOM on swap).
- opencode accounts (`opencode`, `oczer`, `rd`, `work`): `baseURL` already
  `:8080`; only a display-name label said `(:8090)` — label fixed to `(:8080)`.
- `swap-proxy` (:8090) left **down** — the native router (`--models-max 1`)
  replaces it as the single swap path.

### 7.2 The pi low-context bug — router reports `meta.n_ctx` only for the resident model

- **Symptom:** `gpt-oss-20b@f16` in pi auto-compacted at tiny context;
  `Auto-compaction failed: Turn prefix summarization failed: Operation aborted`;
  status `(llama-cpp) gpt-oss-20b@f16`.
- **Root cause (verified 2026-09-09):** in router mode (`--models-preset`,
  `--models-max 1`) llama.cpp's `/v1/models` returns `meta.n_ctx` **only for the
  currently resident alias**. All 23 aliases reported `n_ctx: None` except the
  loaded one (e.g. `gemma-4-12b@q3_k_s` → 65536). pi's plugin
  `pi-llama` (`~/.pi/agent/git/github.com/huggingface/pi-llama/index.ts`) computes
  contextWindow as `model.meta?.n_ctx ?? previous?.contextWindow ??
  DEFAULT_CONTEXT_WINDOW` with `DEFAULT_CONTEXT_WINDOW = 8192`. `None` → **8192**
  → pi auto-compacts at 8.2K tokens. The plugin only learns the true ctx after
  the model becomes resident (refresh post-load).
- **Fix adopted:** use the **static provider** `llamacpp-gpt-oss-20b-f16`
  (explicit `contextWindow`) instead of the plugin, and set
  `contextWindow: 90000` for a server that serves `100000` (10 % headroom).
  Source of truth: `scripts/llama-models.yaml` → `gptoss20b` `ctx: 100000`.

### 7.3 Developer notes

- pi `/reload` reloads the provider catalog (`models.json`) without quitting —
  verified 2026-09-09; a stale running pi session silently keeps the OLD
  `baseUrl` (connection errors that never reach the router — check with
  `llama-router status` + live `tail -f` on `/tmp/opencode/llama-router.log`).
- Measured router swap latency 2026-09-09: gemma↔qwen3.5-4b ~5 s;
  35B-iq3_s→gemma-12b ~6 s. Reload is not, by itself, a timeout source.
- Request hitting the router mid-swap aborts with `Operation aborted` /
  `Loading weights (0%)` — the resident swap preempts in-flight SSE; pi's
  auto-compaction then fails with `Turn prefix summarization failed`.
