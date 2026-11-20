## agents · unversioned · 2026-09-16 — a sandboxed worker cannot think: `auto` stops killing agents

### Why
Spawning an Eindri with the default `--isolation auto` produced an **empty pane
and no status line**. The cause: `auto` chose Utgard whenever the image existed,
and Utgard runs with `--network none` — so the worker could reach neither its
cloud model (OpenCode Go) nor a local one (llama.cpp) and died at launch, silently.

- **`auto` now keeps the worker in its worktree.** A spawned Eindri is a
  model-driven worker: it must reach a model endpoint to think. Utgard is for
  untrusted *code*, not for the agent's own brain, so the automatic choice is
  `off`, and it says why.
- **`--isolation on` warns loudly.** It stays available for a sandbox that can
  actually reach a model, but it now prints that Utgard has no network and the
  agent will die silently without one.

### Files
- *(carried from the frozen CHANGELOG.md)*
