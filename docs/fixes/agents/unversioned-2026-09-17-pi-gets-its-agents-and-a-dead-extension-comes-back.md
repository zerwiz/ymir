## agents · unversioned · 2026-09-17 — Pi gets its agents, and a dead extension comes back

### Why
- **Pi has no agent loader.** Agent loading in Pi is a *package* (`pi-agents`,
  `pi-agent-mode`, `pi-simple-agents`), never a core feature — and Ymir installs
  none. So `.pi/agents/` held twenty correct profile links that **nothing in Pi
  ever read**. The same failure as OpenCode's singular `.opencode/agent/`,
  arrived at from the other side.
- **The fix ships in this repo, not a root-pi package.**
  `.pi/shared/extensions/ymir-subagents.ts` discovers the canonical
  `.agents/agents/*.md` tree itself and registers a `subagent` tool. A call runs
  the chosen figure as a nested model call in the current session: the figure's
  markdown body is its system prompt, its frontmatter `model:` picks the model
  where the machine serves it. `subagent({})` and `/subagents` list the roster.
- **It imports nothing.** `@earendil-works/pi-coding-agent` is not installed as a
  package, so an extension importing its types cannot load at all. This one takes
  `pi` as `any` and declares `parameters` as a plain JSON schema — the pattern
  every working extension in the tree already uses.
- **A rename that left a reader behind.** `skuld-branch-supervision.ts` imported
  `calmTranscriptClassIsVisible` / `CalmPresentationState` from
  `./lib/ro-visibility.ts`, but that module exports `roTranscriptClassIsVisible` /
  `RoPresentationState`. Pi refuses the **whole extension** at load, so Skuld's
  s

### Files
- *(carried from the frozen CHANGELOG.md)*
