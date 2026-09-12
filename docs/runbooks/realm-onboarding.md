# Runbook — Onboarding a Realm

A realm (tenant) is an isolated shop floor under `svartalfaheim/`. Onboarding one
creates its tree, secrets, persona, and registry row — and leaks nothing across
boundaries.

## Prerequisites

- The operator (Allfather) has approved the new realm and named its house.
- Git auth is good: `gh auth status`.

## Steps

1. **Create the realm tree.**

   ```bash
   realm=<realm>
   mkdir -p svartalfaheim/"$realm"/{workspace/{company,marketing,development,life,memory/daily},projects,companies}
   touch svartalfaheim/"$realm"/projects/.gitkeep
   ```

2. **Secrets.** Copy the example and fill it; never commit it.

   ```bash
   cp svartalfaheim/"$realm"/.env.realm.example svartalfaheim/"$realm"/.env.realm
   chmod 600 svartalfaheim/"$realm"/.env.realm
   ```

   `.gitignore` already ignores `svartalfaheim/*/.env.realm`.

3. **Persona.** Write `svartalfaheim/"$realm"/AGENTS.md` (or `Brokk.md`) — the
   realm's operating brief and its house.

4. **Houses & projects.** Add entity cards under
   `svartalfaheim/"$realm"/companies/<house>/entity.md` using
   [`.agents/assets/templates/company_entity.template.md`](../../.agents/assets/templates/company_entity.template.md).
   Register the realm in `data/projects.md`.

5. **Register the house accents** (if new) in `src/data/realms.ts` (Hlidskjalf) and
   `midgard/design-system/tokens.css`.

6. **Verify.**

   ```bash
   test -d svartalfaheim/"$realm"/workspace && echo tree-ok
   bash bin/valknut-load.sh --status
   bin/brokk status
   bash .agents/skills/galdr-cli-cli/scripts/compliance-check.sh
   ```

## Rules

- **Boundaries are sacred:** never read, write, or reference another realm.
- **Secrets stay in `.env.realm`**, never in Markdown.
- **Split or merge a house only by a new append-only entry** — never silently.

## Done when

The realm tree, `.env.realm`, persona, and entity cards exist; the realm is listed
in `data/projects.md`; `bin/brokk status` and the compliance gate are green.
