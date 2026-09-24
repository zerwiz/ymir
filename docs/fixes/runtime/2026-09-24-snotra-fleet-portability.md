## runtime · 2026-09-24 — Snotra on every seat, and the install road

*Appended to the first Snotra note (`2026-09-24-snotra-meeting-ear.md`), not a
rewrite of it.*

### Why
The first landing gave the ear to heimdall: the MCP face and the unit were
materialized by `bin/fleet-ensure.sh`, but the **transcription engine had no
ensure step** and the capture/transcribe commands were not materialized. The
Allfather asked whether this was functional *on installations* — it was not.

### What landed
- **`bin/snotra-ensure.sh`** (new) — reports the seat's whisper engine + model
  and installs what is missing. Per-OS: `pacman -S whisper-cpp` (Arch/omarchy),
  `apt-get install whisper.cpp` (Debian), else build-from-source guidance. Model
  fetched from the whisper.cpp Hugging Face release; a voxtype seat keeps its
  models. `status` / `ensure [--install]` / `install`.
- **`bin/ymir-install.sh`** — `step_snotra` ("the meeting ear") registered in the
  run list; `STEP_TOTAL` 23 → 24. A fresh install now ensures the engine.
- **`bin/eir-doctor.sh`** — the `snotra` surface (`s_snotra` / `f_snotra`),
  composed with the other ensure scripts.
- **`bin/fleet-ensure.sh`** — materializes `snotra-capture.sh`,
  `snotra-transcribe.sh`, `snotra-ensure.sh` and `runes-append.sh` into
  `~/.fleet`, so any seat runs them without a repo checkout on its PATH.
- **`bin/snotra-transcribe.sh`** — portable engine discovery (env → PATH → the
  fleet's build trees → `voxtype transcribe`); 16 kHz mono normalisation;
  `LD_LIBRARY_PATH` set for a build-tree binary (whynot's `libwhisper.so.1` is
  not system-wide); GPU/CPU chosen by free VRAM, with a CPU retry on GPU failure.
- **`bin/snotra-capture.sh`** — the duration bug fixed (see below); `-t` is now
  an output option with a default safety cap; stale `state/.snotra-*` markers are
  cleared on start; `devices` subcommand added.

### The capture bug (and the accidental recording)
The first capture test wrote a **259 MB, 22-minute** WAV. `-t` had been placed as
an *input* option, so it limited only the first of two inputs, and
`amix(duration=longest)` waited forever on the unbounded second. `-t` is now an
output option, and a capture with no explicit duration carries
`SNOTRA_MAX_SECONDS` (default 4 h). The accidental recording was deleted from all
three seats; no capture process remained.

### The seats (measured)
| seat | engine | model | install |
|---|---|---|---|
| heimdall | `~/whisper.cpp.src/build/bin/whisper-cli` (CUDA) | `~/whisper.cpp/models/ggml-small.en.bin` | none needed |
| whynot | `~/whisper.cpp/build/bin/whisper-cli` (CUDA) | `~/whisper.cpp/models/ggml-small.en.bin` | none needed |
| omarchy | `/usr/bin/whisper-cli` (CPU) | `~/.local/share/voxtype/models/ggml-small.en.bin` | `extra/whisper-cpp` 1.9.3-1 |

omarchy already had whisper **inside `voxtype`** (models + `voxtype transcribe` +
a full `voxtype meeting` mode); `extra/whisper-cpp` was seated only for a uniform
CLI. No duplicate engine was vendored.

Proven end-to-end on all three seats: a real speech WAV transcribed and
summarised on heimdall, whynot and omarchy.

### Files
- `bin/snotra-ensure.sh` (new)
- `bin/snotra-capture.sh`
- `bin/snotra-transcribe.sh`
- `bin/fleet-ensure.sh`
- `bin/ymir-install.sh`
- `bin/eir-doctor.sh`
- `.agents/skills/galdr-ymirsystem/assets/snotra-meeting-ear.md`
- `.agents/skills/galdr-ymirsystem/assets/installation.md`
