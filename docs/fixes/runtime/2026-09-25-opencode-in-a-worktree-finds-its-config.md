## runtime · unversioned · 2026-09-25 — OpenCode in a worktree could not find its own config

### Why
OpenCode is **project-scoped**: it reads `opencode.json` from the checkout it
runs in. That file is untracked (it carries absolute paths), so a Yggdrasil
worktree — a fresh git worktree with no copy — had **none**. Reproduced from
`.yggdrasil/harness-wiring-fix`: the mesh and `ymir-local/*` resolved (global
config), but the project providers **`llama.cpp` · `llama-swap` · `apodex`** did
not, and neither did the per-agent models. A worker seated in a worktree could
not reach the local rail.

- **One author, by link.** `bin/valknut-load.sh --opencode` now points every
  `.yggdrasil/*/` at the one config with a **relative symlink**
  (`opencode.json -> ../../opencode.json`). There is still exactly one
  `opencode.json`; the worktree borrows it, so the two cannot drift, and
  `.yggdrasil/` is gitignored so nothing is ever tracked.
- **Proved:** with the link in place, `opencode models` from inside the worktree
  lists `apodex/apodex-1.0-mini`, `llama-swap/frontend-design-expert-8b`,
  `llama.cpp/frontend-design-expert-8b@q4_k_m` — the providers that had vanished.
- **Named, not fixed here:** the seat's **global** OpenCode config still has no
  repo writer — `bin/a2a-mcp.sh` merges the mesh and well into its `mcp` block,
  `fleet-ensure` writes the well door, but `provider` and `instructions` remain
  hand-set. That is the next writer to seat.

galdr-reread: `harness-integration/README.md` (the opencode.json writers; the
worktree link).

### Files
- `bin/valknut-load.sh`
- `.agents/skills/galdr-ymirsystem/assets/harness-integration/README.md`
