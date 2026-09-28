## runtime · 2026-09-28 · Snotra's ear hears the call, and leaves when the room empties

### Why

Snotra's ear (`bin/snotra-capture.sh` + `bin/snotra-transcribe.sh`) could hear a
meeting, but only if a hand armed it. Nothing watched for a call beginning, so a
ping meeting passed unheard. The design named the missing half plainly: **P0b the
detector** (watch PipeWire for an app taking the microphone, arm the capture,
stop when the mic goes idle) and **P5b the boot** (the detector as a user unit
joined to `ymir.target`).

The Allfather's two laws, as words: *"all meetings I have on ping must come to
me"* and *"when all people leave the meeting snotra should leave also"* — no
lingering ear, no endless recording, the minutes finalized and delivered **at
leave**.

### The fix

**The watch — `bin/snotra-detect.sh`.** A standing watch on the PipeWire graph,
read through the portable `pactl` surface (PipeWire serves the PulseAudio
protocol on every seat). One snapshot per tick carries the four graphs it reasons
over (sources, source-outputs, sinks, sink-inputs), emitted as tab-separated
records so the shell reads them without a second JSON parser.

- **The START edge — an app takes the mic.** A *new* record stream on a
  non-monitor source, sustained for `SNOTRA_ARM_DEBOUNCE` (3 s). A stream already
  open when the watch started is **not** a call: the watch takes a baseline at
  start, because Discord on this very box holds the microphone open while idle. A
  second, narrower signal covers the app that already holds the mic — a new
  *playback* stream from that same app is the conversation's remote side
  beginning.
- **Both sides are routed.** At arm the watch resolves the **conversation pair**:
  the microphone the call app is actually reading (`source` on its record stream)
  and the **sink the call itself is playing into** (the sink its playback stream
  rides, falling back to the default sink). The capture is armed with that pair,
  so the remote side is heard.
- **The LEAVE edge — the room empties.** Three independent signs, first to fire:
  **L1** every stream that armed the ear is gone (sustained for
  `SNOTRA_RELEASE_GRACE`, 5 s); **L2** the conversation's sink left the graph;
  **L3** mic and monitor both below `SNOTRA_SILENCE_DB` (−45 dB) for
  `SNOTRA_SILENCE_SECONDS` (300 s). Plus the capture's own safety cap as the last
  resort. On leave the watch stops the capture, closes the book, and re-baselines.
- **The pipeline, at leave.** Stop the capture → transcribe through the seat's
  whisper (the same engine the ear serves to the fleet) → mine decisions and
  actions → write the dated minutes, the actions list and a timestamped
  transcript to `$YMIR_HOME/hodd/workspaces/meetings/<date>-<lane>-<slug>.md` →
  **deliver**: a desktop note (`bin/ymir-say.sh --mark-done`) and a durable wake
  (`bin/ymir-state.sh queue append check meeting:<slug> …`), so the meeting comes
  to the Allfather with no arm and no sweep.
- **The miner — `bin/snotra-mine.sh`.** Mechanical commitment cues over the
  transcript, every line carrying its verbatim quote and its timestamp, with the
  honest trust note written into the header (machine STT, no speaker
  diarization, owners never assigned, nothing invented).
- **The boot — `tools/mill/systemd/snotra-detect.service`.** A user unit,
  `WantedBy=ymir.target`, raised by **capability** and never by role: a seat with
  a microphone owes the watch, a headless heart reports a clean skip. It joins
  the one table in `bin/autoboot-lib.sh` (`AUTOBOOT_CAPABILITY_PROGRAMS`), so the
  raise and the proof can never disagree about what a seat owes.
- **The manual door stays.** `snotra-detect.sh arm [slug]` / `leave`, and the
  existing `snotra-capture.sh` / `snotra-transcribe.sh` by hand, for any call the
  detector cannot see.

### Four wounds found by building it, and mended here

1. **A self-feeding loop.** A delivery's own desktop notification raised a
   microphone stream, which the watch read as a new call — arm → capture →
   deliver → notify → arm, three times in ninety seconds, each one overwriting
   the same minutes and queuing another wake. Two mends: an ignore rule for the
   ALSA-plugin utility clients (`SNOTRA_IGNORE_APP_RE`, default `^PipeWire ALSA`
   — `arecord` and `voxtype` both report under that name on this box, so the
   rule also keeps the seat's own dictation out of the meetings shelf), and an
   **anti-flap cooldown** (`SNOTRA_COOLDOWN`, 30 s) after every meeting closes.
2. **A double arm left a lingering ear.** The watch's loop and the manual door
   could both arm, and a trigger set could change mid-debounce — so a second
   capture started while the first kept writing into the shelf with no pid
   anyone held. Mended with a hard one-ear guard in `do_arm` plus
   `stop_lingering_captures`, which kills any ffmpeg still writing into the
   meetings shelf at leave and at start-up.
3. **The shell wake-lock waits forever.** `bin/brokk-wake-lib.sh`'s
   `fm_wake_append` takes a lock **directory** at `$STATE/.wake-queue.lock`, while
   the queue itself (`src/ymir_runtime/state/queue.py`) owns a lock **file** at
   the same path. Where the queue's file exists, `fm_lock_try_acquire` can never
   succeed and `fm_lock_acquire_wait` loops for ever — a watch that waits for
   ever is an ear that never leaves. The watch now appends through the queue's
   own door (`bin/ymir-state.sh queue append`) and the append is **bounded**
   (`timeout 20`), so no queue pathology can wedge a delivery. *(The shell
   helper's incompatibility is named, not changed — other callers are outside
   this errand.)*
4. **The materialized operator commands could not find the home.**
   `bin/fleet-ensure.sh` copied `snotra-capture.sh` and friends into `~/.fleet`
   but not `bin/hoard-lib.sh`, so every one of them died on `YMIR_HOME: unbound
   variable` the moment it ran outside a shell that already knew the home — the
   seated unit included. `hoard-lib.sh` now rides along, and the watch also
   resolves it through the durable tree the unit names.

### The guarantee, stated honestly

- **Guaranteed: every call this machine can see.** A call whose start and end
  the seat observes — an app taking and releasing the microphone, or a
  conversation sink appearing and leaving — is caught, recorded, mined and
  delivered. That is the detector's whole reach: the microphone.
- **Not guaranteed: a call that never touches this machine.** A meeting held
  elsewhere (a phone, another seat, a browser on a box that is not this one)
  leaves nothing here to hear. That is the **lane's** edge, not the watch's: it
  needs a live-lane ear on the seat that is in the meeting, or the platform's own
  recording. No claim is made beyond the machine's reach.
- **Named false positives.** Any client that opens a microphone capture stream
  arms the ear — the seat's own voice tooling included. The ignore list is
  configurable per seat (`SNOTRA_IGNORE_APPS`, `SNOTRA_IGNORE_BINARIES`,
  `SNOTRA_IGNORE_APP_RE`) and a seat may keep its policy in the hoard at
  `hodd/data/snotra-detect.conf` (a `KEY=value` file sourced before the
  environment), so a room is tuned without editing the tree. A capture below
  `SNOTRA_MIN_SECONDS` (5 s) is kept but never mined: a blip is not minutes.

### Proof (live, on this box, through the seated unit)

A synthetic call: an app takes the microphone (`parec`), the conversation plays
into the call's sink, the microphone is released.

```
2026-09-28T10:48:29Z START edge — app 'parec' (pid 2667776) took the mic;
  pair mic='alsa_input.pci-0000_00_1f.3.analog-stereo' sink='bluez_output.…1'; slug=parec
2026-09-28T10:48:57Z LEAVE edge (mic released) — stopping the ear
2026-09-28T10:49:21Z delivered — …/meetings/2026-09-28-ping-parec.md
```

- the shelf: `2026-09-28-ping-parec.md` · `.actions.md` (6 mined) ·
  `.transcript.txt` (timestamped) · `.wav`
- the durable wake: `1790592561	8	check	meeting:parec	check: ping meeting
  captured — …/2026-09-28-ping-parec.md (51s, mic released, 6 actions)`
- the desktop note: `done · Meeting captured — parec (51s)`
- **the ear is not still recording**: `state/.snotra-pid` and
  `state/.snotra-listening` both absent, and no ffmpeg process alive
- the unit stayed `active`; a clean `systemctl --user stop` leaves it
  `inactive`, not `failed`

Also proved: the **quiet edge** (L3 — the mic still held, the room silent for the
threshold → leave and finalize), the **ignore rule** (`arecord` and `voxtype`
grabs arm nothing), and the **manual door** (`arm` / `leave` by hand).

galdr-reread: `snotra-meeting-ear.md` (M9–M11, the guarantees, the door policy),
`runtime-components.md` (the two new commands), `registry.md` (the watch unit and
the materialized commands), `installation.md` (the capability raise and
`hoard-lib.sh` riding along).

### Files

- `bin/snotra-detect.sh` (new) — the watch: edges, pipeline, delivery
- `bin/snotra-mine.sh` (new) — the mechanical decisions/actions miner
- `tools/mill/systemd/snotra-detect.service` (new) — the unit, joined to `ymir.target`
- `bin/autoboot-lib.sh` — the capability axis (`snotra-detect`), the program row
- `bin/fleet-ensure.sh` — the unit's template row, the templated raise, and
  `hoard-lib.sh` materialized beside the operator commands
- `bin/snotra-capture.sh` — `SNOTRA_OUTFILE` (a named recording) + `state/.snotra-outfile`
- `bin/snotra-transcribe.sh` — explicit minutes/transcript paths, a timestamped
  transcript from whisper's SRT, and the fleet ear lane when the seat has no engine
- `bin/ymir-install.sh` — the watch named in the snotra step (the fleet step raises it)
- `.agents/skills/galdr-ymirsystem/assets/{snotra-meeting-ear,runtime-components,registry,installation,README}.md`
