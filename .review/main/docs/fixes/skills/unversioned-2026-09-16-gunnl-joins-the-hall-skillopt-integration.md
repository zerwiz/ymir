## skills · unversioned · 2026-09-16 — Gunnlöð joins the hall (SkillOpt integration)

### Why
- **SkillOpt integration.** `pip install skillopt` into `.venv/`; training
  loop (`skillopt-train`), eval (`skillopt-eval`), and nightly
  self-evolution (`skillopt-sleep`) available for Smíðja prompts and
  Ymir skills. Nightly Nornir job at 00:30 (bin/nornir-job-skillopt-sleep.sh),
  staged artifacts only — Allfather approves before adopt. One-time setup:
  `bin/skillopt-setup.sh`.
- **Naming.** SkillOpt adopted the name **Gunnlöð** (keeper of the mead of
  poetry — distills trajectories into refined skill artifacts). Added to
  `.agents/assets/agents/naming.md` (platform map, 28 subsystems),
  `.agents/skills/galdr-ymirsystem/assets/registry.md` (skills + external tools),
  `README.md` (System Map + Skills + gratitude), `NOTICE` (MIT attribution).

### Files
- *(carried from the frozen CHANGELOG.md)*
