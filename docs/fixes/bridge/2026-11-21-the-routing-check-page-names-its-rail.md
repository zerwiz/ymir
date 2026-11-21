# bridge · 2.1.3 · 2026-11-21 — the routing check's page names the rail it sends to

The second review of the chain (`2026-11-21-the-last-teaching-of-retired-engines.md`) found one more line that
still taught the retired model daemon. It was not in that note's *Kept, on purpose* table, so it was a miss,
not a decision.

## Changed

- `assets/reference/docs/verification/runtime-backends.md` line 118 said the opt-in routing live check sends
  to the retired daemon. The check (`.agents/tests/fm-harness-adapter-instructions-live-e2e.test.sh`) sends to
  the local llama.cpp rail through its OpenAI-compatible API. The line now says so, and names the
  `FM_HARNESS_ADAPTER_RAIL_URL` override and its default `http://127.0.0.1:8080/v1`.

No behaviour changed; this is a page catching up with the test.
