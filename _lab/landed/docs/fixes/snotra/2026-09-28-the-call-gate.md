## snotra · unversioned · 2026-09-28 — a mic grab is not a meeting (the call gate)

### Why
- **The meeting ear's watch armed and recorded on a seat where nobody was in a
  call, and re-announced the same capture again and again.** Observed on heimdall
  the same day: `bin/time/snotra/snotra-detect.sh status` reported `phase=in-call` with no
  meeting in existence; the same minutes file appeared repeatedly in the Runes
  `meeting.captured` chain; and **four separate `check meeting:parec` rows**
  accumulated in the operator's wake queue from one synthetic capture.
- **The trigger asked the wrong question.** `mic_holders()` treated *any*
  application holding the microphone as a call. Its only defences were name
  filters, and `SNOTRA_IGNORE_BINARIES` defaulted to `ffmpeg` alone — so an **idle
  Chromium mic hold** (Discord open, no call) read as a meeting.
- **Measured, not assumed.** A live `pactl list source-outputs` of the offending
  stream returned `application.name = "Chromium input"`,
  `application.process.binary = "chromium"` and **no `media.role` at all**. The
  discriminator the watch was missing is the property call applications set while
  a call is live: PulseAudio's `Communication`, which PipeWire's session manager
  surfaces as `phone` (verified by creating a stream with
  `--property=media.role=Communication` and reading back `media.role = "phone"`).
- **A blast radius, not a nuisance.** Every false arm writes a recording of the
  room into the vault, mails a desktop notification, appends a Rune and queues a
  wake — so one wrong trigger became a stream of them.

### Fix
- **`bin/time/snotra/snotra-iscall.sh` — the call predicate, one owner of the judgement.**
  Exit 0 only when (a) an explicit arm marker exists (`<state>/.snotra-arm` — the
  Þing room's door or the operator's own hand), or (b) a microphone stream
  **carries a call role** (`SNOTRA_CALL_ROLES`, default `communication phone`)
  **and** its binary is not one of the house's own audio tools (`ffmpeg`, `parec`,
  `pacat`, `arecord`, `pw-record`, `whisper*`, `voxtype`, the `snotra-*` scripts…).
  `--why` and `--json` make the verdict explain itself in the log; malformed or
  absent sound-server data **fails safe** (not a call).
- **The watch consults it before arming.** In the arm path, immediately before
  `do_arm`, the watch now calls the predicate and, when it says no, logs the
  reason and refuses to arm:
  `no call: no stream carries a call role (communication phone)`.
  The guard is skipped when the predicate is absent, so a seat without it keeps
  the old behaviour rather than losing the ear.

### Proof
- **Unit, `.agents/tests/snotra-iscall.test.sh` — 12 assertions, all passing**,
  including the fault itself (`bare mic grab (no media.role) -> NOT a call`), the
  true positives (`chromium + phone`, `firefox + Communication`), the house tools
  (`pacat/parec` and `ffmpeg` with a call role -> not a call), a mixed seat
  (`ffmpeg` ignored, `zoom` still counts), the explicit arm, an operator ignore
  list, and two fail-safe cases (malformed JSON, unreadable source). The predicate
  reads a fixture through `SNOTRA_ISCALL_FIXTURE`, so the tests need no sound server.
- **Live, both directions, on heimdall 2026-09-28:**
  - *refused* — a new microphone holder whose binary is not ignored and which
    carries no call role: the watch reached its gate and logged
    `no call: no stream carries a call role (communication phone)`; nothing was
    recorded and `state/.snotra-listening` stayed absent;
  - *armed* — a stream carrying `media.role=phone`: the watch logged the capture
    start, `state/.snotra-listening` read `recording`, and the phase went to
    `in-call` — so the ear still hears a real call, and the fix narrows the
    trigger rather than disabling the ear.

### Wiring: the merged watch now consults the gate, and delivery is once per meeting

When this landed, the merged watch (`bin/time/snotra/snotra-detect.sh`, merged via
`eindri/ping-meetings-delivered`, PR #243) still asked only "does an app hold the mic?".
Three wirings were missing; all are in this change:

- **The arm path consults the predicate.** Immediately before `do_arm`, the watch runs
  `bin/time/snotra/snotra-iscall.sh` and, when it says no, logs the reason and refuses to arm:
  `no call: no stream carries a call role (communication phone)`. The guard is skipped
  when the predicate is absent, so a seat without it keeps the ear rather than losing it.
- **`bin/fleet/fleet-ensure.sh` materializes `snotra-iscall.sh`** beside the other ear scripts,
  so the guard travels to every seat.
- **`deliver()` is now idempotent.** The gate stopped the false *captures*; it did not
  stop the same capture being *announced* over and over — which is what the Allfather saw.
  Delivery now keys on the **meeting artefact** (the minutes path, unique per capture —
  **not** the app slug in `meeting:$slug`, which collides across meetings and never
  closes): `state/meetings-delivered/<sha256(minutes-path)[0:16]>`. A repeat delivery is
  **suppressed**, and the suppression is logged and said out loud, never silent.

**Proven in a sandbox** (a temporary hoard, and a doors directory with no `ymir-say.sh` so
the test could make no desktop noise): two `arm`/`leave` passes with the same slug, which
produce the same minutes path —

```
2026-09-28T17:10:55Z delivered — …/2026-09-28-ping-ledgertest.md
2026-09-28T17:11:35Z already delivered — …/2026-09-28-ping-ledgertest.md (suppressed; one meeting is announced once)
ledger entries: 1        suppressions: 1        real deliveries: 1
```

### What is still owed
- **Seating the version.** The unit and `fleet-ensure` both address
  `~/.fleet/snotra-detect.sh`; a `fleet-ensure` after this lands is what puts the fixed
  watch on every seat. A running seat may still hold an older or hand-patched copy.
- **The cron-leak** (found by the same day's smoke test, not this fix): five seat
  schedulers read the one `config/cron.yaml`, so its ungated lines run once per scheduler.

### Also in this pass: the two channels, and the trap in them

`bin/time/snotra/snotra-capture.sh` and `bin/time/snotra/snotra-transcribe.sh` changed in the same pass, so
they carry this note too.

- **Dual-channel capture.** The capture mixed mic and system audio with
  `amix`, which destroys the two channels; it now keeps them apart with `amerge`
  behind `SNOTRA_CHANNELS=mono|stereo` (default `stereo`), so a 2-channel file
  exists to diarize. A 2-channel file is safe either way — decoded without `-di`,
  miniaudio downmixes it to one channel (`decoder_config_init(…, stereo ? 2 : 1, …)`,
  `examples/common-whisper.cpp`).
- **The assignment is load-bearing, and the obvious order is wrong.** whisper.cpp's
  `-di` names the speaker by whichever channel's energy dominates a segment, so the
  operator's mic must be **channel 0** and the room (the sink monitor) **channel 1**.
  Measured on heimdall: with the monitor on channel 0 the remote side came back as
  `(speaker 0)` — the two sides silently swapped. The filter therefore re-orders
  its inputs deliberately (`[1:a]` mic → channel 0, `[0:a]` monitor → channel 1).
- **Diarization and its labels.** `run_whisper` passes `-di` when the input has two
  channels (`SNOTRA_DIARIZE=off` disables), and the transcript renders whisper's
  channel labels legibly: `(speaker 0)` → `[Me]`, `(speaker 1)` → `[Others]`,
  `(speaker ?)` → `[?]` for overlapping or ambiguous segments.
- **Verified end to end:** speech in the left channel alone → `(speaker 0)`; in the
  right alone → `(speaker 1)`; through the patched capture, a played sample on the
  system side came back `[Others]`. Simultaneous speech on both channels returns
  `(speaker ?)` — honest, and worth stating: this is two speakers by channel, not
  N-speaker diarization.

### Files
- `bin/time/snotra/snotra-iscall.sh` (new) — the call predicate
- `.agents/tests/snotra-iscall.test.sh` (new) — 12 assertions
- `bin/time/snotra/snotra-detect.sh` — the arm path consults the gate; `deliver()` carries the
  once-only `meetings-delivered/` ledger
- `bin/fleet/fleet-ensure.sh` — materializes `snotra-iscall.sh`
- `bin/time/snotra/snotra-capture.sh` — dual-channel capture (`SNOTRA_CHANNELS`), the
  channel-order fix, the channels announcement
- `bin/time/snotra/snotra-transcribe.sh` — `-di` on a 2-channel input, `audio_channels()`,
  and the `[Me]`/`[Others]` label render (in the transcript **and** in the
  timestamped file the miner reads)
