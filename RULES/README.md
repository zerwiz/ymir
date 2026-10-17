# RULES — the house law

Numbered, binding rules for how Ymir is organised. A rule is law: code, plans,
UI, and agents obey it, and a change that contradicts a rule must first change
the rule (append-only; never silently rewritten).

```
rules_index[15]{file,subject}:
  "01-domains.md","domains (Greinar) · houses · Eindri"
  "02-agents.md","agents: home, kinds, profile contract, no mock"
  "03-houses.md","houses = companies; ownership, records, boundaries"
  "04-hoard.md","Hodd: the one private place — secrets, docs, tenants, identity"
  "05-platforms.md","one portable core + per-OS installation layers; core changes propagate"
  "06-append-only.md","some records are memory: append, never rewrite, never lose on a move"
  "07-config.md","configuration is never hardcoded: ports/hosts/paths/credentials resolve from env/config"
  "08-delivery-gate.md","PR-only delivery; treehouse worktrees; sandcastle sandboxes"
  "10-deployed-servers.md","every server/tool the runtime runs lives in the repo and is deployed from it"
  "14-features.md","every feature explained: FEATURES.md (the catalogue) + docs/features/ (the how-tos)"
  "15-vault-confidential.md","the vault is a confidential domain: NDA content never leaves it, in any form"
  "16-confidential-session.md","work on the vault with no route off it: confined workdir, doors off, model tier, airlock"
  "17-no-dead-code.md","no dead code: a file, function, branch or constant nothing reaches is a claim that a feature exists"
  "18-distinct-gates.md","distinct gates: one class per service, one gate per class — public · team · client · operator · confidential · fleet"
  "19-two-planes.md","two planes: OUR functions (the well, Runes, plans, the vault, the agents) and THE TEAM'S (places, the suite) — never blurred"
  "20-the-well-appends.md","the well appends: an episode is never replaced, rebuilt-over or lost to a restore; the count never falls"
  "README.md","this index"
```

Keep each rule short and unambiguous; reference it from code where it bites.

| 09 | `09-electron.md` | Electron is a local seat: local connections only, no login, the rune icon and entry installed, one lifecycle with the web. |
| 10 | `10-deployed-servers.md` | Every server/service/worker/MCP runs from a file the repo owns and is deployed from it (`bin/fleet/fleet-ensure.sh`); never hand-placed on a machine. |
| 13 | `13-pi-extensions.md` | Pi extensions: **one home per extension** (`.pi/shared/extensions/` → `~/.pi/agent/extensions/`), pi's own layout (a directory needs `index.ts`), and `bin/seat/valknut-load.sh --check` as the gate. Two load paths means **no agent can be seated**. |
| 14 | `14-features.md` | Every feature is explained: `FEATURES.md` (the append-only master catalogue) + `docs/features/` (one plain-language how-to per user-facing feature), enforced by `bin/gates/guards/features-guard.sh`. |
| 18 | `18-distinct-gates.md` | Distinct gates: **one class per service, one gate per class**. public · team · client · operator · confidential (the vault) · fleet (agents). A door never serves two classes, and the refusal is the feature. |
| 19 | `19-two-planes.md` | **Two planes:** OURS (the operator + fleet — the well, Runes, plans, the vault, the agents) and **THE TEAM'S** (places, the suite, their chat/files/record). A function belongs to one plane; **there is no team well**. |
| 20 | `20-the-well-appends.md` | **The well appends:** an episode is written once and stays. A fork is a UNION, a repair ADDS, and the episode count and the log's lines never fall — enforced by `bin/records/well-guard.sh` (the `well` surface of Eir). |
| 15 | `15-vault-confidential.md` | The vault is a **confidential domain**: content under NDA never leaves it, in any form, local or remote; no model, log, embedding, ticket, or network ever sees it; enforced by `bin/gates/guards/vault-guard.sh`. |
| 16 | `16-confidential-session.md` | A **confidential session** (`bin/vault/confidential.sh`): work on the vault with no route off it — confined workdir, off-vault doors off, an explicit model tier (local/none/remote), and `--airlock` for no network at all; `confidential-guard` refuses out-of-vault commits. |
| 17 | `17-no-dead-code.md` | **No dead code**: an unreached file, function, branch or constant reads as a working feature and is not one; enforced by `bin/gates/guards/dead-code-guard.sh`. |
