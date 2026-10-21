# Five closed roads, one dead package claim, and a page describing a deleted door

**Component:** docs · **Seat:** heimdall · **Date:** 2026-10-21

## The question

*"we need to validate that everything for users to read in the readme are current functional and
implemented. or have the readme become stale?"* — and, of the page linking the masterplan and the
plan index: *"aren't this old info?"*

## What the audit found

```
findings[6]{document,claim,reality}:
  "README.md","the smithy is not `@zerwiz/smiddja`: 'accepted twice by the registry and served never'","`npm view @zerwiz/smiddja` → **0.1.1**, description matching the smithy. The sentence stopped being true when the name resolved"
  "README.md","`docs/masterplan.md` — 'the append-only forge orders'","the masterplan is the vault's (`hodd/docs/masterplan.md`); the repo has no such file, and should not — forge orders are private"
  "README.md","`docs/plans/README.md` — the feature plan index","the ledger moved to `$YMIR_HOME/svartalfaheim/<realm>/projects/<project>/plans/`"
  "README.md","`config/cron.yaml`","the tree ships `cron.yaml.example`; the live file is the hoard's"
  "README.md","`config/backend`","written by the seat at runtime — never shipped"
  "docs/lore.md","`docs/plans/`, `.agents/config/cron.yaml`, `.agents/config/eindri-harness/`","all three moved; two of them into the hoard"
  "docs/features/open-on-the-right-display.md","**'built and tested (2026-10-18)'**","`bin/desktop/open-on.sh` and its test were **deleted** in `a72ba5f6`; only `bin/desktop/display-lib.sh` remains. The page described a door that is not in the tree"
  "docs/lore.md","Himinbjörg '(planned)'; Vörðr '(planned)'","both built — Himinbjörg that same day (`/api/ward` + the panel), Vörðr on 2026-10-18"
```

**Not one of these looked wrong while reading.** That is the finding: a stale document is
indistinguishable from a current one to the person reading it, and the author cannot see it because
it was true when written.

## What was done

- The claims are corrected in place (living documents move; the corrections are dated).
- **`bin/gates/checks/readme-claims.sh`** — it reads the user-facing documents and refuses a claim
  the tree does not hold: repo paths must exist, `@zerwiz/*` can be checked against the registry,
  `--ports` reports what actually listens. A line is waived in writing
  (`<!-- stale-ok: reason -->`, or `docs/README-claims.waived`).
- **`bin/gates/guards/docs-claims-guard.sh`** — the ward, in `guards.sh`'s list, covering the
  README, FEATURES, the lore and all 58 feature pages: **197 claims checked, 0 missing**.
- **Proved to fail**: a fake `bin/does-not-exist.sh` in the README makes the ward exit 1; removed,
  it passes.
- **`RULES/27-the-documents-are-checked.md`** — the law the rest obeys: a claim about the tree is
  checked by a machine, a waiver is written with its reason, the page moves with the code in the
  same change, built-or-planned is said out loud, and *a check that cannot fail is not a check*.

## One mistake made on the way, recorded

Proving the ward could fail, I appended a fake claim to `README.md` and then ran
`git checkout README.md` to remove it — **which discarded the uncommitted corrections I had just
written**, because checkout restores the last commit, not the previous minute. The corrections were
re-applied and committed. The lesson is the same as the vault's, one layer down: a destructive
command is destructive whether or not the target felt important.
