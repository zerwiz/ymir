## gate · unversioned · 2026-10-12 — Rule 18: distinct gates (one class per service, one gate per class)

### What

The Allfather: *"we need to have distinct gates from what's private and what's team
data, etc."* Ymir holds material with genuinely different audiences — a public site, a
team's shared work, a client's realm, the operator's own hoard, and NDA-grade vault
content — and treating them as one boundary is how a teammate ends up reading a private
plan, or one leak opens every surface.

Rule 18 makes the boundary **many gates, each with its own mechanism**:

- one **class** per service (a service serving two classes has two doors, or it is mis-built);
- one **gate** per class — and the **mechanism** differs, not only the policy:
  public (open) · team (SSO) · client (SSO + realm role) · operator (the operator's own
  identity) · confidential (the vault, Rules 15/16) · fleet (agent tokens per seat);
- a door **never** serves two classes; crossing carries proof naming the class;
- **confidential is a mechanism, not a policy level** — it never leaves the vault.

**The refusal is the feature:** every class must prove a negative — the wrong class is
refused *and recorded* — or "distinct gates" is aspiration, not architecture.

### Verified

- The rule is registered in `RULES/README.md`'s index (count corrected to 14) with a
  table row; it cites and does not restate Rules 04 (the hoard), 15/16 (the vault), and
  the realm boundary law.
- It is consistent with the governed-path law: the team/identity half is planned in plan
  77, whose Part 9 carries the same classes and gates.

### Files

- `RULES/18-distinct-gates.md`
- `RULES/README.md`
