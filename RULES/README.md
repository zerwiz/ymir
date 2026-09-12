# RULES — the house law

Numbered, binding rules for how Ymir is organised. A rule is law: code, plans,
UI, and agents obey it, and a change that contradicts a rule must first change
the rule (append-only; never silently rewritten).

```
rules_index[5]{file,subject}:
  "01-domains.md","domains (Greinar) · houses · Eindri"
  "02-agents.md","agents: home, kinds, profile contract, no mock"
  "03-houses.md","houses = companies; ownership, records, boundaries"
  "04-hoard.md","Hodd: the one private place — secrets, docs, tenants, identity"
  "README.md","this index"
```

Keep each rule short and unambiguous; reference it from code where it bites.
