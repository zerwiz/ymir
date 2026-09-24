# Snotra — the meeting ear (Galdr asset)

**Role:** The meeting ear — captures, transcribes, and stores meeting minutes
privately in the hoard. Named for Snotra, the wise one, mistress of counsel.

## Architecture

```
THE EAR (capture)      the seat in the meeting — heimdall today, omarchy too
                       PipeWire mic + monitor capture. Nothing else can do this.
THE BRAIN (transcribe) the seat with the GPU — heimdall's RTX A5000
                       whisper.cpp CUDA (~1.0s) + local rail for summaries
THE RECORD (store/serve)  whynot, the heart — minutes in the vault, synced by
                       the home's git road, the MCP face served there
```

**Cost if run otherwise:** If the Allfather insists on transcribing on whynot
(the P2000), it costs a 3-5× slowdown on transcription (P2000 lacks CUDA
acceleration for whisper) and requires the recording to be transferred from the
meeting seat to whynot first. The configuration change is a single env var:
`WHISPER_GPU=off` and `WHISPER_MODEL` pointing to a CPU model. The design
supports this; it is not a rewrite.

## Components

### M1 — Fleet tool (`tools/snotra/`)

- `server.mjs` — MCP server (read-only minutes access, streamable HTTP, port 8321)
- Materialized into `~/.fleet/snotra-server.mjs` by `bin/fleet-ensure.sh`
- Pinned version: Meetily-Local AppImage (see fetch below)

### M2 — Systemd unit (`tools/mill/systemd/snotra.service`)

- User unit, `WantedBy=default.target` (the auto-boot law)
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
- Resource: `snotra://ear` (meeting count)
- StreamableHTTP transport (mirrors `tools/tickets-mcp`)
- Wired into seat MCP config by `fleet-ensure.sh` (port 8321)

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
- The capture is the **ear** (hears the meeting)
- The transcription is the **brain** (processes what was heard)
- The minutes are the **record** (what was decided)
- The MCP face is the **voice** (speaks the record to agents)
