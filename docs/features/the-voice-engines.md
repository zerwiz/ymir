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
