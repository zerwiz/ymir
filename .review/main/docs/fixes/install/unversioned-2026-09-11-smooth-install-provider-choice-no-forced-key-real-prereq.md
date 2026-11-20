## install · unversioned · 2026-09-11 — Smooth install: provider choice, no forced key, real prereqs

### Why
- **Model provider is now the operator's choice** (`YMIR_MODEL_PROVIDER`):
  `opencode-go` (needs a key), `lmstudio` (keyless local), or
  `openai-compatible`. The bridge no longer forces `OPENCODE_GO_API_KEY`;
  with no key it auto-selects the keyless local provider so a fresh install works.
- **New:** `.agents/backend/model-bridge.py` (provider-aware, keyless-capable);
  `opencode-go-bridge.py` kept as a delegating shim so existing references work.
- **`bin/bifrost-bridge.sh` v2:** `--provider`, provider auto-selection, no hard
  env-file requirement, actionable errors per provider.
- **`bin/ymir-install.sh`:** installs `bun` for real (user-space, then a package
  hint); installs `mcp<2`; `engram` is now an honest `SKIP` with the Python
  version reason instead of a permanent WARN; distinguishes docker-group
  permission from a build failure.
- **`scripts/start.sh`:** fixed the early exit that skipped the gate API and all
  services whenever the SPA was already running.
- **Verified:** compliance 8/8; bridge relays models + chat + 404s; keyless
  start confirmed; `start.sh` raises Gate API, Nornir, Bifrost, visualizer.

### Files
- *(carried from the frozen CHANGELOG.md)*
