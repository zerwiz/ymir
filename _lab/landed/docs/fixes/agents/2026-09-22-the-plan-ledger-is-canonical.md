## agents · unversioned · 2026-09-22 — the plan ledger is canonical

### Why
The operator's plan shelf never matched the contract. The 2026-09-17 layout
sweep taught every reader `$YMIR_HOME/memory/plans/<domain>/` — but the real
ledger lives at `svartalfaheim/<realm>/workspace/<project>/plans/` (the ymir
project's: `svartalfaheim/whynotproductions/workspace/ymir/plans/`, plans
01–42, already named "the ONE canonical ledger" in the home map). Result: plans
accumulated in a mirror inside the public tree, a fresh federation plan was
filed in the retired shelf, and the system had no pointer to the truth.

### What
Every teaching byte now names the canonical ledger:
- `AGENTS.md` — layout tree + the Ratatoskr spec pointer + the re-layout note
  (2026-09-22 supersedes the 2026-09-17 filing note; `memory/plans/` is
  retired, `BROKK_PLANS_DIR` may point the runtime at the ledger).
- `.agents/agents/brokk.md` — the plan workflow (file → index → number) now
  names the ledger and its numbering.
- `forseti-reviewer.md` · `mimir-planner.md` · `tyr-check/SKILL.md` ·
  `ratatoskr-a2a/SKILL.md` · `hodd/AGENTS.example.md` — pointer replaced.
- The physical shelf move (public-tree mirror folded into the ledger,
  federation plan renamed 29→42 and reconciled with plans 37/39/36/09/25–27)
  was committed directly to the private home — the private side carries the
  bytes; this change teaches the public contract.

### Files
- `AGENTS.md`
- `.agents/agents/brokk.md`
- `.agents/agents/forseti-reviewer.md`
- `.agents/agents/mimir-planner.md`
- `.agents/skills/tyr-check/SKILL.md`
- `.agents/skills/ratatoskr-a2a/SKILL.md`
- `hodd/AGENTS.example.md`

### Note
The 2026-09-17 fix notes remain as history (append-only); this note is the
correction that supersedes them.