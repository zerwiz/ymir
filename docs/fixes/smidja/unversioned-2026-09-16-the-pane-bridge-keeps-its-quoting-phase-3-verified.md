## smidja · unversioned · 2026-09-16 — the pane bridge keeps its quoting; Phase 3 verified

### Why
- **The Apodex plan's last open verification is closed.** Run in a herdr pane —
  `bin/herdr-run.sh run huginn-research -- bin/huginn-research-worker.sh --brief
  "…" --output-dir …` — the worker recalled, dispatched to the Apodex seat, wrote
  its verdict, and observed it into Mimirsbrunn (`status: completed`, verdict
  *"The capital of Norway is Oslo."*). Phase 3 needed a spawn, which the
  read-only session lock had forbidden; it was run once the lock was this
  session's.
- **Defect found and mended — `bin/herdr-run.sh run` lost its quoting.** A pane
  runs its command through a *shell*, but the bridge handed herdr the raw argv.
  An argument containing spaces reached the pane as separate words, so
  `--brief "In one sentence: …"` arrived as `--brief In one sentence: …` and the
  worker died with `error: unknown arg: one`. Every real brief is multi-word, so
  the documented invocation could never have worked. `run` now quotes each
  argument on the way in (`printf '%q'`), verified by re-running it.
- Asset updated in the same change: `.agents/skills/ymir-host/assets/thjazi.md`
  carries the quoting rule.

### Files
- *(carried from the frozen CHANGELOG.md)*
