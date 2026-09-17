## 2026-09-16 — the roster can finally run an agent on Pi

`bin/agents-config.sh apply` wrote **every** agent's model into `opencode.json`'s
agent block, whatever harness that agent used. So an agent set to run on **Pi**
(native local models) would have had its Pi model id —
`llamacpp/qwen3.5-9b` — written into OpenCode's config, which cannot resolve it.
That is why the roster's two local agents were pinned to `harness: opencode` with
opencode-style ids: there was no working way to put an agent on Pi.

- **`apply` is now harness-aware.** Only `opencode`-harness agents are written
  into `opencode.json`; a `pi` (or `hermes`) agent is left out, its model id going
  to the resolve cache that `bin/agent-run.sh` reads. The providers block is
  unchanged — a provider's endpoint is a real fact OpenCode may still want.
- The way this is meant to be used: declare a local agent's model as its **Pi**
  id (`llamacpp/qwen3.5-9b`, `llamacpp-coder/qwen3-coder-30b` — the ids `pi
  --list-models` reports) with `harness: pi`; the roster is then Pi-driven with no
  per-machine hand-editing.
- `galdr-reread`: `assets/harness-integration/README.md` — the two writers of
  `opencode.json`, and the rule that only OpenCode agents belong in it.
