# Rödd — the voice, as a desk app

The face of Ymir's realtime voice: an Electron window over the house's browser voice UI
(the engine's own, dressed in the house's cloth — stone, bone and bronze).

**The pipeline is not started here.** It is the door's business:

```sh
bin/voice/voice-door.sh start      # raise the host if needed, tunnel, seat the terminal client
bin/voice/voice-door.sh status     # what answers, on which seat, by which road
```

This app is the **face**; the door is the **pipeline**. A window that claimed to host a
voice it did not raise would be a lie told in pixels.

## Install and run

```sh
cd apps/rodd
npm ci                             # electron (dev dependency)
npm run ui:install                 # the UI's own deps (the engine's pins)
SPEECH_TO_SPEECH_URL=ws://127.0.0.1:8890/v1/realtime npm run start:system   # uses the Arch electron41 package
```

The window serves `ui/` from a loopback HTTP server on an ephemeral port — a real origin is
required for `getUserMedia`, and ES modules will not load from `file://`.

## What is where

| path | what |
|---|---|
| `src/main.js` | the Electron shell: static server + one window, titled Rödd |
| `ui/index.html`, `ui/main.js`, `ui/ws/**`, `ui/worklets/**` | the engine's voice UI (unmodified except `house.css` and the role words) |
| `ui/house.css` | **ours**: the palette only — the layout and the bubbles stay the engine's |
| `ui/package.json` + lock | the UI's pinned dependencies (`npm run ui:install`) |

## Limits, stated plainly

- The UI carries the demo's own JS tools (web search, camera) — **not** the house's fourteen
  voice tools, which live in the Python client (`bin/voice/voice_tools.py`). Bridging them is
  named in plan 132 §30.3.
- One session slot: the terminal client and this window cannot both hold the host.

## Vendored from upstream (attribution)

`ui/` is the browser face of **huggingface/speech-to-speech** at tag **v1.1.0**
(Apache-2.0) — the demo whose `@openai/agents` pin matches that engine release. Its
browser UI was built by Pollen Robotics and Hugging Face (`amir-tfrere/minimal-conversation-app-s2s-backend`).
The house's changes are deliberately small and additive: `house.css` (the palette), the
page name, the two role words, the Kokoro voice list, the house brief, and one hook that
forwards tool calls to the house's toolbox. The vendored SDK bundle and the VAD/onnx wasm
are **not** committed — `npm run ui:install` fetches them.

## CHANGE LOG

- **2026-11-07** — carved. The Electron shell, `start.sh` (the single-seat order) and `smoke.sh`
  (eight stages; the last must prove audio arrived). The UI is vendored from
  `huggingface/speech-to-speech` v1.1.0 with the house's palette, its own brief, the Kokoro voice
  list and the ember canvas; the SDK bundle and the onnx assets are fetched by `npm run ui:install`,
  never committed. The vendored project's own documentation (README, CONTEXT, DESIGN, adr, livekit)
  is left out of this repository on purpose — attribution lives here, and Rule 06's change log
  belongs to the house's documents, not to upstream's.
