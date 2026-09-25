## runtime · unversioned · 2026-09-25 — the global OpenCode config gets a writer

### Why
OpenCode's machine-wide config (`~/.config/opencode/opencode.json`) was the one
harness file with **no repo writer**: its `provider` block was hand-set, so a run
outside the checkout — another project, or a plain `opencode` in `/tmp` —
resolved only whatever a human had once typed there. This closes the last of the
three harness gaps named after the A2A set-up.

- **`bin/agents-config.sh apply` now also publishes the same provider block into
  the global config**, resolved from the hoard like every other model fact. The
  project `opencode.json` keeps the per-agent models; the global file becomes the
  machine's provider truth. Neither overwrites the other's keys (`setdefault`,
  deep) — the existing `ymir-local` provider and the hand-set `instructions`
  survive untouched.
- **Proved:** after `apply`, `~/.config/opencode/opencode.json`'s providers read
  `ymir-local · llama-swap · opencode-go`, and `opencode models` **from `/tmp`**
  lists `llama-swap/frontend-design-expert-8b` — the rail, resolved outside any
  repository.
- **One truth named:** `apodex/*` and `llama.cpp/*` remain in the **project**
  config only, because the hoard's `config/agents.yaml` does not list them as
  providers. That is a config decision, not a code fault — the writer carries
  exactly what the hoard declares.

galdr-reread: `harness-integration/README.md` (the opencode.json writers; the
global provider write).

### Files
- `bin/agents-config.sh`
- `.agents/skills/galdr-ymirsystem/assets/harness-integration/README.md`
