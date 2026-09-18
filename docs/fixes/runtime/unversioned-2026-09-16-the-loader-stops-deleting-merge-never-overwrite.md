## runtime · unversioned · 2026-09-16 — the loader stops deleting: merge, never overwrite

### Why
- **Root cause of the Apodex-provider loss, mended at the source.** Two writers
  share the untracked `opencode.json`: `bin/valknut-load.sh` (structure, from
  `opencode.json.example`) and `bin/agents-config.sh apply` (the roster —
  providers and per-agent models, from `config/agents.yaml`). The loader
  re-rendered with `sed` + `mv`, so because the example carried only
  `llama.cpp`, **every loader run silently deleted the Apodex provider** that
  lived only in the live file. `config_out` now merges deep and
  `setdefault`-style: missing keys are added, existing ones are never
  overwritten, and the skills path is ensured. Verified by wiping the provider
  by hand: the next run reports `merged(provider.apodex)` and restores it, while
  an unrelated hand-added key survives untouched. Seeding happens only when the
  file is absent.
- **The changelog guard still bites, without punishing a follow-up.** The
  pre-push guard now accepts either the pushed range touching `CHANGELOG.md` or
  the branch's whole range since it left the trunk touching it — a commit that
  merely lands a file the record already tells needs no micro-entry. A branch
  whose entire range leaves untold is still refused.
- `bin/valknut-load.sh --status` reports the config outcome
  (`seeded` · `merged(…)` · `unchanged` · `kept`), so a silent stomp can never
  hide behind a "rendered" line again.
- `harness-int

### Files
- *(carried from the frozen CHANGELOG.md)*
