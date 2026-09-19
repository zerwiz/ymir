---
name: bragi-translation
description: >-
  Bragi the skald — the translation craft. Carries words between tongues:
  speech→text (whisper.cpp) then text→text (the llama router's local seats),
  or direct text→text for written material. Use when the task is translate,
  transcribe, localize, subtitle, or render a message in another language.
  Keywords — translate, transcribe, speech-to-text, localize, subtitle, ogg,
  whisper, language.
argument-hint: "[transcribe | translate | localize | check]"
---

# bragi-translation — translation — speech-to-text and text-to-text between tongues

> **Norse name:** **Bragi** (the skald, poetry's god) — the word-crafter.
> Translation is the second hand of his craft: marketing (bragi-marketing)
> sends the message; translation carries it across the language border.

This skill is the Norse shell over the translation engines. Every translation
is a **real artifact** — a text file, a subtitle, a localized page — grounded
in the source exactly, never invented.

```
translation_loop[4]{step,what}:
  "transcribe","voice clip -> source text (whisper.cpp, local GPU on heimdall)"
  "translate","source text -> target tongue (the llama router's seats; no API key)"
  "verify","the Allfather's eye on names, numbers, dates, legal phrases"
  "deliver","a text file under the record, append-only, named by date"
```

## 1. The programs (detailed — see `assets/programs.md`)

| Program | Where it lives | What it does |
|---|---|---|
| **whisper.cpp** | heimdall `~/whisper.cpp/build/bin/whisper-cli` | speech → text; models `ggml-{tiny,base,small,medium}.en.bin`; GPU (RTX A5000). Refuses opus-in-ogg directly — decode via ffmpeg to 16 kHz WAV first. |
| **ffmpeg** | `/usr/bin/ffmpeg` on every seat | opus/ogg/m4a → 16 kHz mono WAV (the whisper door) |
| **the llama router** | `:8080` qwen · `:1234` apodex | text → text (the target tongue), the same local seats all coding uses |
| **Caddy/edge** | the server | where a translated page is served |

The full program-by-program how — exact commands, flags, model choice,
GPU/CPU, and the text-translation recipe — is **`assets/programs.md`**. Read it
before any translation work; it is the detail this skill's router points at.

## 2. The law

1. **Translate meaning, not words** — idiom, tone, and the target audience win
   over word-for-word fidelity.
2. **Never invent** — a name, number, or date is carried exactly; nothing is
   guessed into the translation.
3. **Speech first, then text** — a voice clip is transcribed before any
   translation (the whisper door).
4. **Flag, don't guess** — a legal or contractual phrase is flagged for the
   Allfather's eye, never silently translated.
5. **The record stays in the hoard** — every translation lands in
   `$YMIR_HOME/hodd/docs/translation/records/` (or the seat's Downloads when
   it is the source), append-only, named by date. The hoard folder's
   `README.md` carries the fold index.

## 3. The current weave (2026-09-19)

- First transcription proved live: heimdall's `WhatsApp Ptt 2026-09-19 at
  19.49.37.ogg` (8:20, mono opus) → `~/Downloads/whatsapp-2026-09-19.txt` via
  whisper.cpp small.en on the RTX A5000 — 1,136 words, timestamped.
- Owed: translation of that transcript into the tongue the Allfather names.

## 4. Bragi's sibling — the knowing (Kvasir)

Kvasir (the scout) maps where the translation programs live and how they
connect — see `kvasir`'s agent card; the same `assets/programs.md` is his map.
The skald uses the tools; the scout knows the terrain. One craft, two hands.