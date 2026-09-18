## hoard · unversioned · 2026-09-17 — the schedule is the user's: cron leaves the tree, lives in the home

### Why
- **The tracked tree no longer carries the live cron schedule.** The Nornir
  scheduler now resolves the schedule in this order: `BROKK_CONFIG_OVERRIDE`
  (explicit) → **the home's own `$YMIR_HOME/config/cron.yaml`** (users set
  their jobs there) → the repo's `config/cron.yaml.example` (a template, never
  the live list). `bin/nornir-cron-start.sh` resolves the home through
  `bin/hoard-lib.sh`, the one answer the whole runtime shares.
- `config/cron.yaml` → `config/cron.yaml.example` (the tracked template stays;
  the live schedule lives in the operator's home).
- **The marketing stack can be provisioned on any computer** —
  `bin/ymir-marketing-stack.sh up|status|down|doors` stands Mautic + Postiz +
  Activepieces (+ optionally Forgejo) from the same OSS engines the server
  runs, env-driven, ports virtualized, secrets generated once into the home
  (never inline); agents (Bragi · Sindri) provision it for any user.
- **Bragi's scrape round, honest to Firecrawl** — `bin/nornir-job-bragi-scrape.sh`
  reads the operator's `config/scrape-sources.yaml` and scrapes with the real
  Firecrawl SDK (scrape/search + markdown, BYOK key from the home's secrets),
  landing clean markdown in the marketing workspace and carving a Rune.

galdr-reread: `.agents/skills/galdr-ymirsystem/assets/nornir-jobs.md` — §2
rewritten (the schedule is the user's; example template; the four-inputs
contract

### Files
- *(carried from the frozen CHANGELOG.md)*
