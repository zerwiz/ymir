# Runbooks

Task-oriented guides for operating a Ymir home. Each is written for the
operator, not just the maintainer.

```
runbooks[8]{file,subject}:
  "models.md","choose models per agent; local (llama.cpp) vs hosted; per-machine overlays"
  "agents.md","Eindri profiles: where they live, how to add/run/dispatch one"
  "agent-permissions.md","set what each agent may do — the bash gap and recommended postures"
  "updates-and-migrations.md","update the runtime; heal old homes (bin/ymir-migrate.sh)"
  "secrets-and-hoard.md","Hodd: secrets by path, secret-guard, rotation + history scrub"
  "worktrees-isolation.md","Yggdrasil worktrees: isolated by default, --main opt-out, see them in Hlidskjalf, merge"
  "a2a.md","Ratatoskr — talk between agents over A2A: engine, MCPs, addressing, injection, registration"
  "realm-onboarding.md","onboarding a realm/tenant"
```

Related: `.agents/skills/galdr-cli/assets/installation.md` (first setup),
`.agents/skills/galdr-cli/assets/registry.md` (inventory).
