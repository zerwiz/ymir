## runtime · 2026-09-24 — Snotra, the meeting ear

### Why
Meetings leave no record on this machine. Google Meet, Zoom, and Teams each hold
their own; neither follows the operator across platforms nor writes the record
into the hoard where the fleet's agents can read it.

### What was built
- **`tools/snotra/`** — the MCP face (read-only minutes access, streamable HTTP,
  port 8321). Tools: `snotra_list`, `snotra_read`, `snotra_search`, `snotra_summary`.
  Resource: `snotra://ear`.
- **`tools/mill/systemd/snotra.service`** — user unit, `WantedBy=default.target`,
  joins the auto-boot law. Runs `node ~/.fleet/snotra-server.mjs`.
- **`bin/snotra-capture.sh`** — PipeWire mic + system monitor capture. Writes
  dated WAV to the hoard. Listening indicator via `state/.snotra-listening`.
- **`bin/snotra-transcribe.sh`** — whisper.cpp transcription (local GPU),
  structured Markdown minutes, Rune appended.
- **`bin/fleet-ensure.sh`** — updated to materialize `snotra-server.mjs`,
  wire `snotra` into the seat's `mcp.json`, and raise the unit.
- **`.agents/skills/galdr-ymirsystem/assets/snotra-meeting-ear.md`** — owning
  Galdr asset.
- **`AGENTS.md`** — `governed[]` updated (9 paths now).

### Architecture
```
THE EAR (capture)      the meeting seat — PipeWire mic + monitor
THE BRAIN (transcribe) the GPU seat — whisper.cpp CUDA
THE RECORD (store/serve)  the heart — minutes in the vault, MCP face
```

If transcribing on whynot (P2000), it costs a 3-5× slowdown (no CUDA) and
requires transferring the recording. Configurable via `WHISPER_GPU=off`.

### Files
- `tools/snotra/server.mjs`
- `tools/mill/systemd/snotra.service`
- `bin/snotra-capture.sh`
- `bin/snotra-transcribe.sh`
- `bin/fleet-ensure.sh` (updated)
- `AGENTS.md` (governed[] updated)
- `.agents/skills/galdr-ymirsystem/assets/snotra-meeting-ear.md`
