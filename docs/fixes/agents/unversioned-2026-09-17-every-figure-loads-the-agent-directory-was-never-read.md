## agents · unversioned · 2026-09-17 — every figure loads: the agent directory was never read

### Why
- **The bug, stated plainly.** Twenty agent profiles existed, twenty symlinks
  pointed at them, and every gate was green — yet OpenCode loaded **three**
  agents. The symlinks lived in `.opencode/agent/` (SINGULAR). OpenCode reads
  `.opencode/agents/` (PLURAL). Twenty correct links sat in a directory no loader
  opened, so only `brokk` and `hnoss` — the two declared by hand in
  `opencode.json` — ever appeared.
- **The directory is fixed and migrated.** `.opencode/agent/` → `.opencode/agents/`
  (20 links, all resolving). `bin/valknut-load.sh` now writes the plural path and
  **migrates a legacy singular dir forward**, so an old home heals instead of
  silently keeping its agents invisible.
- **The roster now declares what it names.** `bin/agents-config.sh apply` only
  touched an agent already present in `opencode.json` (`if a in ablock`), so a
  figure the roster knew but the config had never seen stayed undeclared. The
  roster is the source of truth; a name in it now reaches the harness config.
- **A new gate catches the class.** `compliance-check.sh` gains **`roster`**: the
  roster (`config/agents.yaml.example`) and the canonical tree
  (`.agents/agents/*.md`) must name the same figures. A figure in the tree but not
  the roster falls to `default_model` and is never declared; a figure in the
  roster with no profile is a phantom. This is the check that would have caught

### Files
- *(carried from the frozen CHANGELOG.md)*
