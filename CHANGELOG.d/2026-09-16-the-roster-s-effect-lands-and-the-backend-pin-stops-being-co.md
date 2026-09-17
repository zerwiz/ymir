## 2026-09-16 — the roster's effect lands, and the backend pin stops being committable

Applying the private roster (`bin/agents-config.sh apply`) writes the resolved
model into each agent's canonical profile. Flipping the two local agents to Pi
made that visible — and surfaced a small ignore hole.

- **Profiles follow the roster.** `sindri-developer.md` and `kvasir-scout.md`
  now carry their **Pi** ids (`llamacpp-coder/qwen3-coder-30b`,
  `llamacpp/qwen3.5-9b`), and `huginn-researcher.md` its declared model — the
  output of `apply` against the operator's roster. These profiles are what the
  harnesses load, so the local agents now run on Pi rather than through OpenCode.
- **`.agents/config/backend` is ignored.** The pinned terminal backend is
  machine-local, but `config` is a **symlink** to `.agents/config`, so the
  `config/*` rule never matched it and the pin was committable. The file is named
  in `.gitignore` instead.
