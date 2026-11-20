## sessrumnir · unversioned · 2026-09-16 — Apodex seat verified; the Weave mended

### Why
- **Correction (cites the entry below, never rewrites it).** The earlier
  entry said *"LM Studio is retired; its :1234 port belongs to Apodex now."*
  That was false as carved. LM Studio still holds `:1234` and is what serves
  the Apodex GGUF; Apodex took the **model seat**, not the server.
- **Live verification.** `bin/apodex-smoke-test.sh` → PASS (valid tool-capable
  response, exit 0). `bin/huginn-research-worker.sh` with **bare defaults** →
  `status: completed`, verdict written, observed into Mimirsbrunn. The Apodex
  seat (`http://127.0.0.1:1234/v1`) is live.
- **One model id, everywhere.** The seat serves **`apodex-1.0-mini`**; the
  worker, smoke test, `.env.example`, `opencode.json`, `config/agents.yaml.example`
  and Huginn's profile now all say so. Previously three names drifted
  (`apodex/Apodex-1.0-mini-Q4_K_M`, `apodex/apodex-mini-q4`, the served id) and
  the default worker call failed with `No models loaded`.
- **Four defects mended.** `bin/huginn-research-worker.sh` made executable
  (was 644 — bare invocation died with `Permission denied`); the smoke test's
  `--serve` GGUF path corrected to
  `~/Models/FlameF0X/Apodex-1.0-mini-Q4_K_M-GGUF/apodex-1.0-mini-q4_k_m.gguf`;
  `bin/models-detect.sh` env var renamed from the typo `APEDEX_URL` to
  `APODEX_URL`.
- **Weight truth.** The Apodex Q4_K_M weights are **21.7 GB**, not the ~4–6 GB
  the plan assumed — it ca

### Files
- *(carried from the frozen CHANGELOG.md)*
