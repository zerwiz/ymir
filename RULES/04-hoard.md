# Rule 04 — Hodd, the private hoard, and YMIR_HOME

Every private thing the Allfather holds lives in **one** place: **Hodd**
(`hodd/`) at the repo, and **YMIR_HOME** (`$HOME/Documents/Ymir/`) as the
shareable private repo. *Hodd* is Old Norse for a hoard — guarded, and
never shown. The repo holds the **framework** (scaffolds, guards,
templates); the data lives at **YMIR_HOME**, committed and pushed to a
private GitHub repo so it can be shared between machines.

## What belongs in Hodd (at the repo)

Only **scaffolds and guards** live at the repo path `hodd/`:

- **Guards** — `hodd/.gitignore` (inner ward, tracks only itself, README,
  and `*.example` shapes)
- **README** — `hodd/README.md` (this map of the hoard)
- **Scaffolds** — `hodd/AGENTS.example.md`, `hodd/**/*.example` (templates
  so a new operator knows what belongs)

## What lives at YMIR_HOME (the real hoard)

All private data is committed to the **private YMIR_HOME git repo** and
pushed to a **private GitHub repo** for multi-machine sync. It is **NOT**
gitignored — the user owns it and shares it between computers:

| Repo location | YMIR_HOME location |
|---|---|
| `hodd/docs/` | `$YMIR_HOME/docs/` |
| `hodd/secrets/` | `$YMIR_HOME/secrets/` |
| `hodd/identity/` | `$YMIR_HOME/identity/` |
| `hodd/tenants/` | `$YMIR_HOME/tenants/` |
| `data/` | `$YMIR_HOME/data/` |
| `memory/kaia.engram*` | `$YMIR_HOME/memory/` |

## The law

- **Hodd at the repo is untracked.** `hodd/.gitignore` tracks only the guard
  and the README; everything beneath is private on every clone. A clone
  must never inherit another operator's hoard.
- **YMIR_HOME is committed.** All private data at YMIR_HOME is committed
  to the user's **private** git repo and pushed to a private GitHub repo
  for sync between machines. It is never gitignored (except runtime
  ephemera like `*.wal`, `*.shm`, `smidja/`, `state/`).
- **Secrets are referenced, never inlined.** Read them by path — `YMIR_HOARD`
  (default `$YMIR_HOME`), `bin/hodd.sh emit <file>` to set them in a shell. A
  value never enters a tracked file, a commit, or a document.
- **Two wards.** `bin/secret-guard.sh` is the outer ward (pre-commit + CI);
  `hodd/.gitignore` is the inner one. Nothing leaves without passing both.
- **Realm boundaries are sacred.** Private data at YMIR_HOME is
  scoped per operator; a clone must never inherit another's hoard.
- **The public tree keeps only the framework** (lore, architecture, scaffold)
  and `*.example` shapes.
- A change that contradicts this rule must change the rule first (append-only;
  never silently rewritten).

## docs/ is public — plans are not

`docs/` is the **public, user-facing** tree: it holds what a user of Ymir may
read. Operator-private documents — plans, strategy, roadmaps, the masterplan,
`append-only-log`, and project planning — belong in `hodd/docs/` at the repo
(never `docs/`), or live at `$YMIR_HOME/docs/` in the private repo.

`bin/docs-guard.sh` blocks a commit that stages such a document under `docs/`
(wired into the pre-commit hook beside `secret-guard.sh`). When it fires, move
the file to `$YMIR_HOME/docs/` in the private repo.

---

## Correction — 2026-09-17: hodd/ *is* the YMIR_HOME data path

*Appended, citing the sections above; nothing above is rewritten.*

The mapping table above ("What lives at YMIR_HOME") implies a **flat** layout —
`hodd/identity/` → `$YMIR_HOME/identity/`, `data/` → `$YMIR_HOME/data/` — i.e.
that the repo-side `hodd/` and the data path are two different locations. On a
real home that reading produced **two parallel stores**: a flat
`$YMIR_HOME/identity/` and `$YMIR_HOME/data/` alongside `$YMIR_HOME/hodd/identity/`
and `$YMIR_HOME/hodd/data/`. They drifted, and the flat pair went stale.

The truth on a live home, and the intent of this rule:

- **`$YMIR_HOME/hodd/` *is* the private data path.** There is no second, flat
  copy. `identity/`, `data/`, `docs/`, `secrets/`, `tenants/`, and the memory
  well live **under `hodd/`**.
- **`bin/hoard-lib.sh` is the single source of truth** for that path: it
  resolves `${YMIR_HOARD:-${YMIR_HOME:-$HOME/Documents/Ymir}/hodd}`. A script
  that needs the hoard calls `hoard_root`, never a hardcoded path.
- **`.ymir-layout.yaml` records the real layout** and must name only paths that
  exist. A layout entry pointing at a nonexistent directory is stale, and a
  stale map is what let private work land outside the hoard.
- The three-way reading in the section above (`hodd/x/` → `$YMIR_HOME/x/`) is
  **superseded**: read every row as `$YMIR_HOME/hodd/x/`.
- The "docs/ is public" section's closing line ("move the file to
  `$YMIR_HOME/docs/`") is likewise read as **`$YMIR_HOME/hodd/docs/`**.

Confirmed by the Allfather 2026-09-17. Drift of this kind is caught by
`bin/eir-doctor.sh`'s hoard placement check.

---

## Appended 2026-10-01 — personal data is not only secrets; the ward must see it

The first law says: *never store personal or private data in this repo — not a
secret, a key, a name, a plan, a schedule, a client, a credential, or a note.*

Read until now, the automated wards enforced only the **secret** half.

- `bin/secret-guard.sh` scanned content for **credential values** (keys, tokens).
- `bin/private-guard.sh` scanned **paths** for private roots.
- **Nothing scanned file content for who the operator IS or WHERE their machines
  live.** So an operator username, a tailnet domain, a personal hostname and a
  fleet hardware inventory were committed and pushed to a public remote while
  every gate reported green. Measured 2026-10-01 across `origin` =
  `github.com/zerwiz/ymir` (public).

**The law, as the Allfather laid it down:**

1. A person's **identity and topology are personal data** whether or not they are
   a secret. Username, home path, tailnet domain, hostnames, machine names and
   the fleet's hardware inventory are **never** committed to this repo.
2. **Local-model knowledge is never in this repo, under any circumstances.**
   The modeltesting skill, its benchmarks, VRAM ceilings, measured prefill/decode
   and per-seat host profiles are **operator-specific** and live at
   **`$YMIR_HOME/.agents/skills/modeltesting`**. This repo may carry only the
   *doctrine* — which engines exist, how to detect them, why honest measurement
   beats a lucky load — never the measurements, the hosts, or the numbers.
   (Supersedes commit `cb5c2f1`, 2026-09-12, which moved the skill to a galdr
   asset; the asset remains doctrine, the skill is the Allfather's own.)
3. The **public way** to say a private thing is a placeholder: `$HOME`,
   `$HOME_SEAT`, `<user>`, `<host>`, `<tailnet>`, `<gpu>`, `<seat>`, `<home>`.
   Docs use the placeholder and stay universal; the value stays in the hoard.
4. The wards must **fail** on this class, not merely be able to. A test that
   cannot fail on the leak is not a test.

**The ward:** `bin/private-guard.sh` now scans content for identity/topology by
**shape, never by value** — a literal `/home/<name>/`, a `*.ts.net` tailnet host,
a CGNAT `100.64/10` address — and exempts synthetic fixtures and `.example`
files. It deliberately contains **no** operator name, domain or hostname: naming
them in the guard would re-create the very leak the guard exists to stop.

Confirmed by the Allfather 2026-10-01. Law 06: this entry is appended, never
rewritten; a correction is a new entry citing this one.

---

## Appended 2026-10-01 — data comes FROM the hoard; the repo holds only craft

Laid down by the Allfather, following the entry above.

The repo must not merely *avoid* personal data — it must not **contain a copy of
it in any form**, not even a placeholder that a human filled in once. Every piece
of operator data is **read at run time from `$YMIR_HOME`**, and the repo ships
only the *function* that reads it.

| Belongs in `$YMIR_HOME` (data) | Belongs in this repo (craft) |
|---|---|
| the modeltesting skill, benchmarks, VRAM ceilings, host profiles | the doctrine: which engines exist, how to detect them |
| machine / seat inventories, topology, hostnames | `.example` **shapes** with synthetic names |
| the operator's model ids, context windows, measured limits | the scripts that read `$YMIR_HOME` and decide |

Rules:

1. **No copy.** A value that exists in the hoard is never also pasted into the
   repo — not as a value, not as an "example" filled with the real thing.
2. **Examples are synthetic.** An `.example` carries a made-up name
   (`h1.tail.ts.net`, `/home/alice`), never a real seat, domain or user. A ward
   enforces it; see `bin/private-guard.sh` and the exempt-fixture rule in
   `.agents/tests/private-guard-identity.test.sh`.
3. **Functions read the hoard.** Anything needing operator data resolves it
   through `bin/hoard-lib.sh` (`hoard_root`) at run time. A machine that has no
   hoard says so loudly; it never falls back to a value baked into the tree.
4. **One source of truth.** When the data and the repo disagree, the hoard is
   right and the repo is drift.

Confirmed by the Allfather 2026-10-01. Appended under Law 06; a correction is a
new entry citing this one.
