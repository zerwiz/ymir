## agents · unversioned · 2026-09-11 — Chat uses the root Pi model catalog

### Why
- **Fix:** the Kaia chat guessed a llama.cpp model id by regex and fell through
  to the Bifrost bridge (`:4603` → 401) when the guess failed.
- **Now:** the gate API reads the operator's root Pi catalog
  (`~/.pi/agent/models.json`) for the exact provider → base URL, model id, and
  key (llama.cpp router `:8080`, `sk-not-key-required`). A chosen local model
  is tried only on its own base; the default is the operator's Pi default
  (`qwen3.6-35b-a3b@iq3_s`). `/api/chat/models` lists the real connected set.
- **Verified:** `gemma-4-12b@q3_k_s`, `qwen3.6-35b-a3b@iq3_s` (default), and
  `qwen3.5-9b@q4_k_s` all answered live; no 401.

### Files
- *(carried from the frozen CHANGELOG.md)*
