# INSTALL — provisioning the model host + router on a machine

This is the **installation** procedure: it stands up the local model-serving
stack so you can test against it. It is provisioning, not operation — once
installed, day-to-day running belongs to the machine's own docs (§9).

> **Law: the stack is machine property, outside every git repo.** Nothing here
> gets vendored into a skill or committed to a repo: this document *describes*
> the files and where they go, it does not carry them.

Verified against this host (RTX 3080 Laptop 16 GB, driver 610.57.04), 2026-09-12.

---

## 0. What gets installed, and where

```
~/.local/share/llama-router/
├── scripts/
│   ├── llama-models.yaml            # THE REGISTRY — one block per model
│   ├── llama-models.py              # registry reader (list/get/ids/verify/defaults)
│   ├── gen-llama-router-config.py   # registry -> router INI (full_id() lives here)
│   ├── llama-router                 # start/stop/status/restart the router
│   ├── model-host.sh                # one-at-a-time launcher (swap rule)
│   ├── llama-run.sh                 # detached server wrapper
│   ├── llama-server-cuda            # GPU server shim (§3)
│   ├── llama-menu                   # TUI
│   └── swap-proxy, swap-proxy.cjs   # optional legacy gateway (:8090)
├── config/llama-router-config.json  # client/port snapshot
└── docs/                            # the system's own manuals
~/.local/bin/{llama-router,model-host,llama-models,llama-server-cuda,llama-menu,swap-proxy}  # symlinks
~/.config/systemd/user/llama-router.service                               # autostart
```

Every path is resolved from the scripts' own location or from the registry, so
the seat can move without edits.

## 1. Prerequisites

| Need | Check | Note |
|---|---|---|
| NVIDIA GPU + driver | `nvidia-smi` | 16 GB class fits the models here at 80K |
| A **CUDA-capable** `llama-server` | `--list-devices` → `CUDA0` | a CPU-only build silently "works" and is ~10× slow — see §3 |
| `python3` + `pyyaml` | `python3 -c "import yaml"` | the registry reader |
| `curl`, `node` | `command -v curl node` | `node` only for the legacy gateway |
| A models directory | — | this host: LM Studio's `downloadsFolder`, `~/.lmstudio/models` |

If no CUDA llama.cpp exists on the box, get one:

- **Option A (this host):** LM Studio ships a CUDA12 build *and* the matching
  CUDA12 runtime in separate packs under `~/.lmstudio/extensions/backends/`.
  No build step — wire them with the shim in §3.
- **Option B:** build llama.cpp yourself with `-DGGML_CUDA=ON` and point
  `LLAMA_SERVER_CUDA` at the result.

## 2. Lay out the seat

```bash
mkdir -p ~/.local/share/llama-router/{scripts,config,docs}
# place the files from §0 into scripts/ and config/, then:
chmod +x ~/.local/share/llama-router/scripts/*
```

Confirm the seat is **not** inside a repo:

```bash
git -C ~/.local/share/llama-router rev-parse --show-toplevel 2>&1   # must fail: not a git repository
```

## 3. The GPU server shim (the step everyone gets wrong)

A CPU-only `llama-server` does not error — it loads a model and runs ~10× slow,
which yields believable, useless benchmark numbers:

```bash
/usr/bin/llama-server --list-devices     # -> Available devices: (none)
```

`llama-server-cuda` exports `LD_LIBRARY_PATH` to the CUDA build and its runtime,
then `exec`s the real binary. It auto-discovers LM Studio's newest CUDA12 pack,
so it survives LM Studio updates:

```bash
#!/usr/bin/env bash
set -euo pipefail
[ -n "${LLAMA_SERVER_CUDA:-}" ] && exec "${LLAMA_SERVER_CUDA}" "$@"
BASE="$HOME/.lmstudio/extensions/backends"
PACK=$(ls -d "$BASE"/llama.cpp-linux-x86_64-nvidia-cuda12-avx2-* 2>/dev/null | sort -V | tail -1)
VENDOR=$(ls -d "$BASE"/vendor/linux-llama-cuda12-vendor-* 2>/dev/null | sort -V | tail -1)
[ -n "$PACK" ]   || { echo "no CUDA12 llama.cpp pack under $BASE" >&2; exit 1; }
[ -n "$VENDOR" ] || { echo "no CUDA12 vendor runtime under $BASE/vendor" >&2; exit 1; }
export LD_LIBRARY_PATH="$PACK:$VENDOR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$PACK/llama-server" "$@"
```

Verify before going further:

```bash
~/.local/share/llama-router/scripts/llama-server-cuda --list-devices
# must print:  CUDA0: NVIDIA GeForce RTX ... (NNNNN MiB, ...)
```

## 4. The registry

`scripts/llama-models.yaml` opens with `defaults:` — point it at the shim and
the real models directory:

```yaml
defaults:
  server: /home/<you>/.local/share/llama-router/scripts/llama-server-cuda
  models_dir: /home/<you>/.lmstudio/models     # where the GGUFs actually are
  pid_dir: /tmp/opencode
```

Then one block per model (`gguf` is **relative to `models_dir`**), each model
getting both variants — `<id>` (parallel, own port) and `<id>-swap` (shared
port+group, one slot):

```yaml
  - id: 27b
    label: Qwen3.8 27B IQ3_XXS (parallel)
    gguf: unsloth/Qwen3.8-27B-GGUF/Qwen3.8-27B-UD-IQ3_XXS.gguf
    ctx: 81920
    port: 8083
    group: ""
    vram_mib: 11000
    cpu_moe: false
    ngl: 999
    kv: iq4_nl
    parallel: 1
```

`ctx` is the **verified** window, never the file's maximum. If the
client-facing name differs from the id, add it to `full_id()` in
`gen-llama-router-config.py` — that is the second place and the easy miss.

Check what actually resolves before trusting anything:

```bash
llama-models defaults          # server|models_dir|pid_dir
llama-models list              # every entry
llama-models verify            # ids unique, ggufs exist, ungrouped ports unique
find "$(llama-models defaults | cut -d'|' -f2)" -name "*.part"   # unfinished downloads
```

## 5. Put it on PATH

```bash
R=~/.local/share/llama-router/scripts
ln -sfn "$R/llama-router"    ~/.local/bin/llama-router
ln -sfn "$R/model-host.sh"   ~/.local/bin/model-host
ln -sfn "$R/llama-models.py" ~/.local/bin/llama-models
ln -sfn "$R/llama-server-cuda" ~/.local/bin/llama-server-cuda
ln -sfn "$R/llama-menu"      ~/.local/bin/llama-menu
ln -sfn "$R/swap-proxy"      ~/.local/bin/swap-proxy
```

## 6. Autostart (so clients never see a dead endpoint)

Without this, the router is up only while someone remembers to start it, and
clients (pi, opencode, Zed) get connection errors after every reboot.

`~/.config/systemd/user/llama-router.service`:

```ini
[Unit]
Description=llama-router — local GGUF model router on :8080 (machine property)
Documentation=file:///home/<you>/.local/share/llama-router/docs/LLAMA_CPP_SERVER.md
After=network.target

[Service]
Type=forking
PIDFile=/tmp/opencode/llama-router.pid
ExecStart=/home/<you>/.local/bin/llama-router start
ExecStop=/home/<you>/.local/bin/llama-router stop
Restart=on-failure
RestartSec=5
# Needs the GPU and the models under $HOME — do NOT copy the distro unit's
# ProtectHome=tmpfs sandbox, it cannot serve these models.
NoNewPrivileges=yes
TimeoutStopSec=20

[Install]
WantedBy=default.target
```

```bash
systemctl --user daemon-reload
systemctl --user enable --now llama-router
```

Notes:
- The router holds no VRAM until a request arrives, then keeps one model
  resident (`--models-max 1`) and sleeps it after the idle timeout.
- The distro ships `/usr/lib/systemd/user/llama-server.service` — it runs a
  **bare, CPU-only** server with no preset. Leave it **disabled**.
- To have it up before login (no graphical session needed), enable lingering:
  `sudo loginctl enable-linger $USER`.

## 7. Verification checklist

| # | Command | Expected |
|---|---|---|
| 1 | `llama-server-cuda --list-devices` | `CUDA0: NVIDIA GeForce RTX …` |
| 2 | `llama-models verify` | `✓ registry OK — N models` |
| 3 | `systemctl --user is-active llama-router` | `active` |
| 4 | `curl -s 127.0.0.1:8080/v1/models` | JSON list of the registered aliases |
| 5 | one real request | answer + a decode rate, and `nvidia-smi` util > 50 % |
| 6 | `nvidia-smi --query-gpu=memory.used --format=csv,noheader` after idle | back near the idle floor |

A request that returns text but leaves GPU utilisation at ~0 % means you are on
the CPU-only server — go back to §3.

Point clients at `http://127.0.0.1:8080/v1` (pi: a provider in
`~/.pi/agent/models.json` with a static `contextWindow` per model, because in
router mode `/v1/models` reports the real `n_ctx` only for the *resident*
alias).

## 8. Rollback

```bash
systemctl --user disable --now llama-router
rm -f ~/.config/systemd/user/llama-router.service ~/.local/bin/{llama-router,model-host,llama-models,llama-menu,swap-proxy}
rm -rf ~/.local/share/llama-router
```

Nothing else on the machine depends on the seat; the models themselves live in
the LM Studio folder and are untouched.

## 9. Maintaining the install

- Once installed, **day-to-day operation is not this skill's business.** The
  machine's manuals live with it: `~/.local/share/llama-router/docs/`
  (`LLAMA_CPP_SERVER.md`, `SYSTEM.md`, `llama-menu.md`, `swap-proxy.md`).
- Version drift to watch: LM Studio replaces its CUDA12 pack on update — the
  shim picks the newest automatically, but re-run checklist step 1 after an
  LM Studio upgrade.
- Re-run §7 after any change to the registry, the shim, or the unit.

## 10. Optional: serving a model on the INTERNAL GPU (Vulkan)

Only needed when the internal GPU is the target — e.g. the eGPU is detached, or
you want a small model resident on the iGPU while the XG Mobile serves the big
ones. The router's binary is CUDA-only, so it cannot reach an AMD or Intel iGPU;
install a second, Vulkan-backed endpoint instead.

### 10.1 The Vulkan shim

LM Studio ships a Vulkan llama.cpp build beside the CUDA one. `llama-server-vulkan`
in `scripts/` execs it, exactly as `llama-server-cuda` does for CUDA:

```bash
llama-server-vulkan --list-devices
#   Vulkan0: AMD Radeon Graphics (RADV RENOIR)  16254 MiB (shared RAM)  <- internal
#   Vulkan1: NVIDIA GeForce RTX 3080 Laptop GPU 16384 MiB               <- the eGPU
```

**Both GPUs appear**, so the device must always be pinned (`--device Vulkan0`).
Omitting it lets llama.cpp pick, which is how a "small internal model" ends up
fighting the eGPU for memory.

### 10.2 The launcher

`scripts/llama-igpu` serves one registry model on that device, on its own port
(`8097`), with its own alias — reading `gguf`, `ctx`, `ngl`, `kv` and `threads`
from the registry so there is still one source of truth:

```bash
llama-igpu start 4b     # default model: 4b
llama-igpu status
llama-igpu stop
llama-igpu log
```

On PATH via symlinks, alongside the rest:

```bash
R=~/.local/share/llama-router/scripts
ln -sfn "$R/llama-server-vulkan" ~/.local/bin/llama-server-vulkan
ln -sfn "$R/llama-igpu"          ~/.local/bin/llama-igpu
```

### 10.3 Why it is not in the router

Router mode spawns **one binary for all of its model presets**, and that binary
is the CUDA build. A Vulkan model therefore needs its own endpoint. The upside is
that the two do not compete: different devices, so both run at once — verified
with the router holding 6 aliases on the 3080 while `llama-igpu` served the 4B on
the AMD iGPU.

### 10.4 Verify

| # | Command | Expected |
|---|---|---|
| 1 | `llama-server-vulkan --list-devices` | lists `Vulkan0` (AMD) and `Vulkan1` (NVIDIA) |
| 2 | `llama-igpu start 4b` | `✓ loaded on Vulkan0`, serving on `:8097` |
| 3 | `curl -s 127.0.0.1:8097/v1/models` | the model's client-facing alias |
| 4 | one request | text back; on an iGPU expect ~10-13 t/s decode, ~130 t/s prefill for a 4B |

Measured reference on this host: Qwen3.5-4B Q4_K_S at its native 262,144 ctx on
the internal iGPU — prefill 128 t/s, decode 11.7 t/s, 15 GiB of 30 GiB RAM.

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
