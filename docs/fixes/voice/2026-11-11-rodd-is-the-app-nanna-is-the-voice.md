# Rödd is the app; Nanna is the voice inside her — and the head can leave the house

**Date:** 2026-11-11 · **Component:** voice (`apps/rodd/*`, `bin/voice/voice-door.sh`,
`bin/voice/rodd-head.py`, `bin/voice/head-proxy.py`, `bin/voice/voice-toolbox.py`)

## What was wrong

1. **The assistant was called Skírnir.** His correction: *"the apps are named rödd. not the assistant in the
   app. the female"*, and *"rödd is a female, it's not skírnir. skirnir are the nerfed assistant."* Nothing in
   `docs/lore.md` named either figure; the brief in `patch/patch-ui.py` said *"You are Skírnir"*, and the
   transcript's role words were `Allfather` / `Skírnir`.
2. **His own words were thrown away.** `ui/main.js` restored the instruction field only when the saved text
   still matched `/Skírnir|Skirnir/`. A brief he edited — or a brief that named Nanna — was silently replaced
   by the shipped default on the next load. Measured in his window at 05:14: the field read the Skírnir text
   even after the default had become Nanna's.
3. **The head was hardcoded to one model, chosen by a script.** `apps/rodd/start.sh` named a 3050-tuned alias
   that **this** rail does not serve; the door refused with `model 'qwen3.6-35b-a3b-3050@iq2_xxs' not found`
   (400), the host never came up, and the window showed the engine's unhelpful `[object Event]`.
4. **There was no way to use an online model**, and no place to put a key that was neither the repo nor the
   window's storage.
5. **The door refused to raise its own host while its own window was open** — `refused: '@zerwiz/rodd' holds
   the microphone`, measured 05:12. The guard against taking the mic from a live call could not tell her own
   face from a call.
6. **Kokoro was slow** because the engine asks Hugging Face about the model on the way to the first word:
   `tts_ttfa=8.85s` and `15.30s` for 3.18 s and 2.55 s of audio, against **0.16 s** for the same line warm on
   this box (measured: 11.55 s import + 5.24 s pipeline init cold).

## The fix

- **The names, in the committed layer only.** `patch/patch-ui.py` (`HOUSE_BRIEF`) now opens *"You are Nanna,
  the one who answers in Rödd"*, says she is a she, and says plainly that Skírnir is someone else. The role
  words are `Allfather` / `Nanna`. `ui/` is build output — fetched by `setup.sh` and re-dressed every time — so
  every change lands in the patcher, never in the face.
- **His words are kept.** The `/Skírnir|Skirnir/` gate is gone. `SHIPPED_BRIEF_HEADS` names the opening line of
  every brief the house has shipped, and only one of those is replaced; anything he wrote is used verbatim.
  The patcher mends both older shapes (the plain one-liner and the regex gate), so a face dressed at any
  earlier generation converges.
- **One door for the head: `bin/voice/rodd-head.py`.** It resolves mode (`local` · `online`), base URL, model,
  key and client profile, in that order: environment → `$YMIR_HOME/hodd/secrets/rodd.env` (0600) → the shipped
  template. The repository carries ONLY `apps/rodd/config/rodd.env.example` — the shape, with the sentence
  that a key is **named**, never pasted. A key name may be `pi:<provider>`, resolved from the seat's own pi
  store, so a key the operator already has is never copied anywhere.
- **A key typed in the panel goes to the home.** `POST /head` writes `RODD_HEAD_API_KEY` into
  `$YMIR_HOME/hodd/secrets/rodd.env`, mode 0600, and `save()` **refuses** a destination inside the repository.
  No endpoint ever returns a key: `GET /head` reports `key_state` (`vault:NAME` · `typed · ends 1234` · `none`).
- **The settings panel gains a Mind block.** Mode, base URL, model, key, and a button that saves and raises the
  host. It reads `GET /head` and shows what actually answers — proven in the live window: `online ·
  deepseek-v4.1-flash · key vault:pi:opencode-go`.
- **`bin/voice/head-proxy.py`** — a loopback OpenAI-compatible door for hosted endpoints that refuse a plain
  client. Measured against opencode-go: default UA → `403 error code: 1010`; no session header →
  `400 MissingSessionID`; with `x-opencode-client` + `x-opencode-session` + a proper UA → **200**. The door
  raises it as `rodd-head-proxy.service` whenever the mode is online, and points the engine at loopback.
- **The door no longer mistakes her face for a call.** `@zerwiz/rodd` joins the microphone-holder exclusions —
  named, not a blanket Electron forgiveness.
- **`HF_HUB_OFFLINE=1`** on the host unit, so the cached Kokoro model is not re-questioned on the way to a word.
- **The resolver's key wins.** For an online head the door had fallen back to the rail's key and the engine
  answered 400; the key the resolver names is now used first.

## Proven

- `rodd-head.py` on this box: `local · qwen3.5-9b@q4_k_s · key vault:LLAMA_SWAP_API_KEY`, file 0600 at
  `~/Documents/ymirhome/hodd/secrets/rodd.env`.
- Online head, raised through the door and answering: `ymir-voice-host.service` up on 8890,
  `rodd-head-proxy.service` active with `{"ok": true, "client": "opencode", "upstream": "opencode.ai"}`, and a
  direct call through the proxy returning `the hall is listening.` from `deepseek-v4.1-flash`.
- The live window, read over its own DevTools: the Mind block present, showing `online ·
  deepseek-v4.1-flash · key vault:pi:opencode-go`, and the instructions field reading the **Nanna** brief.
- The Skírnir gate proven gone: after a reload the field carries Nanna's text even though localStorage still
  held the old Skírnir brief.
- Kokoro warm on this box: 0.16 s for a spoken line (cold: 11.55 s import + 5.24 s init + 1.81 s first line).

**Not proven:** a live conversation with his voice on the online head — that needs the ear and the mouth at
once and his mouth to speak. Also owed, and named in plan 247: a **pinned UI port** (the origin still moves, so
browser storage still resets), the window reading its settings from `GET/POST /settings` (the endpoints exist;
the UI does not use them yet), and the memory file (`POST /memory` exists unwired).

## CHANGE LOG

- **2026-11-11** — carved. Rödd named as the app and Nanna as the voice in it (`patch-ui.py` brief, role words,
  `docs/lore.md`); the restore gate replaced by `SHIPPED_BRIEF_HEADS`; `bin/voice/rodd-head.py` as the one door
  for the head with the template in the repo and the values in the home; `POST /head` + `/settings` + `/memory`
  on the toolbox; `bin/voice/head-proxy.py` for hosted endpoints that want their own headers; the door's
  microphone guard taught her own product name; `HF_HUB_OFFLINE=1`. Found while making her answer: the 3050
  alias this rail does not serve, the `@zerwiz/rodd` refusal, the `[object Event]` the window shows when the
  host is down, and Kokoro's 15 s cold time-to-first-audio.
