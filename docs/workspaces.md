# Workspaces — where things live

> **Status:** PROPOSED. This page is the map; the code is authoritative. It exists
> because three workspace roots grew at once (the repo's `workspace/`, the realm
> tree under `svartalfaheim/`, and `$YMIR_HOME/workspaces/`), and a fourth
> question — where a *project* lives — had no single answer. Two rules decide it:
> private data is never inside the checkout (Rule 04), and a domain is not a
> house (Rule 01/03).
>
> **2026-09-17:** the roots settled — workspaces now live under
> `$YMIR_HOME/hodd/workspaces/` (marketing/ · personal/ · work/); this page
> stays the map, the hoard is authoritative.

## The one idea

**Two private trees, one of each kind of thing.**

- **Hodd** — what is true about *the operator*: secrets, identity, doctrine, memory.
  It belongs to no realm, because it governs all of them.
- **Svartalfaheim** — the realms, one per working world (tenant). A realm holds
  its workspaces: a **private** one for the operator's own work, and a **company**
  one per company. Work is organised **per project**, and inside a project
  **per topic** — that is the only two-level split anyone actually needs.

Everything below `$YMIR_HOME` is private and committed; nothing below `$YMIR_HOME`
is inside the checkout; the repo ships `examples/` and nothing else.

## The tree

```
$YMIR_HOME/                               ← the private root (Rule 04) — ONE place
│
├── hodd/                                 ← the operator's own; about you, not about work
│   ├── secrets/                          platform.env · tenants/<tenant>/.env   referenced by path, never inlined
│   ├── identity/                         workspaces.yaml · projects.yaml          the registries of truth
│   ├── docs/                             masterplan · append-only-log · plans/ · reports/
│   ├── data/                             operator.md · learnings.md · fleet.md · kindred.md
│   └── memory/                           daily/ · well/  (+ kaia.engram*)
│
└── svartalfaheim/                        ← the realms: one per working world
    ├── examples/                         ← the ONLY thing the repo ships (a full realm, as a template)
    │   └── acme/
    │       ├── .env.realm.example
    │       └── workspace/{personal,company/acme}/…
    │
    └── work/                             ← a live realm (this operator's)
        ├── .env.realm                    realm secrets, referenced by path
        ├── workspace/
        │   ├── personal/                 PRIVATE workspace — the operator's own work
        │   │   ├── inbox/                unsorted: captures, loose files, "deal with later"
        │   │   ├── me/                   personal topics: health · admin · finance
        │   │   └── <topic>/              one dir per topic, earned not assumed
        │   └── company/                  COMPANY workspaces — one per company
        │       └── <company>/            e.g. wayof/
        │           ├── strategy/         business material: plans, pricing, positioning
        │           ├── marketing/        campaigns, copy, research
        │           └── projects/
        │               └── <project>/    the working tree for ONE project
        │                   ├── brief.md          what this is and why
        │                   ├── notes/            topic-level material
        │                   ├── reports/          agent output: verdicts, audits, reviews
        │                   └── links.md          where the CODE lives (checkout path + repo)
        ├── memory/                       the realm's own memory
        │   ├── daily/YYYY-MM-DD.md
        │   └── well/                     realm-scoped engram store
        └── runs/                         agent runs, traces, envelopes (ephemeral, never backed up)

    └── <other-realm>/                    another tenant — same shape, fully isolated
```

**Where code lives.** A project's *checkout* is not its *material*. Code stays
where the project registry says (`repo:` in `hodd/identity/projects.yaml`) — the
monorepo's own `apps/*`, or a clone under `$YMIR_HOME/projects/<project>/`. The
workspace holds what a human reads: the brief, the notes, the reports, and a
`links.md`. One place for "why", one place for "how".

## Old → new

| Today | Becomes | Why |
|---|---|---|
| `<repo>/workspace/{personal,memory,companies}/` | `$YMIR_HOME/svartalfaheim/<realm>/workspace/…` | private data was sitting **inside the checkout** |
| `<repo>/svartalfaheim/work/…` (a live realm) | `$YMIR_HOME/svartalfaheim/work/…` | the repo ships **examples only** |
| `<repo>/svartalfaheim/examples/examples/…` | `$YMIR_HOME`-independent: repo's `svartalfaheim/examples/<realm>/` | the scaffold was doubly nested by mistake |
| `$YMIR_HOME/workspaces/{work,personal}/` | `$YMIR_HOME/svartalfaheim/<realm>/workspace/{personal,company/…}` | one root, realm-aware naming |
| `<repo>/hodd/` (was holding a live plan) | scaffolds only: `README.md` · `.gitignore` · `*.example` | Rule 04: repo keeps the guard, not the hoard |

## What this buys

- **One question, one answer.** "Where is it?" → `$YMIR_HOME`, then *operator or
  realm*, then *private or company*, then *project*, then *topic*. Five steps,
  never a guess.
- **Realm boundaries become physical.** A realm is a directory; nothing leaks by
  accident, and deleting a realm deletes exactly that tenant's world.
- **The repo is publishable by construction.** It has no private path to leak,
  because no private path is inside it.
- **Backup has a name.** The append-only set (Runes ledger, fix notes, rules) and
  the private set live in one tree, so Rule 06's move-check is a listing.

## Decisions I need from you

1. **`hodd` beside `svartalfaheim`, or `hodd/` holding everything?** Proposed:
   siblings under `$YMIR_HOME` (as drawn), because one is *about the operator* and
   the other is *about tenants*.
2. **Material-only workspaces, or checkouts inside them?** Proposed: material in
   the workspace, code where `projects.yaml` says. The alternative is one
   directory per project holding both — simpler to explain, messier to sync.
3. **`inbox/` worthy?** A place for the unsorted is what keeps `personal/`
   from becoming one. Drop it if you never have unsorted.
