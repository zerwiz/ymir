# Rule 07 named the operator and a collaborator by name — masked to roles

**Date:** 2026-11-23 · **Component:** rules (`RULES/07-config.md`) · **Errand:** `security-audit`

## What was wrong

Hœnir's security audit (2026-11-22) found that `RULES/07-config.md` lines 129–138 named a collaborator
(the security owner) and the operator (a person's name in the
example `ATLAS_OWNER=<name>`). The rule itself says *"Operations documents name roles, not people"* —
so the rule was violating its own clause D.

## What was built

- the security owner's name and login → "the security owner (the one who holds architecture, security, build and operations)"
- `ATLAS_OWNER=<name>`, `get_env(:owner, "<name>")`, `home:<name>`, `like home:<name>` → `<name>` placeholders

## What this does not decide

- **The public history** still carries the old wording (finding 1 of the audit). A history rewrite is the
  operator's decision.
- **The other findings** (vault key, marketing-stack.env, branch protection, Docker exposure, LM Studio
  connector) need the operator's word or sudo and are not addressed here.

## CHANGE LOG

- 2026-11-23 — written the night the audit arrived.
