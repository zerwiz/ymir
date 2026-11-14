# The plan ledger law (assets of the elder skill · Reginn)

## The canonical shelf

The ymir project's plans live in **exactly one ledger**:

```
$YMIR_HOME/svartalfaheim/<realm>/workspace/<project>/plans/
  README.md          # the index — domain map + every plan as a row
  <NN>-<slug>.md     # one file per plan, numbered after the index's last
  <domain>/...       # some plans keep their domain folder (core/, mesh/…)
```

For the operator's own setup (realm `<realm>`, project `ymir` — the realm is HIS, so the ledger is
discovered, never spelled: `bin/vault/hoard-lib.sh` → `ymir_plan_dir`):

```
svartalfaheim/<realm>/workspace/ymir/plans/              # plans 01–42
```

## Retired shelves — never write here

- `$YMIR_HOME/memory/plans/` — retired 2026-09-22 (the 2026-09-17 layout
  teaching pointed here; it was wrong).
- `hodd/docs/plans/` (any tree) — retired 2026-09-22; the public-tree mirror
  was folded into the ledger and deleted.
- `hodd/plans/` is NOT the ledger — it holds live PERSONAL working plans only
  (omarchy/…), never ymir project plans.
- A plan that exists only in a worktree or a seat copy is not in the ledger.

## Numbering

- A new plan takes the next integer after the ledger index's highest number
  (ymir: 42 → 43). Numbers are never reused; a renumbered plan records the
  move in the README row (e.g., federation 29 → 42) and in the runes.
- The README index gains a row with: number · title · path · status.

## The reconciliation discipline (Part 0)

A new plan that touches ground the elders already hold must open with
**Part 0 — Reconciliation with the elders**:

1. Read the highest relevant plan numbers FIRST (37 fleet-data-sync, 39
   one-well-fold, 36 tailnet, 09/25–27 A2A lineage, 02 well, 14 ingress,
   31 agent-start, 42 federation …).
2. Name in Part 0: which elder is extended, which is consumed as designed,
   which is deliberately superseded — and why (a correction is a new entry
   citing the old, per the append-only law).
3. Mine the elders for ideas before inventing; record what was mined and from
   where (their "done when" and "guards" are the best seams).

## Replacements

A plan is amended by a NEW numbered plan or an appended dated section, never by
rewriting it. Fix notes (`docs/fixes/<component>/`) stay one-file-per-fix and
are never rewritten — corrections supersede, they do not erase.
#### Correction (2026-09-30, append-only) — the canonical shelf is `projects/`, not `workspace/`

The layout block above names `svartalfaheim/<realm>/workspace/<project>/plans/`. **That name is
retired** (plan 62, "one word, three meanings"). The canonical shelf is now:

```
$YMIR_HOME/svartalfaheim/<realm>/projects/<project>/plans/    # plans, and the index
$YMIR_HOME/hodd/life/<domain>/                               # the operator's life shelves
$YMIR_HOME/hodd/identity/{projects,workspaces}.yaml           # the registries
```

The move is performed by `.agents/migrations/0007-one-word-three-meanings.sh` (`git mv` inside the
home, then the append-only set is verified **by name**), so a seat that already ran it has the new
path and a seat that has not still has the old one — and this correction tells a reader which is
which. The block above is left as the record of what the law used to say; it is not the current
shelf. **A plan written before today and read after it names the old path** — the plans themselves
are history and are not rewritten; the law is corrected, once, here.

---

## 2026-11-10 — the ledger has four shelves, because a plan belongs to whoever owns the work

His word: *"its not an ymir plan. we need to update ymir so machines and other projects and companies can make plans
also. not only for ymir. this must come in installations and updates of ymir."* (plan 240.)

Until today the ledger resolved one shape — `svartalfaheim/<realm>/projects/<project>/plans/` — so a machine, a
company (realm) and the Allfather's own work had no shelf, and a laptop repair was numbered among the ymir project's
plans. `bin/records/plan.sh` now takes `--scope` and `--owner`:

```
scopes[4]{scope,path,created by the tool}:
  "project (default)","svartalfaheim/<realm>/projects/<project>/plans/","never — an unknown project is a typo, not a shelf"
  "realm (a company)","svartalfaheim/<realm>/plans/","yes, on first use, with its index"
  "machine","hodd/machines/<host>/plans/","yes — owner defaults to this host"
  "personal","hodd/plans/","yes — the Allfather's own shelf, now with an index"
```

**What does not change:** numbering is still after *that shelf's* highest and a number is never reused within a
shelf; the Rule 45 fresh-ledger refusal still guards `new` on every scope; `hodd/plans/` is still **not** the ymir
ledger — it is the *personal* scope's shelf, and it now carries an index like the others.

Every plan header carries `owner:` and `owner_name:`, so a plan moved between shelves keeps its provenance.
`plan.sh list --all` and `plan.sh next --all` walk every shelf. `.agents/migrations/0018-plan-scopes.sh` creates the
three new shelves (idempotently, seeding an index only where none exists), and it ships the way every structure
change ships: `bin/engine/ymir-install.sh` and `bin/agents/groa-update.sh` both run `bin/engine/ymir-migrate.sh
apply`, so a fresh home is born able to plan for a machine and an old home gains the shelves on its next update.

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
