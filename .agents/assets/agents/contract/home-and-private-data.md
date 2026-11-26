Read when: writing, moving or committing anything private (a plan, a memory, a note, an identity, a schedule), deciding where a file belongs, or keeping a home current.

# The home and private data

Part of the Ymir contract. The prior text is kept verbatim in `docs/contract-history/AGENTS-2026-11-24.md`.

## The first law (RULES/04)

**Never store personal or private data in this repo.** Not a secret, a key, a name, a plan, a schedule, a client, a
credential or a note-to-self. Not in a file, a comment, a commit message, a test fixture or a document. This repo is
public; the home is the vault.

**The repository is 100 % agnostic** (2026-11-14, RULES/04 and RULES/25). At the operator's word: *"it's critical that
ymir's repo is 100% agnostic; our special tooling etc belongs in ymir home"* · *"it's a public repo and users might run
their fleets in different ways."* The first law forbids private **data**; this widens it to private **shape**.

- **What belongs here:** only what any operator's install needs: the engine, the apps, the tools, the gates, the
  `*.example` templates, and the documents that teach them.
- **Never here, in any file:** a real person, client, company, mail domain, meeting or NDA; the operator's host names,
  user names, tailnet name or addresses.
- **Never assumed:** a machine count, a role layout (which machine is the heart), a delivery road (who merges), or a
  model on a particular box. All of these are read from the operator's home (`hodd/data/fleet.json`,
  `hodd/identity/projects.yaml`, `config/`), and the default is a fleet of one machine.
- **The operator's special tooling lives in the home.** Automations written for one company's meetings, one client's
  boards, one mail domain or one person's workflow go to `$YMIR_HOME/.agents/skills/` and the home's own scripts and
  config. A feature this repository ships is generic first.
- **Examples use invented names** (`Ada`, `example.org`, `host-a`). Fix notes name roles (*the heart*, *the dev
  machine*, *a second machine*), never a machine.
- **It is audited, not trusted.** A whole-tree scan for the operator's names, domains and hosts runs on the heart's
  clock twice a day and on every push, with the deny list kept in the home. A finding is a red gate and a notice to the
  operator (the operator's plan 287).

## Where the home is

Everything private lives at **`$YMIR_HOME`** (default `~/Documents/ymirhome`), env-driven, never in this repo.
`$YMIR_HOME/hodd/` **is** the private data path; there is no second, flat copy. `bin/vault/hoard-lib.sh` resolves it
(`hoard_root`), and it is the single source of truth: a script that needs the hoard calls it, never a hardcoded path.
All scripts reference `$YMIR_HOME` (with `YMIR_HOARD`, `YMIR_STATE_DIR` and the like as overrides). The repo ships
`*.example` templates; the runtime reads from `$YMIR_HOME`, never from the repo tree.

The home has **four shelves**, one kind of material each (plan 331, 2026-11-19):

| Shelf | Holds |
|---|---|
| `hodd/` | the **record**: memory, identity, plans, secrets, reference and docs |
| `life/` | the **operator's own material**: personal, work, marketing, meetings and outreach |
| `state/` | **runtime state** written by supervisors |
| `config/` | **settings** (for example `agents.yaml` and per-machine overlays) |

**Where each shelf lives is not restated here.** Read it from `$YMIR_HOME/.ymir-layout.yaml` (the shape) and
`$YMIR_HOME/hodd/identity/home.yaml` (the master register: every register and the shelf it governs). Prose that
describes the layout goes stale the first time a shelf moves. An older home is moved by migration
`0026-life-and-state-out-of-hodd`, which leaves the links `hodd/life -> ../life` and `hodd/state -> ../state` for one
release cycle. Eir's `hoard` surface names a shelf holding the wrong kind of material, and
`bin/gates/guards/retired-path-guard.sh` refuses a new file that teaches a retired path. The how-to is
`docs/features/the-four-shelves.md`.

Where outputs go, in the shelves' terms:

| Kind | Where |
|---|---|
| Business and strategy | `$YMIR_HOME/hodd/identity/companies/` |
| Marketing and social | `$YMIR_HOME/life/marketing/` |
| Software specs | `$YMIR_HOME/life/work/` |
| Personal and schedules | `$YMIR_HOME/life/personal/` |
| Daily logs | `$YMIR_HOME/hodd/memory/daily/YYYY-MM-DD.md` |
| The global audit (Runes) | `$YMIR_HOME/hodd/memory/runes_audit.md` |
| Shared **public** assets | `midgard/` (in this repo) |

**Plans** live only in the canonical ledger, one shelf per project:
`svartalfaheim/<realm>/projects/<project>/plans/` with its README as the index. The `memory/plans/` shelf is retired;
never file a plan there. `hodd/plans/` holds only live personal working plans. `BROKK_PLANS_DIR` may point the runtime
at the ledger. The private contract lives at `$YMIR_HOME/AGENTS.md` (untracked); its shape is `hodd/AGENTS.example.md`.

## Editing the home

- Edit the home through `bin/vault/home-sync.sh`: `begin` before the edit, `ship "<msg>" <named paths…>` straight after.
  It commits, pushes, and merges and retries on a lost race; it never forces (RULES/50). Allocate a plan number only
  after `begin`, and ship the file that claims it in the same minute.
- **Stage named files in the home; never `git add -A`.** A scratch file written seconds earlier (a plaintext backup, a
  decrypted copy) would be swept into a commit and pushed. This happened on 2026-09-17 and cost a history rewrite; the
  incident is recorded in `hodd/docs/secrets-vault.md`.
- **Realm boundaries are sacred** (law 5). Determine the active realm (tenant) first; load
  `svartalfaheim/<realm>/.env.realm` for realm secrets; scope every file operation to that realm's tree; never touch
  another realm without the Allfather's explicit approval. Private data is scoped per operator, and a clone must never
  inherit another's hoard.

## Append-only (RULES/06)

Some records are the system's memory and are **appended to, never rewritten, never truncated, never lost in a move**:
the Runes ledger (`$YMIR_HOME/hodd/memory/runes_audit.md`, chained by checksum), the rules themselves, the fix notes
(`docs/fixes/`, one file per fix), and everything in `$YMIR_HOME`. A correction is a **new** entry citing the old one. A
migration, re-clone or backup **must carry every append-only artifact** and the private set; verify the set by name
before and after any move. The contract itself is the one exception: it is a living document whose corrections are
folded in, with the prior text kept verbatim in `docs/contract-history/` (RULES/06, 2026-11-24).

## For open-source release

The repo contains only public artifacts (source code, public docs, `*.example` scaffolds). All private data lives at
`$YMIR_HOME` and syncs between machines through the user's private GitHub repo. A fresh clone →
`bin/engine/ymir-install.sh` → choose `$YMIR_HOME` → optionally link a private GitHub repo → done.

## Keeping a home current

- **Structure updates:** `bin/engine/ymir-migrate.sh status|apply` runs versioned, idempotent migrations in
  `.agents/migrations/` (for example `0001-hodd-layout`). Install and Gróa call it.
- **Update (Gróa):** `bin/agents/groa-update.sh [--check]` fast-forwards the runtime and every registered home, never
  forced, then mends forward; `bin/agents/brokk-update.sh` is her alias, and the `groa-update` skill (`/updateymir`) is
  her door. She reports `reread-Brokk` and `galdr-reread`: when the instruction surface moved, re-read `AGENTS.md` and
  reflect it in the owning Galdr asset. Exit 4 means the update moved but surfaces are still owed;
  `config/owed-accepted.txt` in the home names the ones the operator accepts.
- **Repair (Eir):** `bin/agents/eir-doctor.sh [check|fix]` composes every `*-ensure.sh` surface, diagnoses the system and
  mends what is broken.
- **Your agent set:** `config/agents.yaml` (template `.example`, private; at `$YMIR_HOME/config/agents.yaml` after
  install) picks each agent's harness and model: `bin/fleet/agents-config.sh show|apply`, and
  `bin/agents/agent-run.sh <agent> "<task>"`. Local models go to **pi**, hosted ones to **opencode**.
- **Skills:** one galdr-style skill per figure (a `SKILL.md` router + `assets/`); same-figure split pairs are
  consolidated (`ymir · urdh · saga · nornir · nsr`). The registry is `.agents/skills/README.md`.

## CHANGE LOG

- **2026-11-25** — written when the contract was split by topic (plan 369 item 7); its text is folded from the
  sections of the prior `AGENTS.md`, kept verbatim in `docs/contract-history/AGENTS-2026-11-24.md`.
