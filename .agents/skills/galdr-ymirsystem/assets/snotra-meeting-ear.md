# Snotra — the meeting ear (Galdr asset)

**Role:** The meeting ear — captures, transcribes, and stores meeting minutes
privately in the hoard. Named for Snotra, the wise one, mistress of counsel.

## Architecture

```
THE DOOR (front)        the heart (zerwizserver): the MCP face on :8321 —
                        minutes + the fleet's hearing door. NEVER the whisper
                        engine: the heart's GPU cannot run it (plan 51 Part 9a).
THE HEARING (engine)    a STRONG box — heimdall (A5000, CUDA) first, then whynot
                        (forge; CPU until its CUDA build is arch-mended), then
                        omarchy. Served by whisper.cpp's own `whisper-server` on
                        :8322; the door resolves whichever is LIVE per request
                        (Part 9c: a dropped box is a reroute, never an outage).
THE CAPTURE (ear out)   the seat in the meeting — PipeWire mic + monitor. Only a
                        seat with a mic can do this (heimdall today, omarchy too).
THE BRAIN (summaries)   the fleet's rail (heimdall/omarchy MagicDNS) for minutes
                        summaries; a weak seat never runs inference, it calls the lane.
THE RECORD (store)      the heart — minutes in the vault, served by the MCP face.
```

**The door/engine split (2026-09-27).** Before this, `snotra.service` was a
single read-only minutes face wherever it ran, and the transcription engine was
assumed local. Plan 51 Part 9a forbids that: the heart runs the RECORD and small
programmes only. So the ear became a service of its own on a strong box
(`snotra-ear.service`, `:8322`) and the door gained the hearing
(`snotra_transcribe`, `snotra_ear`) with a LIVE resolution over the fleet
registry's `ear` row.

**Cost if run otherwise:** transcribing on the heart is not a slowdown — it is
a failure (its GPU cannot load the kernels). On whynot's P2000 the seat's ear is
already CPU-bound (see the engine matrix); it works, at CPU speed.

## Components

### M1 — Fleet tool (`tools/snotra/`)

- `server.mjs` — MCP server (streamable HTTP, port 8321): read-only minutes
  (`snotra_list`, `snotra_read`, `snotra_search`, `snotra_summary`), the ear
  door (`snotra_transcribe`: base64 clip → the live strong box), and
  (`snotra_ear`: where the hearing stands right now)
- Materialized into `~/.fleet/snotra-server.mjs` by `bin/fleet-ensure.sh`
- The operator commands (`snotra-capture.sh`, `snotra-transcribe.sh`,
  `snotra-ensure.sh`, `snotra-ear.sh`, `runes-append.sh`) are materialized into
  `~/.fleet` too
- Ear resolution: `fleet.json`'s `ear` row (names) × each host's own address ×
  `SNOTRA_EAR_PORT` (default 8322) → `GET /health` in order → first live box
  serves. A box whose POST fails is ejected for `SNOTRA_EAR_EJECT_MS` (60 s) and
  the next live box takes the request — a health check alone is not proof the
  engine can hear
- Pinned version: Meetily-Local AppImage (see fetch below)

### M1b — The ear service (`bin/snotra-ear.sh` + `tools/mill/systemd/snotra-ear.service`)

- Owed by CAPABILITY, not role: raised where a whisper engine **and** a model
  exist (`snotra-ear.sh status`), so the heart reports a clean skip and never
  loads whisper
- Runs upstream `whisper-server -m <model> --host 0.0.0.0 --port 8322 --convert`
  (`GET /health`, `POST /inference`, multipart `file`) — no bespoke engine
- Device by free VRAM (`SNOTRA_EAR_GPU=off` forces the CPU); a build-tree binary
  gets `LD_LIBRARY_PATH` set to its own directory
- Reached over the tailnet (`http://<seat>.tailefab81.ts.net:8322`); the port is
  not opened beyond the tailnet
- Commands: `snotra-ear.sh serve` (the unit's ExecStart) · `status` · `probe`

### M0 — the engine ensure (`bin/snotra-ensure.sh`)

- Reports the seat's engine + model; installs what is missing
- Per-OS: `pacman -S whisper-cpp` (Arch/omarchy), `apt-get install whisper.cpp`
  (Debian), else build-from-source guidance
- Model fetched from the whisper.cpp Hugging Face release; a voxtype seat keeps
  its models
- Wired into `bin/ymir-install.sh` (`step_snotra`) and `bin/eir-doctor.sh`
  (`snotra` surface)

### M2 — Systemd unit (`tools/mill/systemd/snotra.service`)

- User unit, `WantedBy=ymir.target` — it joins the ONE target the install enables
  once, and boot pulls the whole role set (the auto-boot law). NOT `default.target`,
  which was the pre-autoboot contract.
- Runs `node ~/.fleet/snotra-server.mjs` on port 8321
- Depends on `$YMIR_HOME` being mounted (the hoard)

### M3 — Capture road (`bin/snotra-capture.sh`)

- `start` — PipeWire mic + system monitor → dated WAV under the hoard
- `stop` — kills the ffmpeg process
- `status` — shows PID and listening indicator state
- Listening indicator: writes `state/.snotra-listening` (value: `recording`)
  so the bar can display it alongside ScreenRecording and Dictation

### M4 — Minutes into the vault (`bin/snotra-transcribe.sh`)

- Transcribes WAV with whisper.cpp (local GPU)
- Produces structured Markdown minutes
- Stores under `$YMIR_HOME/hodd/workspaces/meetings/`
  (the workspaces shelf: meetings are work-adjacent artifacts that follow the
  operator across domains; the hoard's `workspaces/` is the natural home)
- Appends a Rune via `bin/runes-append.sh`

### M5 — MCP face (`tools/snotra/server.mjs`)

- Read-only tools: `snotra_list`, `snotra_read`, `snotra_search`, `snotra_summary`
- The hearing: `snotra_transcribe` (a short clip, base64) and `snotra_ear` (the
  live seat + health) — the door fronts, the strong box hears
- Resource: `snotra://ear` (meeting count + where the ear stands)
- StreamableHTTP transport (mirrors `tools/tickets-mcp`)
- Wired into seat MCP config by `fleet-ensure.sh` (port 8321); on a non-heart
  seat the URL resolves to the heart's tailnet door

### M6 — Summaries on the local rail

- Uses the machine's own llama-swap rail (`http://127.0.0.1:8080/v1`)
- Model: `qwen3.6-35b-a3b@q2_k_xl` (the resident model on heimdall)
- No cloud key needed — the rail key is resolved from `~/.pi/agent/auth.json`

### M7 — The proof

- A real 5-minute capture end-to-end: captured, transcribed, minutes written,
  Rune appended, MCP query answered
- Evidence pasted in the PR body (transcript content redacted)

### M8 — The record

- Fix note under `docs/fixes/runtime/`
- This asset updated in the same change
- `compliance-check.sh` clean

## Private data

Audio recordings, transcripts, and meeting content are **private data**. They
live under `$YMIR_HOME/hodd/workspaces/meetings/` and are never committed to
the public repo. The repo carries only the wiring scripts and the MCP server.

## First Law compliance

- No participant names in the repo
- No meeting content in the repo
- No audio files in the repo
- The hoard is the vault; the repo is the wiring

## The fleet's engines (measured 2026-09-24; ear service + whynot CUDA finding 2026-09-27)

| seat | engine | model | notes |
|---|---|---|---|
| heimdall | `~/whisper.cpp.src/build/bin/whisper-cli` + `whisper-server` (CUDA) | `~/whisper.cpp/models/ggml-small.en.bin` | the prime ear (A5000); `snotra-ear.service` serves `:8322` on CUDA |
| whynot | `~/whisper.cpp/build/bin/whisper-cli` + `whisper-server` (CUDA, **P2000-arch broken**) | `~/whisper.cpp/models/ggml-small.en.bin` | needs `LD_LIBRARY_PATH`; its CUDA build carries **no kernel image for compute 6.1** and ABORTS on inference, so the ear runs CPU-bound via a seat drop-in (`SNOTRA_EAR_GPU=off`) until rebuilt with `GGML_CUDA_ARCHS=61` |
| omarchy | `/usr/bin/whisper-cli` (CPU, `extra/whisper-cpp`) | `~/.local/share/voxtype/models/ggml-small.en.bin` | voxtype also has a full `meeting` mode; a CPU ear for the live set |
| zerwizserver | — | — | the heart: fronts the door (`:8321`), never the ear (plan 51 Part 9a) |

The transcribe script discovers the engine (env → PATH → build trees →
`voxtype transcribe`), normalises to 16 kHz mono, sets `LD_LIBRARY_PATH` for a
build-tree binary, and picks GPU vs CPU by free VRAM (a driverless seat's
`nvidia-smi` complaint is filtered, never compared as a number).

## Dependencies

- **PipeWire** (system audio capture) — already present on Omarchy
- **ffmpeg** (audio recording) — already present
- **whisper.cpp** (transcription) — already built on heimdall
- **llama-swap** (summarization) — already running on the rail
- **Node.js** (MCP server) — already available
- **bun** (optional, for faster startup) — already installed on seats

## Meetily-Local integration (future)

Meetily-Local (`github.com/Hankanman/Meetily-Local`) is the recommended engine
for the capture phase. The AppImage can be fetched from upstream releases:

```bash
# Pin the version (update this when a new release is verified)
SNOTRA_VERSION="0.1.0"
curl -L -o ~/.fleet/meetily-local.AppImage \
  "https://github.com/Hankanman/Meetily-Local/releases/download/v${SNOTRA_VERSION}/meetily-local-${SNOTRA_VERSION}-linux-x86_64.AppImage"
```

The AppImage is not vendored into the repo (100+ MB). A checksummed fetch from
the upstream release is the chosen path — it keeps the repo lean and the
version pinned. The ensure script can include this fetch step.

## Naming

- **Snotra** — the meeting ear (wise one, mistress of counsel)
- The MCP face is the **door** (the heart's address agents call)
- The served engine (`snotra-ear.sh` / `snotra-ear.service`) is the **hearing**
  (the strong box that actually transcribes)
- The capture is the **ear** (hears the meeting)
- The transcription is the **brain** (processes what was heard)
- The minutes are the **record** (what was decided)
- The MCP face is the **voice** (speaks the record to agents)
