# The mouth: Kokoro, a local model, and a voice that starts before it finishes

**Component:** agents · **Seat:** heimdall · **Date:** 2026-10-21

## The ask

*"not piper voice — we should use kokoro … i wanna test to talk to him with streaming llm voice."*

**Kokoro was already installed and working** — `kokoro-serve.service` on `:8765` (OpenAI-compatible
`/v1/audio/speech`, 82M on the GPU) and `kokoro-speak` bound to F11. It was simply **not running**:
the unit is `enabled` but went `inactive` 18 s after boot (started, consumed 6.5 s of CPU, died). Started
again and verified: `POST /v1/audio/speech` → **200, 45,116 bytes** for one sentence.

## The chain

```
voice.sh[5]{step,engine,note}:
  "hear","arecord → whisper.cpp (`ggml-small.en`)","6 s default; `--file` and `--text` for testing"
  "think","Skírnir at the OWNER tier, digest only","templates first; `--model <id>` for free text"
  "the gate","no URL · no link · no image · canaries · NDA parties","the voice does not relax the law"
  "speak","**Kokoro** on :8765, one sentence at a time; Piper as fallback","speech begins before the answer ends"
  "record","`assistant.db` + Runes","with the digest hash used"
```

## Measured

```
skírnir (template)  → "OptiCat is a system for OVK …"            spoken by Kokoro
skírnir (model leg) → "OptiCat is a system designed for OVK …"   qwen3.5-9b, digest-only context
kokoro              → 200 OK, 45 KB wav for one sentence         resident server, ~2 s of audio
```

## What the voice did not change

He is still a mouth with no hands: no tool calls, no vault, no NDA fact to a non-party, no URL in an
answer. A spoken answer is the same answer — the walls are upstream of the microphone.

## What is next for talking properly

The **35B MTP** (`qwen3.6-35b-a3b@q4_k_xl-mtp`) for the free-text leg: the code takes any id via
`--model`, and the rail swaps to it, but a 14 GB load is 30–60 s on this card — so the honest order is
the small model for speech latency, the 35B for a considered answer, and the rail's one-resident rule
respected either way.
