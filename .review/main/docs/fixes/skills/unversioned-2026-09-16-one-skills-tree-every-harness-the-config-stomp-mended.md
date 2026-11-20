## skills · unversioned · 2026-09-16 — one skills tree, every harness; the config stomp mended

### Why
- **Every harness now reaches `.agents/skills`.** Pi was already right — its own
  code walks up from the cwd to `.agents/skills` (and `~/.agents/skills`), so it
  discovers Ymir's skills natively with no link and no config; a second root
  under `.pi/` would only double-load. Claude Code, Codex and Cursor read project
  skills from their own directory, so `bin/valknut-load.sh` now binds
  `.claude/skills`, `.codex/skills` and `.cursor/skills` to `../.agents/skills`.
  opencode reaches the tree through `skills.paths`. The install step `loaders`
  runs the loader, so a fresh install gets all of it.
- **The `harnesses` gate (G14) now asserts the skills surfaces too** — opencode's
  config, Pi's native root, and the three links — so a harness silently loading
  nothing can no longer pass.
- **Defect mended: the loader was stomping `opencode.json`.** `bin/valknut-load.sh`
  renders `opencode.json` from `opencode.json.example`, and that example carried
  only `llama.cpp` — so a loader run silently **deleted the Apodex provider**,
  which had only ever lived in the generated file. The example now carries Apodex
  as well, with the served id `apodex-1.0-mini`, so a re-render cannot drop it.
- `bin/valknut-load.sh --status` now reports every surface (agents *and* skills)
  with a true row count instead of a hardcoded header.
- Assets: `harness-integration/README.md` gains the skill-loc

### Files
- *(carried from the frozen CHANGELOG.md)*
