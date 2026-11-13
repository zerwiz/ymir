# voice · 2026-11-13 · The house was deaf

## What

A voice note from the Allfather arrived on Telegram and the seat answered *"I cannot hear it."* Measured:

```
voice-door.sh status → engine ABSENT · host seat none reachable · answers no
no whisper binary on PATH · nothing in ~/whisper.cpp/build/bin (the tree holds models only) · no ffmpeg
```

The docs say the ear is *discovered, never assumed* — `snotra-transcribe.sh` names a binary per machine. On the
heart none was ever seated, so the discovery found nothing and reported a capability absent.

## Why

Two causes, and the second is the interesting one.

1. **Nothing installed the engine here.** The install step seated the door and not the ear.
2. **The door only knew one road.** It probed for a whisper *binary*. This machine has `python3` and `pip`, and
   `faster-whisper` turns a recording into words perfectly well — so the capability was reported ABSENT while
   the machine could already do the work.

## The fix

- **The engine**, installed without root: `python3 -m pip install --user --break-system-packages
  faster-whisper` and `av==13.1.0` (pyav 19 dropped `metadata_errors`, which faster-whisper still passes).
- **`bin/voice/ear.sh`** — one door, two roads, probed in order and the answering road named: `whisper-cli` when
  a seat has it, `faster-whisper` otherwise. A file that decodes to silence is **exit 3 with NO AUDIO**, because
  an empty recording is a fact to report, not an error to hide.

## Proof

A real recording, transcribed in full:

```
ear[4]{engine,model,language,text}:
  "faster-whisper","base","en","Before the worlds were shaped, cold mist and embers met, and from that meeting
  came the giant whose body became everything. One machine, one repository, from his body, every hall of your
  work is carved."
```

The note he sent the same evening:

```
ear[1]{engine,verdict}:
  "faster-whisper","NO AUDIO — the file decodes to silence (rms 0), so there is nothing to hear"
```

Verified twice: the python decoder and ffmpeg inside a container both measure rms 0.0 over 14.6 s — the file
carries no sound, so the fault was the recording, not the ear. He was told, and asked to send it again.

## Change log

- **2026-11-13** — written with the door, after the seat had to admit it was deaf.
