## gate · unversioned · 2026-10-11 — Rule 15: the vault is a confidential domain

### What

The Allfather's word: **some vault projects are under NDA and legally cannot leave
the vault** — a leak is fines and potentially prosecution for the user. This makes
that law and gives it a ward.

- **`RULES/15-vault-confidential.md`** — the law. Everything inside Hnitbjörg is
  confidential by default; vault content **never leaves the vault, in any form,
  local or remote**; no model, agent, embedding, log, ticket, plan, ledger, crash
  dump, or network ever sees it; vault work happens only while open and produces
  nothing outside; seal when done.
- **`AGENTS.md`** — the duty, in the always-loaded contract, under *Private data*:
  never copy vault content out, never send it to any model, and **refuse** a request
  that would move it.
- **`bin/gates/guards/vault-guard.sh`** — the ward. While the vault is OPEN it
  hashes every file inside the mount and **refuses to commit any file in the repo or
  the home whose content matches a vault file verbatim.** Seated in `guards.sh`'s
  `WARDS` (pre-push + CI) **and installed as a pre-commit hook in both trees**, so
  git runs it on every commit, including the hasty ones.
- **`RULES/README.md`** — the rule is indexed.

### Verified

- `tests/e2e/vault-guard-proof.sh` — **all pass**: a verbatim copy of a vault file is
  refused; an ordinary file is allowed; a sealed vault is reported, not silently passed.
- `guards.sh` → runtime · defaults · cron · features · **vault** all **PASS**.

### The honest limit (stated in the rule, not hidden)

A machine can catch a file copied out whole; it cannot catch a screenshot, a
paraphrase, or a paste into a remote model. Those are the operator's and the agent's
discipline — the ward raises the floor, it does not replace the law.

### Files

- `RULES/15-vault-confidential.md` (new)
- `bin/gates/guards/vault-guard.sh` (new), `bin/gates/guards.sh`
- `tests/e2e/vault-guard-proof.sh` (new)
- `AGENTS.md`, `RULES/README.md`
- (seated, machine-local) `.git/hooks/pre-commit` in the ymir repo and the home
