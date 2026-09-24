## runtime · unversioned · 2026-09-24 — the model rail unloads the idle, on both machines

### Why
- **Problem:** a loaded GGUF holds VRAM (and its worker holds RAM + a CUDA
  context) long after the last request. On the 4 GB iGPU box that starves the
  next model; on Heimdall's A5000 it pins the card for nothing.
- **Fix (two stages, both machines):** llama.cpp's `--sleep-idle-seconds` frees
  the model's **VRAM** on idle, but leaves the worker **process** alive (upstream
  ggml-org/llama.cpp issues #19379, #25570). So a timer reaps the sleeper:
  - `omarchy` — idle from the registry (`llama-models.yaml` →
    `defaults.sleep_idle_seconds: 600`), passed by `llama-router` as
    `--sleep-idle-seconds`; `llama-router-sweep.timer` (user, every 2 min) runs
    `llama-router sweep`, which unloads **only** workers in the `sleeping` state.
  - `heimdall` — `llama-swap.service` (a **system** unit running the native
    router, not mostlygeek's llama-swap) was **crash-looping**: after the
    2026-09-23 llama.cpp rebuild split `llama-server` into shared libs under
    `/usr/local/lib`, the loader never learned that path —
    `libllama-server-impl.so: cannot open shared object file`, exit 127,
    restart counter climbing every 10s. Mended by registering `/usr/local/lib`
    with the loader (`/etc/ld.so.conf.d/llama.conf` + `ldconfig`) and seating a
    drop-in (`LD_LIBRARY_PATH`, idle `900 → 600s`). `llama-rail-sweep.timer`
    (system, every 2 min) reaps sleepers via the router's `/models/unload`.
- **Also fixed:** `gen-llama-router-config.py` never emitted `--embedding`, so
  registry entries marked `embedding: true` started in chat mode and **aborted**
  (SIGABRT in `llama_context::output_reserve`, a core dump per request). It now
  emits `embedding = true`.
- **Also fixed:** `llama-router status` read the idle value from the registry
  rather than the live process, so an `LLAMA_IDLE_SECONDS` override misreported;
  it now parses the running cmdline and distinguishes `[loaded]` from
  `[sleeping]`.

### Verified
- `omarchy`: load `qwen3.5-4b-3050@q4_k_s` → VRAM **3647 MiB**; after idle sleep →
  **109 MiB** (`status=sleeping`, worker alive); `llama-router unload` → **3 MiB**,
  worker process gone.
- `heimdall`: load `minicpm5-1b-agentic-tooluse` → VRAM **3480 MiB**, child RSS
  1.2 GB; after idle sleep → **254 MiB** (child alive, RSS 460 MB); the rail's
  `/models/unload` and the sweep both reap the child → **65 MiB**.
- `heimdall` rail after the mend: `llama-swap.service` **active**, `/health`
  **200**, `NRestarts=0`, `ldconfig -p` lists 12 llama libs, running process
  carries `--sleep-idle-seconds 600`.
- Both units and both timers are enabled on boot (`linger=yes` on `omarchy`).
- The sweep was tested against a live probe on a throwaway port before being
  seated — the sleeping worker was reaped and the journal recorded it.

### Files
- `~/.local/share/llama-router/scripts/llama-models.yaml` (machine property)
- `~/.local/share/llama-router/scripts/llama-models.py`
- `~/.local/share/llama-router/scripts/llama-router`
- `~/.local/share/llama-router/scripts/gen-llama-router-config.py`
- `~/.local/share/llama-router/docs/SYSTEM.md` §12
- `~/.config/systemd/user/llama-router-sweep.{service,timer}`
- `heimdall:/etc/ld.so.conf.d/llama.conf`
- `heimdall:/etc/systemd/system/llama-swap.service.d/override.conf`
- `heimdall:/usr/local/bin/llama-rail-sweep.sh`
- `heimdall:/etc/systemd/system/llama-rail-sweep.{service,timer}`
