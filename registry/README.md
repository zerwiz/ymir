# Ymir — Global / Personal Workspace & Audit Trails

- `config/` — platform configuration, `portfolio.md` (project registry)
- `memory/` — global audit trail, `runes_audit.md`

Global (non-realm-scoped) state lives here. Realm-scoped data lives under `svartalfaheim/<realm>/`.
## Privacy

This tree is the operator's **private** world (business, marketing, personal,
memory, companies). It is deliberately untracked:

- `workspace/{work,personal,memory,companies}/` are in `.gitignore` — a clone
  never inherits another operator's data.
- Only the scaffold (`README.md`, `INSTALL.md`, `*.yaml`) and config examples
  are tracked, so the runtime has a shape without carrying private content.
- `bin/secret-guard.sh` blocks a commit that stages a private env file or an
  obvious secret. Wire it once with `bin/secret-guard.sh --install`.
