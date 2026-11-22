# 2026-11-22 — the voice head falls back to a free model when it fails

The operator, when Nanna went silent on a call: *"use a free model as fallback if models are failing."* The cause, measured: the voice head (an online model through `head-proxy.py`) answered **429 — weekly usage limit reached**, the engine's warm-up died on it, and nothing answered on the voice port.

`bin/voice/head-proxy.py` now tries, in order, when the head refuses a chat request with 402 · 403 · 408 · 429 · 5xx or cannot be reached:

1. `RODD_HEAD_FALLBACK_MODELS`: other models on the same endpoint (e.g. a free tier), with the fields such models refuse dropped (`chat_template_kwargs`, `reasoning_effort`, measured: the free tier answered 400 to the first);
2. `RODD_HEAD_FALLBACK_LOCAL`: `"<base_url> <model>"` on a local rail (free: this machine's GPU), key `RODD_HEAD_FALLBACK_LOCAL_KEY`.

Read from the environment or the operator's own Rödd settings (`hodd/secrets/rodd.env`); nothing is configured by default. Each fallback that answers is said on stderr, never a key.

Proved on a throwaway port: a request for the exhausted model answered 429 upstream and came back from the free model (`head-proxy: the head failed (429); answered by the fallback … beam-free`).

## CHANGE LOG

- 2026-11-22 — review-mend: added missing heading for #900
