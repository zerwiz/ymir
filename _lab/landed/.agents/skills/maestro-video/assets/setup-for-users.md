# Standing Maestro up for a user — Ymir's provision road

**What this is:** the road Ymir walks when a seat has *no* video forge and the
operator wants one. It detects the machine, installs the app, raises it as a
**user unit on `ymir.target`**, declares which model families that seat should
fetch, proves the door answers, and keeps it **private**. It is written to be run
by an agent (`bin/maestro-ensure.sh`) and read by a human.

Nothing here is inferred from the forge's own docs: the install path, the unit
shape and the two faults below were measured on a live seat running Maestro
**v2.4.2** with one video family resident.

---

## 0. The law before the road: the forge rides the strong box

Ymir's compute boundary (plan 51 **Part 9a**) is explicit, and it decides *where*
a forge may live before any install begins:

> The heart's duty is the RECORD and the PROGRAMMES that are small on CPU; it is
> **not** a compute seat. **A weak seat never runs inference; it calls the lane.**

```
where_the_forge_may_live[3]{seat,verdict,why}:
  "heart (the record seat)","NEVER","its CPU runs git ops, the crons, the MCP faces and the ledger — a video diffusion model would starve the record"
  "forge / dev (a seat with a real GPU)","YES — this is the home","model serving and GPU compute are the forge's declared duty"
  "a weak seat with an old GPU","NO — call the lane instead","a caption-class GPU (e.g. a GTX 770M) cannot run these models; the seat reaches the rail over the tailnet and Maestro runs where the silicon is"
```

**Consequence:** step 1 is a **hard gate**, not a suggestion. If the box fails it,
stop and report — never install a forge that cannot generate.

## 1. Detect the box (the gate)

Before anything is installed, ask the machine. Two ways — the first needs no
Maestro at all:

```bash
# A. no forge required — the raw truth
nvidia-smi --query-gpu=name,memory.total,compute_cap,driver_version --format=csv
nvidia-smi --query-gpu=memory.used --format=csv         # is the GPU already busy?
df -h "$HOME"                                            # tens of GB are needed
```

```bash
# B. once a forge answers, let it judge itself
curl -s http://127.0.0.1:8761/api/v1/system-detect | python3 -m json.tool
curl -s http://127.0.0.1:8761/api/v1/system/preflight
```

`system-detect` returns `hardware{cuda_available, gpu_name, gpu_vram_gb,
gpu_capability, ram_gb, ram_tier, vram_tier, supports_fp8, supports_nvfp4,
supports_sage, supports_flash}` and a `recommended{}` profile block. Read
`gpu_capability` — it drives the install — and `vram_tier` — it drives what may
be asked of the seat.

```
gate[4]{check,pass,why}:
  "cuda_available","true","no CUDA means no diffusion; a CPU forge is not a forge"
  "gpu_capability","sm_80 or newer (fp8/nvfp4 paths want sm_89+)","the installer picks the runtime from this; an old capability class silently gets the legacy stack"
  "gpu_vram_gb","≥ 12 GB usable, 16 GB comfortable","a 22B video family at INT8 plus its text encoder is tens of GB; VRAM decides what fits resident"
  "free disk","≥ 80 GB for a first video family + encoder","a single video family measured ~49 GB on disk before the planner LLM"
```

Also confirm no other heavy job holds the card (`memory.used`). A resident
`llama-server` on a peer port can be holding most of a 16 GiB device and will
make every timing — and possibly every load — wrong.

## 2. Install the app

Maestro ships as a **Pinokio** application: `install.js`, `start.js` and
`torch.js` at the repo root are Pinokio kernel scripts, not shell. Pinokio is
not installed on a headless Ymir seat, so the install is **reproduced by hand,
following those files step for step** — read them, do not guess:

```
install_steps[6]{step,what,note}:
  "venv","uv venv --python <3.10|3.11> app/env","the script's Python choice follows the GPU's capability class; the README's newer Python is not universal"
  "deps","uv pip install -r app/requirements.txt --index-strategy unsafe-best-match","309 packages measured"
  "torch","torch/torchvision/torchaudio + xformers from the cuXXX index for THIS card","torch 2.7.x + cu128 measured on an sm86 card"
  "attention","the prebuilt attention wheel matching the python/torch/cuda triple","sageattention + flash-attn; a mismatch builds from source and can fail"
  "gguf kernels","app/scripts/install_gguf_kernels.py","a SOFT no-op on older python/torch; recorded, not fixed — GGUF variants dequantize on CPU"
  "ui","cd app/ui && npm install && npm run build","the SPA must be built or the door serves nothing to a browser"
```

Two install traps that cost hours and are worth pre-empting:

- **`UV_HTTP_TIMEOUT=300`** before the torch/CUDA wheels — the large
  `nvidia-*-cuXX` wheels time out at the default retry budget.
- **Hugging Face `hf_xet` can stall on multi-GB files** with the process still
  alive and mtimes updating. A resumable `curl -C - --speed-limit … --speed-time
  …` fetcher is more reliable here than the client, and a stalled transfer must
  be dropped and resumed rather than waited on. Judge progress over ≥60 s.

The installer resolves the runtime from the GPU. On an older card
(`isSolCapable() == false`) it takes the **legacy CUDA profile** — correct for
that card, and not the newer high-capability engine. Do not "upgrade" a working
legacy stack to match a README.

## 3. Raise it as a user unit on `ymir.target`

The template ships in this skill:
**`assets/maestro.service`** — the `tools/mill/systemd` shape
(`WantedBy=ymir.target`, `Restart=always`, the environment block). Render it to
the real paths, then:

```bash
install -Dm644 assets/maestro.service ~/.config/systemd/user/maestro.service
systemctl --user daemon-reload
systemctl --user enable --now maestro.service
systemctl --user is-active maestro.service        # → active
systemctl --user status  maestro.service --no-pager
```

`ymir.target` is the fleet's **one** user target: the install enables it once and
boot pulls every role-owed program. A forge that is `WantedBy=default.target`
instead is a forge that starts on every login whether or not the role wants it —
join the target, not the login.

**The two lines in the unit that prevent real faults:**

| line | without it |
|---|---|
| `Environment=MAESTRO_LLAMA_BIN=<dir with a CUDA llama-server>` | the planner finds no server where it looks and **compiles llama.cpp from source** (~355 nvcc objects, ~15 min), usually failing with `RuntimeError: Linux CUDA llama-server compilation failed`. The escape hatch is documented in `app/services/llama_linux_runtime.py`. |
| `Restart=always` + `TimeoutStartSec=900` | systemd's default start timeout kills the forge during its first multi-minute model load, and the seat reports a failure that never happened. |

The unit also carries the **model shelf**: the app resolves `checkpoints_paths`,
`save_path`, `image_save_path`, `audio_save_path` and `loras_root` **relative to
`WorkingDirectory`** (see `app/wgp_config.json`). That is why `WorkingDirectory`
must be the real `app/` — a wrong one makes the forge re-download every family
into a fresh tree. `MAESTRO_LLM_CACHE` points the planner's GGUF cache at its own
shelf. Keep **all** of it outside any repo: models and outputs are machine data,
never public artifacts.

## 4. Declare which families this seat fetches

Do **not** fetch 200 models. A seat declares the families its work needs, and the
forge downloads on demand. Declare through the API so the running server and the
file agree (`GET,PUT /api/v1/model-visibility`, mirrored into
`app/wgp_config.json` → `maestro_model_visibility.enabled_models`):

```bash
curl -s "$B/api/v1/model-visibility"                       # what this seat shows today
curl -s -X PUT "$B/api/v1/model-visibility" -H 'Content-Type: application/json' \
     -d '{"enabled_models":["<model_type>","<model_type>"]}'
curl -s -X POST "$B/api/v1/models/<model_type>/download"    # fetch one, explicitly
curl -s "$B/api/v1/models/downloads/status"                 # watch it land
```

A sensible starting declaration per seat role:

```
declare[3]{role,suggested_families,why}:
  "a solo creator seat","one general t2v/i2v family + one image family","one resident model is the law; a family per purpose is enough to work"
  "a marketing seat","the same, plus a music/audio family","score and voice work ride the audio path"
  "a seat that only ever edits","one i2v/control family, no t2v","fetch what the work is, not what the catalogue holds"
```

Whatever is declared, the **one-resident-model** law still holds: a video job
evicts the last. Declare breadth for *choice*, not for concurrency.

## 5. Verify the door — the exact curl

The seat is provisioned when the API answers **and** the machine is sound:

```bash
curl -sf http://127.0.0.1:8761/api/v1/models >/dev/null \
  && echo "maestro door: UP"
curl -s  http://127.0.0.1:8761/api/v1/system/preflight   # want {"ok":true,"checks":[]}
curl -s  http://127.0.0.1:8761/api/v1/models/downloads/status
```

A `200` from `/api/v1/models` is the single proof the forge is up; `preflight`
is the proof it is *well*. If the door answers but a job fails, read the failing
job's `message` and the seat's log before touching configuration — the fault is
usually environmental (the planner build above) and already named.

## 6. The privacy rule — loopback, and nothing else

**The forge is unauthenticated.** There is no login on `/api/v1`; whoever reaches
the port can generate, download tens of GB, and read every output on the seat.

```
privacy[4]{rule,why}:
  "bind loopback","SERVER_NAME=127.0.0.1 — the unit's default. Never 0.0.0.0 on a shared or untrusted network"
  "never a tunnel","no Cloudflare tunnel, no public hostname, no port-forward to :8761 — a public door to an unauthenticated generator is a public GPU bill and a public read of your outputs"
  "if a seat must reach it remotely","ride the private overlay deliberately and firewall the port to that interface only; that is a decision the operator makes, documented, never a default the installer takes"
  "outputs are private","generated media and prompts are machine data — they live under the operator's home, never in a public repo"
```

An operator who deliberately widens the bind on their **own** box may do so; the
provision road must not do it for them.

## 7. The ensure seam — how the fleet step seats this

The unit and the road above are made callable by a **script skeleton** so a fleet
step can seat a forge without an agent re-deriving all of it:

```
seam[3]{piece,path,what}:
  "the ensure","bin/maestro-ensure.sh","status | detect | ensure [--install] | verify — detects the GPU, renders+seats the unit, proves /api/v1/models, and REFUSES on a GPU-less box or a missing CUDA llama-server"
  "the unit template",".agents/skills/maestro-video/assets/maestro.service","the systemd user unit the ensure renders (WantedBy=ymir.target, Restart=always, env block)"
  "the craft",".agents/skills/maestro-video/SKILL.md","how an agent drives the door once it is up"
```

`bin/maestro-ensure.sh detect` is the gate; `ensure` is the raise; `verify` is
the proof a supervisor can call and trust. The script follows the house ensure
conventions (idempotent, TOON status out, loud refusals, never a silent skip) so
`bin/eir-doctor.sh` and the install steps can compose it the way they compose
every other `*-ensure.sh`.

**A seat that already has a forge is left alone.** `ensure` adopts a running door
rather than fighting it — the same doctrine as the local-model ensure, which
adopts a standing CUDA `llama-server` and never rebuilds one.
