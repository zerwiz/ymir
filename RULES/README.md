# RULES — the house law

Numbered, binding rules for how Ymir is organised. A rule is law: code, plans,
UI, and agents obey it, and a change that contradicts a rule must first change
the rule (append-only; never silently rewritten).

```
rules_index[8]{file,subject}:
  "01-domains.md","domains (Greinar) · houses · Eindri"
  "02-agents.md","agents: home, kinds, profile contract, no mock"
  "03-houses.md","houses = companies; ownership, records, boundaries"
  "04-hoard.md","Hodd: the one private place — secrets, docs, tenants, identity"
  "05-platforms.md","one portable core + per-OS installation layers; core changes propagate"
  "06-append-only.md","some records are memory: append, never rewrite, never lose on a move"
  "07-config.md","configuration is never hardcoded: ports/hosts/paths/credentials resolve from env/config"
  "README.md","this index"
```

Keep each rule short and unambiguous; reference it from code where it bites.
