## install · unversioned · 2026-09-16 — Apodex joins the Weave (research/planning provider)

### Why
- **Apodex provider.** Apodex-1.0-mini-Q4_K_M climbs into the machine as
  the research/planning GGUF on `http://127.0.0.1:1234/v1`, seated
  alongside llama.cpp coding models on :8080. LM Studio is retired; its
  :1234 port belongs to Apodex now.
- **Env template.** `.env.example` gains the `APODEX_*` block; the LM
  Studio block is marked RETIRED with its port claim corrected.
- **Smoke test.** `bin/apodex-smoke-test.sh` — probe or serve-and-test an
  Apodex seat; exits 0=pass, 1=fail, 2=unavailable. Never mutates config.
- **Research worker.** `bin/huginn-research-worker.sh` (Apodex-powered
  Eindri): takes a brief, recalls from Mimirsbrunn, dispatches to the
  Apodex chat/completions seat, writes a structured verdict, observes it
  back into the well. Wears the name **Huginn** per the naming law (the
  research seat; Gungnir stays the skill-synthesis engine).
- **Agents hall.** `.agents/agents/huginn-researcher.md` binds Huginn to
  the apodex model; `config/agents.yaml.example` registers the apodex
  provider and Huginn's seat; `opencode.json` carries the apodex provider
  block alongside llama.cpp; `bin/models-detect.sh` probes and emits the
  apodex provider for the Pi model file (`~/.pi/agent/models.json`).
- **Install seams.** Apodex rides the existing seams: models-detect merges
  it into the Pi models file at install; agents-config applies it into
  opencode.json. Mo

### Files
- *(carried from the frozen CHANGELOG.md)*
