# Operator runbooks

Task-oriented guides under `docs/runbooks/`, written for the operator:

```
runbooks[5]{path,load_when}:
  "docs/runbooks/models.md","choose models per agent; local vs hosted; per-machine overlays"
  "docs/runbooks/agents.md","Eindri profiles: home, add, run, dispatch"
  "docs/runbooks/tailscale-sync.md","sync pi data across your own machines over Tailscale"
  "docs/runbooks/updates-and-migrations.md","update the runtime; heal old homes (ymir-migrate)"
  "docs/runbooks/secrets-and-hoard.md","Hodd: secrets by path, secret-guard, rotation + scrub"
```

Index: `docs/runbooks/README.md`. When a host task has an operator-facing
procedure, add a runbook there and a row here.
