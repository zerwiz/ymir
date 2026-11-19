# Check the microphone

## What it is

If your voice reaches the machine loud, then very quiet, the speech-to-text engine loses words. This page shows
what the machine actually hears, and whether it stays steady.

There are two places to look:

- **In Rödd:** open Settings. Under the noise gate there is a level bar, a "your level" line, and a button,
  **Check my level (10 s)**.
- **In a terminal:** `bin/voice/mic-check.sh`.

## What you need

- PipeWire (`pw-record`, `pactl`) for the terminal door.
- Nothing extra for Rödd's level line.

## The commands

| Command | What it does |
|---|---|
| `mic-check.sh level` | Records 10 s from the default microphone, then prints its level each second, the spread, the band and the system input volume |
| `mic-check.sh level 30 --source <name>` | The same for 30 s, from a named source |
| `mic-check.sh trace a.wav b.wav` | The same trace for files you already have, so you can compare a raw and a processed recording side by side |
| `mic-check.sh volume` | The system's input volume for the microphone, with nothing recorded |

## What the bands mean

Levels are in dBFS, measured over one second:

- **under −45:** silent
- **−45 to −35:** too quiet; raise the microphone in the system's sound settings
- **−35 to −10:** good
- **a peak at −1 or above:** clipping; lower the microphone

A steady voice stays in one band. A spread of more than 12 dB across the seconds you spoke is the
"loud, then quiet" swing.

## Limits

- Nothing is recorded while the desk is held (you are on a call).
- No audio is kept. The recording lives in a temporary folder and is removed once the trace is printed.
- The door changes no setting. Raising or lowering the microphone is yours to do.

## If it does not work

- **"pw-record is not installed"**: this machine has no PipeWire. Use Rödd's level line instead.
- **"no voice heard"**: check that the right microphone is chosen in Rödd's Settings, or name it with `--source`.
- **"NOT steady"** in Rödd, but steady in `mic-check.sh level`: something between the microphone and the page is
  riding the gain. Rödd turns the browser's gain control off; report it with both traces.
