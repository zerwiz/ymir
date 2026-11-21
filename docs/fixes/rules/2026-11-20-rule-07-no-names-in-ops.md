# Rule 07 gains clause D: no person or machine is built into how a system runs

**Date:** 2026-11-20 · **Component:** rules · **Door:** `RULES/07-config.md` (appended amendment D)

At the CTO's word — *"I do not want our overall engineering and devops practices to be fragile. So no hardcoded
dev names for ops"* and *"this way we can audit deployment accountabilities"* — RULES/07 gains an appended
amendment. A person's or machine's name is never a default, a fallback, a setting or a runnable example in code,
configuration, scripts, deploy kits, CI or runbook commands. What identifies an owner is given, with no default,
and a program without it refuses to start. Examples use placeholders; operations documents name roles. Each person
deploys as their own account, and every change a deploy kit makes is recorded with who, when and which commit. A
client's name stays out of code: a guard that needs it reads a list outside git and fails closed. Records,
papers and named test fixtures are not judged. A repository that deploys enforces the clause with a gate in its
required CI check (atlas-vault: `scripts/gates/ops-names.sh`).

## CHANGE LOG

- 2026-11-20 — written with the change it describes.
