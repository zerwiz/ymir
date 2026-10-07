# Snotra — the meeting ear (Galdr asset)

**Role:** The meeting ear — captures, transcribes, and stores meeting minutes
privately in the hoard. Named for Snotra, the wise one, mistress of counsel.

## Architecture

```
THE WATCH (detect)     a CALL SEAT — any seat with a microphone. Watches PipeWire
                       for an app taking the mic, arms the capture of the
                       conversation pair, and leaves when the room empties.
                       Raised by CAPABILITY, never by role.
THE EAR (capture)      the seat in the meeting — heimdall today, omarchy too
                       PipeWire mic + monitor capture. Nothing else can do this.
THE BRAIN (transcribe) the seat with the GPU — the living-rail resolver's
                       serving box (heimdall's <gpu> first, then whynot)
                       whisper.cpp CUDA (~1.0s) + the LIVE rail for summaries
THE RECORD (store/serve)  the heart (zerwizserver) — minutes in the vault, synced
                       by the home's git road, the MCP face served there
```

**The watch is the half that makes the ear automatic.** Before it, a meeting was
heard only if a hand armed the capture; now the microphone is the signal — a
voice call cannot happen unless the call application opens a capture stream on a
microphone — and the moment the room empties the ear leaves.

**Cost if run otherwise:** If the Allfather insists on transcribing on whynot
(the <gpu>), it costs a 3-5× slowdown on transcription (<gpu> lacks CUDA
acceleration for whisper) and requires the recording to be transferred from the
meeting seat to whynot first. The configuration change is a single env var:
`WHISPER_GPU=off` and `WHISPER_MODEL` pointing to a CPU model. The design
supports this; it is not a rewrite.

## Components

### M1 — Fleet tool (`tools/snotra/`)

- `server.mjs` — MCP server (read-only minutes access, streamable HTTP, port 8321)
- Materialized into `~/.fleet/snotra-server.mjs` by `bin/fleet/fleet-ensure.sh`
- The operator commands (`snotra-capture.sh`, `snotra-transcribe.sh`,
  `snotra-detect.sh`, `snotra-mine.sh`, `snotra-ensure.sh`, `runes-append.sh`)
  are materialized into `~/.fleet` too — **with `hoard-lib.sh` beside them**: each
  of them resolves the operator's home through it, and a seat that has the
  command without the resolver dies on an unbound `YMIR_HOME` the moment it runs
  outside a shell that already knew the home
- Pinned version: Meetily-Local AppImage (see fetch below)

### M0 — the engine ensure (`bin/time/snotra/snotra-ensure.sh`)

- Reports the seat's engine + model; installs what is missing
- Per-OS: `pacman -S whisper-cpp` (Arch/omarchy), `apt-get install whisper.cpp`
  (Debian), else build-from-source guidance
- Model fetched from the whisper.cpp Hugging Face release; a voxtype seat keeps
  its models
- Wired into `bin/engine/ymir-install.sh` (`step_snotra`) and `bin/agents/eir-doctor.sh`
  (`snotra` surface)

### M2 — Systemd unit (`tools/mill/systemd/snotra.service`)

- User unit, `WantedBy=ymir.target` — it joins the ONE target the install enables
  once, and boot pulls the whole role set (the auto-boot law). NOT `default.target`,
  which was the pre-autoboot contract.
- Runs `node ~/.fleet/snotra-server.mjs` on port 8321
- Depends on `$YMIR_HOME` being mounted (the hoard)

### M3 — Capture road (`bin/time/snotra/snotra-capture.sh`)

- `start` — PipeWire mic + system monitor → dated WAV under the hoard
- `stop` — kills the ffmpeg process
- `status` — shows PID and listening indicator state
- Listening indicator: writes `state/.snotra-listening` (value: `recording`)
  so the bar can display it alongside ScreenRecording and Dictation

### M4 — Minutes into the vault (`bin/time/snotra/snotra-transcribe.sh`)

- Transcribes WAV with whisper.cpp (local GPU)
- Produces structured Markdown minutes
- Stores under `$YMIR_HOME/hodd/life/meetings/`
  (the workspaces shelf: meetings are work-adjacent artifacts that follow the
  operator across domains; the hoard's `workspaces/` is the natural home)
- Appends a Rune via `bin/records/runes-append.sh`

### M5 — MCP face (`tools/snotra/server.mjs`)

- Read-only tools: `snotra_list`, `snotra_read`, `snotra_search`, `snotra_summary`
- Resource: `snotra://ear` (meeting count)
- StreamableHTTP transport (mirrors `tools/tickets-mcp`)
- Wired into seat MCP config by `fleet-ensure.sh` (port 8321)

### M6 — Summaries on the living rail

- Rides the ONE resolver (`bin/model/rail-resolve.sh`, `src/ymir_runtime/fleet/rail.py`, plan 51 Parts 9a/9c): the serving strong box's `http://<box>:8080/v1`, first-alive — a dropped box reroutes, never an outage
- `RAIL_URL` forces one specific rail when set; unset, the resolver's serving box wins (the ear's summaries ride whichever strong box is CONNECTED)
- Model: resolved from the hoard/env (`RAIL_MODEL`; unset = loud refusal — the tree carries no concrete model id)
- No cloud key needed — the rail key is a REFERENCE (env `LLAMA_SWAP_API_KEY` → the hoard vault → `~/.pi/agent/auth.json`), never a value in the tree

### M7 — The proof

- A real 5-minute capture end-to-end: captured, transcribed, minutes written,
  Rune appended, MCP query answered
- Evidence pasted in the PR body (transcript content redacted)

### M8 — The record

- Fix note under `docs/fixes/runtime/`
- This asset updated in the same change
- `compliance-check.sh` clean

### M9 — The watch (`bin/time/snotra/snotra-detect.sh`)

- `run` — the standing watch (the unit's `ExecStart`); `status` — TOON row;
  `scan` — the PipeWire picture, once; `once` — one scan and act
- `arm [slug]` / `leave` — the manual doors, for a call the detector cannot see
- **The START edge.** A NEW record stream on a non-monitor source, sustained for
  `SNOTRA_ARM_DEBOUNCE` (3 s). The graph is read through the portable `pactl`
  surface (PipeWire serves the PulseAudio protocol on every seat), one snapshot
  per tick emitting tab-separated records for sources, source-outputs, sinks and
  sink-inputs. A stream **already open when the watch started is not a call** —
  the watch takes a baseline at start, because Discord holds the microphone open
  while idle on a real seat. A second signal covers an app that already holds the
  mic: a NEW playback stream from that same app is the remote side beginning.
- **The conversation pair.** At arm the watch resolves the microphone the call
  app is actually reading and the SINK the call itself is playing into (the sink
  its playback stream rides, falling back to the default sink), and arms the
  capture with that pair — so both sides are heard. No loopback module, no
  virtual device: the pair is resolved from the graph.
- **The LEAVE edge.** Three independent signs, first to fire:

```
leave_edges[4]{id,sign,default}:
  "L1","every stream that armed the ear is gone (sustained)","SNOTRA_RELEASE_GRACE=5s"
  "L2","the conversation's sink left the graph","—"
  "L3","mic AND monitor below a dB floor, sustained","SNOTRA_SILENCE_DB=-45 · SNOTRA_SILENCE_SECONDS=300"
  "L4","the capture's own safety cap","SNOTRA_MAX_SECONDS=14400"
```

- **The ear never lingers.** `do_arm` refuses to arm while a capture is already
  alive (one ear at a time), and `stop_lingering_captures` kills any ffmpeg still
  writing into the meetings shelf at leave and at start-up — so a lost pid, a
  crash or a restart can never leave a recording running.
- **The anti-flap quiet.** After a meeting closes the watch re-baselines and arms
  nothing for `SNOTRA_COOLDOWN` (30 s): a meeting's own end can raise a
  microphone (a notification's sound, an app closing its device), and a watch
  that re-armed on that would deliver forever.

### M10 — The pipeline and the delivery (at leave)

Stop the capture → transcribe through the seat's whisper (the same engine the ear
serves) → mine → write → deliver:

- `<date>-<lane>-<slug>.md` — the dated minutes (lane default `ping`)
- `<date>-<lane>-<slug>.actions.md` — the mined decisions and actions
- `<date>-<lane>-<slug>.transcript.txt` — the transcript with its timestamps
- `<date>-<lane>-<slug>.wav` — the recording
- **delivery**: `bin/time/snotra/ymir-say.sh --mark-done` (a desktop note) AND a durable wake
  through the queue's own door — `bin/records/ymir-state.sh queue append check
  "meeting:<slug>" "check: …"` — so the meeting reaches Brokk with no arm and no
  sweep. The append is **bounded** (`timeout 20`): no queue pathology may wedge a
  delivery.

### M11 — The miner (`bin/time/snotra/snotra-mine.sh`)

- Mechanical commitment cues over the transcript: decisions ("we decided",
  "agreed", "confirmed", "the decision is", …) and action items ("I will",
  "we need to", "let's", "follow up", "send", "by <day>", …)
- Every line carries its **verbatim quote** and its **timestamp**, so it can be
  jumped to in the recording; the transcript is normalized from whisper's SRT,
  because `--output-txt` carries no times
- The trust note is written into the header, not implied: machine STT, wording may
  be imperfect, **no speaker diarization — owners are never assigned**, nothing
  invented
- A small exclusion list keeps openers ("good morning, let's get started") out of
  the action list

### M12 — The boot (`tools/mill/systemd/snotra-detect.service`)

- A user unit, `WantedBy=ymir.target`, seated from the seat's materialized copy
  (`%h/.fleet/snotra-detect.sh`) with `SNOTRA_DOORS_DIR` naming the durable tree
- Raised by **capability**, never by role: it joins the one table in
  `bin/engine/autoboot-lib.sh` (`AUTOBOOT_CAPABILITY_PROGRAMS`), so a seat's raise and
  its proof can never disagree about what it owes. A seat with a microphone owes
  the watch; a headless heart reports a clean skip.
- `ExecStop=-… leave` closes the book on a stop; a stop with nothing armed is a
  no-op, not a failure

## What the watch guarantees — and what it does not

```
guarantee[3]{edge,what,whose}:
  "guaranteed","every call whose start and end THIS machine can see — an app taking and releasing the microphone, or a conversation sink appearing and leaving","the watch's"
  "not guaranteed","a call that never touches this machine (a phone, another seat, a browser elsewhere) leaves nothing here to hear","the LANE's — a live-lane ear on the seat in the meeting, or the platform's own recording"
  "named false positives","any client that opens a microphone capture stream arms the ear, the seat's own voice tooling included","the seat's policy, below"
```

No claim is made beyond the machine's reach. The manual door (`snotra-detect.sh
arm`, and `snotra-capture.sh` by hand) stays for any call the watch cannot see.

### The seat's policy (what this seat does NOT treat as a call)

The ignore list and the thresholds are configurable per seat, and a seat may keep
its policy **in the hoard** at `hodd/data/snotra-detect.conf` (a `KEY=value` file
sourced before the environment) — so a room is tuned without editing the tree:

```
detect_env[10]{key,default,meaning}:
  "SNOTRA_IGNORE_APPS","—","space-separated app names never treated as a call"
  "SNOTRA_IGNORE_BINARIES","ffmpeg","process binaries likewise (the watch's own probe)"
  "SNOTRA_IGNORE_APP_RE","^PipeWire ALSA","an awk-matched app-name regex. The ALSA-plugin utility clients are never a call — and on a real seat BOTH the seat's dictation (voxtype) and arecord report under this name, so the rule also keeps dictation out of the meetings shelf. No backslash escapes: awk's -v strips them"
  "SNOTRA_ARM_DEBOUNCE","3","seconds a new mic stream must persist to arm"
  "SNOTRA_RELEASE_GRACE","5","seconds the mic must stay released to leave"
  "SNOTRA_SILENCE_DB","-45","the room-quiet floor in dB"
  "SNOTRA_SILENCE_SECONDS","300","seconds of quiet that end a meeting"
  "SNOTRA_COOLDOWN","30","the anti-flap quiet after a meeting closes"
  "SNOTRA_MIN_SECONDS","5","the shortest capture that is a meeting at all; below it the recording is KEPT and the shelf left alone"
  "SNOTRA_LANE","ping","the filename lane token"
```

## Private data

Audio recordings, transcripts, and meeting content are **private data**. They
live under `$YMIR_HOME/hodd/life/meetings/` and are never committed to
the public repo. The repo carries only the wiring scripts and the MCP server.

## First Law compliance

- No participant names in the repo
- No meeting content in the repo
- No audio files in the repo
- The hoard is the vault; the repo is the wiring

## The fleet's engines (measured 2026-09-24)

| seat | engine | model | notes |
|---|---|---|---|
| heimdall | `~/whisper.cpp.src/build/bin/whisper-cli` (CUDA) | `~/whisper.cpp/models/ggml-small.en.bin` | the brain (<gpu>) |
| whynot | `~/whisper.cpp/build/bin/whisper-cli` (CUDA) | `~/whisper.cpp/models/ggml-small.en.bin` | needs `LD_LIBRARY_PATH` |
| omarchy | `/usr/bin/whisper-cli` (CPU, `extra/whisper-cpp`) | `~/.local/share/voxtype/models/ggml-small.en.bin` | voxtype also has a full `meeting` mode |

The transcribe script discovers the engine (env → PATH → build trees →
`voxtype transcribe`), normalises to 16 kHz mono, sets `LD_LIBRARY_PATH` for a
build-tree binary, and picks GPU vs CPU by free VRAM (a resident rail model
starves CUDA — whynot's <gpu> always falls to the CPU).

## Dependencies

- **PipeWire** (system audio capture) — already present on Omarchy
- **ffmpeg** (audio recording) — already present
- **whisper.cpp** (transcription) — already built on heimdall
- **llama-swap** (summarization) — already running on the rail
- **Node.js** (MCP server) — already available
- **bun** (optional, for faster startup) — already installed on seats

## The watch and the engine

Meetily-Local is the recommended *capturer*; the **watch** (M9–M12) is Ymir's
own and needs no engine at all — it is a read of the PipeWire graph and a
capture of the conversation pair. Meetily has no call detection, and its Pro tier
lists auto-detect as future work; the watch is that half, built around whatever
capturer the seat uses.

### The engine's residency is the watch's to decide (2026-10-01)

`tools/mill/systemd/snotra-ear.service` — the whisper engine on `:8322` — is
**not a boot resident and carries no `[Install]` section**, so nothing can put
it in `ymir.target`. `bin/time/snotra/snotra-detect.sh` seats it into
`~/.config/systemd/user/` at arm time and owns its whole lifecycle:

| when | what | why there |
|---|---|---|
| `do_arm`, after the capture is confirmed alive | `ear_up` | a refused arm must not cost the card a whisper for a meeting that is not being heard |
| `do_leave`, on **all three** exits | `ear_down` | no meeting, no VRAM owed — whichever way the leave ended |
| `do_leave`, **after** `finalize` returns | `ear_down` | `finalize` transcribes *through this engine*; lowering first leaves a recorded meeting with no minutes |
| `back_to_idle` | `ear_down` | the net for a watch that restarted mid-meeting, or a seat disabled by hand |

**Why a boot target was the wrong owner.** The engine is the largest VRAM claim
the ear makes — ~900 MiB on a strong box — and a strong box is also serving a
rail whose 262K model needs 13,790 MiB of a 16 GiB card. On heimdall the unit
being resident from login is what made **every rail request fail with a 500 that
named the model**: the preset's MTP draft context found no room. `WantedBy` and a
capability raise both decide by *what hardware the seat has*; only the watch's gate
decides by *whether a meeting is happening*. The old unit comment claimed a
capability raise that never existed — `AUTOBOOT_CAPABILITY_PROGRAMS` is
`snotra-detect` alone.

**The ear is deliberately absent from `AUTOBOOT_PROGRAMS`.** That list is the purge
list: `purge_stale_units` drops any unit in it that is not owed, and the ear is
owed by nothing (a headless heart must never load whisper). Adding it would have
the engine's own unit purged out from under the watch. Staying out leaves the copy
governed by exactly one file — the one in this tree — instead of a materialized
copy in `~/.config/systemd/user/` that nobody audits, which is how a 900 MiB engine
came to sit on a seat for three days with no meeting and no unit in the tree.

**`ear_seat_unit` REFRESHES, it does not merely seed** (corrected 2026-10-01, after
PR #258 shipped a version that tested only `[ -f "$dst" ]`). A seat is not
provisioned or unprovisioned — it is provisioned *to some version*, and that is
exactly where a stale `[Install] WantedBy=ymir.target` hides. So the function
`cmp -s`es the seated copy against the tree's and refreshes when they differ,
returning quietly when they match. The failure it prevents is the sharp one:
seeding-only would have removed the engine's residency from a seat that had
**never** had the unit and left it pinned on a seat that **always** did — the seats
that need the fix most. A seat that hand-wrote its own engine unit is **not**
refused: the watch warns and leaves it standing, because silently replacing a
hand-made unit is the same sin in the other direction.

**The rail yields during transcription.** `bin/time/snotra/snotra-transcribe.sh` defaults
`SNOTRA_FREE_RAIL=1`: when the GPU is starved it sources
`~/.local/bin/voice-gpu-lib.sh` and calls `voice_ensure_vram 2048`, unloading the
resident rail model and retrying on GPU. A meeting is the thing that matters while
it is happening and the rail is the largest claim on the card, so the rail gives
way. `SNOTRA_FREE_RAIL=0` is the deliberate override for a seat that would rather
wait than have its rail evicted. The transcribe path already falls back to CPU by
free VRAM, and then to the seat's own `whisper-cli` when the ear lane is
unreachable — so a meeting is never lost to an engine that would not start.

Record: `docs/fixes/snotra/2026-10-01-the-ear-follows-the-gate.md`.
Measured: `~/CHANGELOG.md` 2026-10-01 and `$YMIR_HOME/hodd/docs/devtools/text-to-speech.md` 2026-10-01.

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

## The live tail (M13)

`bin/time/snotra/snotra-live.sh` — the live tail: realtime mic transcription that grows in a doc.

**Shape:**

```
snotra-live.sh start <slug> [topic]   open the doc, raise the segmenter, raise the tail
snotra-live.sh status                 TOON row: pid, slices done, doc path, last line
snotra-live.sh tail                   follow the doc as it grows
snotra-live.sh stop                   stop, drain the tail, hand off to the pipeline
```

```
mic ──ffmpeg -f segment -segment_time 6──> slices/NNNN.wav
                                            │  tail -f (never a busy poll)
                                            ▼
                              whisper-cli (the seat's engine, discovered)
                                            │  "[hh:mm:ss] text"
                                            ▼
                    <meetings>/<date>-<lane>-<slug>.md   ← grows while spoken
                                            │  at stop
                                            ▼
              snotra-mine.sh → *.actions.md ; snotra-transcribe.sh → minutes ; Rune
```

**Reuse law:**
- Engine discovery reuses `snotra-transcribe.sh`'s `find_whisper()` / `find_model()`
- Hand-off uses the same door `snotra-detect.sh finalize` uses: sets `SNOTRA_MINUTES_FILE` / `SNOTRA_TRANSCRIPT_FILE`, then calls `snotra-transcribe.sh` and `snotra-mine.sh`
- The watch is untouched: manual door only; no change to `snotra-detect.sh` behaviour

**The mic-only sentinel gap:**
`snotra-capture.sh resolve_devices` treats an unset/empty `SNOTRA_MONITOR` as "resolve the default sink", so there is no way today to say microphone-only. A sentinel (`SNOTRA_MONITOR=off`) or a `--mic-only` door is required, and the mic-only ffmpeg branch already exists (capture.sh, the `elif [ -n "$MIC" ]` arm). The live tail passes that sentinel.

**Truths to keep:**
- Latency is ~6-9 s behind the voice — the slice length. That is the price of the chunked tail and it was accepted in exchange for resumability.
- A crash loses at most one slice. The loop is a tail, not a re-run.
- No speaker diarization. The mic is one voice; the miner already says so in its trust note and that wording carries over.
- Private data. Transcripts and audio live under `$YMIR_HOME/hodd/life/meetings/` and never enter the repo.

**Doomed to check:**
- Does a slice written by the segmenter ever read as half-written by the tail? (`-segment_atclocktime`, or a stability check on file size before transcribing) — addressed: ffmpeg's segment output is written atomically once complete, and the tail checks file size stability.
- Does the tail survive a rail eviction mid-meeting? (the rail yields; the engine must not die with it) — addressed: the tail re-discovers the engine on each slice.
- Is the doc safe to `tail -f` while it grows, on this filesystem? — addressed: the tail uses `inotifywait` if available, otherwise polls with a stability check.
- Does `stop` drain the last slices before the pipeline reads the WAV? — addressed: `stop` waits for both the tail and segmenter to complete.

**Proof (M7 spirit):**
One real run on heimdall: start → speak for a couple of minutes → the doc visibly grows with timestamps → stop → minutes, actions and a Rune appear. Transcript content redacted in the PR body.

## Naming

- **Snotra** — the meeting ear (wise one, mistress of counsel)
- The watch is the **ear's own watch** (pricks up when a call begins; `snotra-detect`)
- The capture is the **ear** (hears the meeting)
- The transcription is the **brain** (processes what was heard)
- The miner is the **counsel** (what was decided, and who owes what)
- The minutes are the **record** (what was decided)
- The MCP face is the **voice** (speaks the record to agents)
- The live tail is the **live ear** (writes the transcript as it grows; `snotra-live.sh`)
