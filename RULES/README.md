# RULES — the house law

Numbered, binding rules for how Ymir is organised. A rule is law: code, plans,
UI, and agents obey it, and a change that contradicts a rule must first change
the rule (append-only; never silently rewritten).

```
rules_index[10]{file,subject}:
  "01-domains.md","domains (Greinar) · houses · Eindri"
  "02-agents.md","agents: home, kinds, profile contract, no mock"
  "03-houses.md","houses = companies; ownership, records, boundaries"
  "04-hoard.md","Hodd: the one private place — secrets, docs, tenants, identity"
  "05-platforms.md","one portable core + per-OS installation layers; core changes propagate"
  "06-append-only.md","some records are memory: append, never rewrite, never lose on a move"
  "07-config.md","configuration is never hardcoded: ports/hosts/paths/credentials resolve from env/config"
  "08-delivery-gate.md","PR-only delivery; treehouse worktrees; sandcastle sandboxes"
  "10-deployed-servers.md","every server/tool the runtime runs lives in the repo and is deployed from it"
  "README.md","this index"
```

Keep each rule short and unambiguous; reference it from code where it bites.

| 09 | `09-electron.md` | Electron is a local seat: local connections only, no login, the rune icon and entry installed, one lifecycle with the web. |
| 10 | `10-deployed-servers.md` | Every server/service/worker/MCP runs from a file the repo owns and is deployed from it (`bin/fleet-ensure.sh`); never hand-placed on a machine. |
