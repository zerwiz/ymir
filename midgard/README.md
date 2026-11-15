# MIDGARD — Shared Design Assets

Cross-tenant assets that are **public by design**: the design system and the
shared libraries any realm may pull.

**What does NOT belong here.** Company knowledge — policies, vision, specs,
client names, wiki pages. That is tenant data, scoped per company, and lives at
`$YMIR_HOME/hodd/identity/companies/`. This repo is public; a company wiki in it
would publish that company's internals.

## Contents
- `design-system/` — shared UI components, design tokens, icon set
- `shared-packages/` — internal npm/cargo/python libraries (public)
- `infrastructure/` — shared Terraform / Docker / Kubernetes configs
- `github_org_repos/` — central repositories
  - `shared-core-api/` — example shared repo (with `.yggdrasil/` worktrees)

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.

## 2026-11-14 — three files left this shelf for the operator's home

Appended, never rewritten (Rule 06). Three Markdown files on this shelf were not shared public
assets: two letters to named partners about the operator's own product work, and a partner-facing
business launch document. A letter is private by nature and a public repository is the one place it
must never sit, so they moved into the operator's home by a recorded move (Rule 11; plan 288 step 7,
plan 287 P4).

**What stayed.** Everything else on this shelf — `design-system/`, `shared-packages/`,
`infrastructure/`, `github_org_repos/` — is public by design and unchanged.

**What a user of this repository should take from it.** The *shape* of a partner letter lives in the
code (`systems/snotra/`, the letter templates) and in the design system; the *words* are the
operator's and live in his home. If you are writing to a partner of your own, use an invented name in
any example, and keep the real letter out of your repository.
