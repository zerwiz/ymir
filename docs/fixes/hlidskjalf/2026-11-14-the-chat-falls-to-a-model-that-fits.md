# A chat that cannot load the big model answers from one that fits — and says which

**Date:** 2026-11-14 · **Component:** hlidskjalf (`apps/hlidskjalf/server/chat-ladder.ts`, `server/index.ts`) · **Plan:** 275 item 23

## What was wrong

OmniChat had two roads to a model and both failed at once at 03:16. The rail could not load the big local model
(cudaMalloc of 1,184 MiB, while the voice engine held 2,762 MiB), and Bifrost was pointed at a retired LM Studio. The
chat could only say `The well is local; no model backend answered (http://127.0.0.1:4603/v1 → 500)` — a status code
where the operator needed the reason, and no attempt at a model that would have fitted beside the voice.

## The fix

The chat now has a **ladder** and a **voice for its own decisions**, both pure functions in `server/chat-ladder.ts` so
they can be proved without a server:

1. **The ladder.** `postChat` asks for what the operator asked for, then the models that FIT — the small local preset
   (`CHAT_FITS_MODEL`, default `qwen3.5-9b@q4_k_s-summarizer`), then every online road, which costs the card nothing.
   A fallback answer carries one sentence naming the model that answered and why it was not the one asked for.
2. **The fault is named.** `chatCompletion` reads the provider's error body; llama.cpp's and CUDA's out-of-memory
   words (`cudaMalloc`, `out of memory`, `failed to allocate`, …) are recognised as the CARD being full, not the model
   being wrong. With nothing left to try, the chat says *the card is busy with the voice* — with the engine's own MiB
   from `bin/model/vram-ledger.sh who --json` (memoised 5 s) and the card's size — and how to get it back
   (`bin/voice/voice-idle.sh status`). A card with no voice on it says the card was full. A real outage keeps the
   honest message, status and all.

The reply row still carries the model that answered, so the surface can show it too.

## Verified

`apps/hlidskjalf/server/chat-ladder.test.ts`, run by `node --test` (11 checks): the card's own words are recognised
and an ordinary provider error is not mistaken for them; the ladder puts the small local preset first, then the online
road, never retries the model already tried, and repeats nothing; a fallback note names the model and the voice
holding the card; with nothing loadable the message begins *The card is busy with the voice*, quotes `2,762 MiB … of
the 16,384 MiB card`, points at the idle-out, and does not fall back to "no model backend answered"; a plain outage
still reports its status honestly.

Wired into `bin/gates/ci-verify.sh` as `chat-ladder`.

## Not done here

The gate on this seat runs the PIN, so the new chat text reaches the Allfather's window when the pin flips, not
before. No restart was needed for this half.

## CHANGE LOG

- 2026-11-14 — review-mend: added missing heading for #750
