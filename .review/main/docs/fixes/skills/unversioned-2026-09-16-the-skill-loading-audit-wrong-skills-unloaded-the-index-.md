## skills · unversioned · 2026-09-16 — the skill-loading audit: wrong skills unloaded, the index made true

### Why
- **Three phantom skills stopped loading.** opencode was loading `galdr-compliance`
  and `galdr-crafter` — both superseded, their work long since moved to
  `tyr-check` — and `NSR`, the NSR scaffolding spec, which sat at
  `assets/nsr/SKILL.md` carrying frontmatter. A recursive scanner walks
  `skills.paths` to *any* depth, so all three were announced to every agent as
  live skills. The two galdr crafters are removed; the NSR spec is renamed
  `assets/nsr/scaffold-spec.md` and stays a document (its sibling templates
  carry no frontmatter and were already inert).
- **Two gates added, one per failure class** (`compliance-check.sh`):
  - **`harnesses` (G14)** — every link in `.claude/agents`, `.codex/agents`,
    `.cursor/agents`, `.pi/agents`, `.opencode/agent` must land, one hop, in the
    canonical `.agents/agents/` tree (Rule 02), and no nested `SKILL.md` may
    carry frontmatter. One hop deliberately: Galdr's agent file *is* the skill,
    by the dual-surface rule.
  - **`skillindex` (G15)** — every real skill dir must be named in
    `.agents/skills/README.md`, and every `.agents/skills/<name>` path the assets
    cite must exist. Lines marked planned/legacy/superseded/removed/abandoned/
    retired are exempt by intent.
- **The drift they exposed, mended:** the canonical index listed 23 skills while
  26 existed (`groa-update`, `lifecycle`, `rules-check-drift` were mis

### Files
- *(carried from the frozen CHANGELOG.md)*
