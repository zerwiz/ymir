# The voice engines — whisper for the ear, piper for the voice

> **Status: built and tested (2026-10-18).** `bin/voice/voice-ensure.sh` (**the voice shelf**),
> the `voice` step of the installer, the plan's engines phase, and Eir's `voice` surface.

## What it is

Two engines make a machine able to hear and to speak:

- **whisper.cpp** — speech → text (the ear);
- **piper** — text → speech (the voice), with a voice model (`.onnx`).

**Voice is a machine property**: the engines and the models live on the host or in the hoard,
never in the code tree. The ensure script **adopts what already stands** and installs only what is
missing — it never reinstalls a working engine.

**One road for the ear:** whisper is owned by `bin/time/snotra/snotra-ensure.sh` (the meeting ear's
engine), so `voice-ensure` delegates that half instead of growing a second whisper installer.

## What you need

`python3` (for a venv) or `pipx`, and `curl` for the voice model. Neither is required if both
engines are already present — which is the normal case on this fleet.

## The commands

```sh
bin/voice/voice-ensure.sh status            # is the ear there? the voice? its model?
bin/voice/voice-ensure.sh ensure --install  # adopt, and install only what is missing
bin/voice/voice-ensure.sh install           # the same, said plainly
```

The **installer** runs it as the `voice` step (after `snotra`), and the **plan** shows it in the
engines phase:

```sh
bin/engine/ymir-install.sh --check | grep voice   # "voice","OK","whisper (STT) + piper (TTS) present (adopted)"
bash bin/bridge/ymir-plan.sh | grep voice         # "4","engines","voice","SKIP","…present (adopted)"
```

**Opt out:** `--skip-engines` on the installer, or `YMIR_SKIP_VOICE=1`.

## Where things land

| what | where |
|---|---|
| the voice models | `$YMIR_HOME/voices/<name>.onnx` (env `YMIR_VOICES_DIR`) |
| a venv piper, when pipx is absent | `$YMIR_HOME/.venvs/piper/bin/piper` |
| an adopted piper | `$YMIR_PIPER_BIN`, or `piper` on `PATH`, or a known venv/pipx path |
| the ear's engine + model | wherever Snotra seated them (`bin/time/snotra/snotra-ensure.sh status`) |

## Limits, stated plainly

- **It adopts, it does not upgrade.** A standing engine is left exactly as it is.
- The piper half needs `python3` (venv) or `pipx`, and the network for a voice model. A refusal is
  **loud**, never a silent skip — an engine that is missing must be visible.
- It installs **engines**, not the desktop bindings: the keys and the daemons that use them live in
  the voice section of the seat's own contract.

## If it does not work

| symptom | cause | do |
|---|---|---|
| `voice: piper install failed` | no pipx and no working `python3 -m venv` | install `python3-venv`, or `pipx install piper-tts` |
| `voice: voice fetch failed` | the voice name or the network | check `PIPER_VOICE_NAME`, then retry |
| the ear reports missing | whisper is Snotra's road | `bin/time/snotra/snotra-ensure.sh status` |
| the installer skips voice | `--skip-engines` or `YMIR_SKIP_VOICE=1` | re-run without them |

---

## Appended 2026-10-22 — Kokoro, three doors, and the cleaner that ate the apostrophe

**Kokoro** is the second voice engine: 24 kHz, an 82M model kept resident on the GPU by
`kokoro-serve.service` (`:8765`). Piper stays on **F10**; Kokoro is on **F11**; the assistant speaks
through the same server. Three doors, and they only behave when they share **one text path** and **one
voice**.

### The fault this day, and why it mattered

`~/.local/bin/piper-clean-text` is the markdown cleaner both F11 and Piper run before synthesis. Three
lines in it broke speech for **every** voice:

```
re.sub(r"[^\w\s.,:-]", " ", line)     every apostrophe → a SPACE:  "Allfather's" → "Allfather s"
re.sub(r"(?<!\d)\.(?!\d)", "", line)  every period     → deleted:  no sentence pauses
re.sub(r"(?<!\d),(?!\d)", "", line)   every comma      → deleted:  no breath inside a sentence
```

Heard from the operator's chair: *"do n,,,, t"*, *"allfather .... s"*, *"all voices are breaking it"* —
and every one of those observations was correct. **The lesson is the page's most useful line: when
every voice breaks the same word, measure the string before measuring the speaker.**

**Fixed at the root** (backup `piper-clean-text.bak-20261022`): curly apostrophes fold to a plain one,
only quotes that are not word-internal become spaces, periods and commas are kept, a colon becomes a
comma unless it is a time (`12:30`), and the final sweep allows `'`.

### The voice

`~/.local/bin/kokoro-voice` (SUPER+CTRL+U) is the **single source of truth**. It is read by F11
(`kokoro-speak`) and by the assistant (`bin/assistant/voice.sh`); the server config is only a fallback,
because two sources of truth produced two voices on one box.

Measured on the same long answer: **af_nicole 17.4 s / 14 pauses · af_heart 10.7 s / 6 · af_bella
11.0 s / 5 · bf_emma 10.0 s / 4 · am_michael 11.8 s / 7**. af_nicole is the operator's chosen voice; the
others remain a `kokoro-voice next` away.

### The commands worth knowing

```sh
piper-clean-text <<< "the Allfather's assistant, 1,000 times at 12:30"   # must keep ' , . and digits
kokoro-voice                          # which voice, and its grade
kokoro-voice set af_heart             # or next / prev to cycle
bin/assistant/audio-tighten.py in.wav out.wav   # close a model's short mid-word gaps
bin/assistant/speech-text.py <<< "I don't hold that"   # what the assistant's mouth may say
```

### Limits

- The server returns **MP3 by default**; ask for `"response_format": "wav"` when the audio is to be
  processed (the assistant does, since a file named `.wav` was quietly holding MP3).
- `audio-tighten.py` squeezes a gap **shorter than 120 ms** to 30 ms and leaves a real pause alone —
  `--squeeze-all` exists, but it removes the breath between clauses too.
- The rotation can land on a voice that stutters at apostrophes (af_nicole, grade B−, inserts pauses
  mid-word). That is the voice's character, not a text fault: the text is now correct, and
  `audio-tighten.py` is the lever if it becomes tiresome.
- Never write a possessive with U+02BC (the modifier apostrophe): measured, it shatters
  `Allfatherʼs` into four pieces over 3.26 s. The ASCII apostrophe is the correct one.

### If it does not work

1. `piper-clean-text` round-trip first — if the apostrophe is gone, no voice can save it.
2. `kokoro-voice` — is the voice the one you think it is?
3. `curl -s -o /tmp/a.wav -X POST http://127.0.0.1:8765/v1/audio/speech -H 'content-type: application/json' -d '{"input":"the Allfather'"'"'s assistant","voice":"af_nicole","response_format":"wav"}'` and play `/tmp/a.wav`: that bypasses every door and tests the engine alone.
