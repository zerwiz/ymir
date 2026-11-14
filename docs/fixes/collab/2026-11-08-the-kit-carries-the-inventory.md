# The kit carries the inventory — areas, the gate, and the card (1.1.0 → 1.2.0)

**2026-11-08 · component: collab · plan 219 §13–§14**

## What was wrong

Every project divides its work into areas — the database, multi-tenancy, identity, the interface, the
money, the jobs. **Nothing recorded that the division had happened.** So an area nobody held looked
exactly like an area that was finished: a decision about the tenant boundary was made by whoever
happened to hold a frontend task, and no file anywhere said "multi-tenancy" was ever a question.
Measured on day zero, in the first estate tried: Inmost's Example3 is Elixir/Ash (35 resources
declare `multitenancy strategy(:attribute) attribute(:org_id) global?(false)`, 13 Ash domains), while
the hoard's own stack plan still said Supabase + Next.js. Nobody held "data-model", so nobody noticed
that the plan and the client's code described two different systems.

The collaboration kit is where this house puts discipline into repositories that are not ours (26
files, kernel hooks, five gates, a baton, a review shelf). It had no notion of an area.

## What was forged

Kit **1.2.0** — seven new pieces, one seam, one version:

- `areas/canon.yaml` — eighteen area ids with the question each must answer. The **plain face** of
  Ymir's `.agents/areas.yaml`: the questions travel, the house's figures stay home (RULES/48).
- `areas/TEMPLATE.yaml` — the declaration shape, with the four states explained (`held` · `waived` ·
  `na` · `unheld`).
- `areas/README.md` — the shelf's own front door, including the eighteen ids in one table.
- `scripts/areas.{sh,py}` — the door: `init · list · check · estate · canon · claim · waive`. Standard
  library only, because an Elixir repository has no PyYAML and a door that needs installing is shut.
- `scripts/gates/areas-guard.sh` — at **pre-push**: a change under an `unheld` area's ground is refused,
  naming the area and the file, never the author.
- `scripts/a2a.{sh,py}` + `scripts/gates/a2a-guard.sh` — the card in the constellation, generated from
  the same shelf: one skill per **held** area, `a2a` 1.0 required fields, both `url` (0.3) and
  `supportedInterfaces` (1.0), a declared grant scheme, and a refusal of loopback, secrets and mailboxes.
- `docs/areas.md`, `docs/a2a.md`, `RULES/18-an-area-is-held-or-waived.md` — the how-to and the law.

Three seams, so nothing becomes a sixth way to do a fifth thing: `scripts/checks.sh` gains an `areas`
verb; `handoff/check.py` prints the estate line (and **never** fails the baton's seven headings for it);
`.githooks/pre-push` calls the two new gates.

## Why it is a referee change, and why that is said here

The kit's gates judge other people's repositories. A gate that changes silently looks exactly like a
gate that passes — the same fault this kit already paid for on 2026-11-06, when a gate sat after an
`exit 0` and had never run anywhere. So: the version moves 1.1.0 → 1.2.0, the manifest records it, and
this note exists before the push.

## What was verified, on a real repository

Inmost's Example3, `~/CodeP/Inmost-ControlTower`, working tree at `chore/collab-kit`:

```
bash scripts/areas.sh init                    → 18 declarations, every one honestly unheld
bash scripts/areas.sh claim delivery|tests|docs|ward  → 4 held, each with two artefacts
bash scripts/areas.sh claim tenancy|data|identity|frontend|money --unheld --path  → ground scoped, nobody holding it
bash scripts/areas.sh estate                  → 18,4,0,0,0,14
bash scripts/checks.sh areas                  → clean: no fault. 14 unheld · 0 unproved
bash handoff/check.sh --check                 → handoff: areas: 18 · 4 held · 0 unproved · 0 waived · 0 na · 14 unheld
bash scripts/a2a.sh card --write              → 4 held area skills; check → valid, UNPUBLISHED (no address yet)
bash scripts/gates/areas-guard.sh HEAD~1 HEAD → REFUSED: "tenancy (unheld): apps/ct_core/lib/ct_core/domains/tenancy.ex"
```

The refusal is the whole point: the repository said whose ground that folder is, and nobody had taken
it, so the change could not pass quietly.

## Four faults found while forging it, and fixed

1. **A block parser ate a list.** `evidence:` under an area swallowed the next eighteen areas; an
   18-area canon parsed as **one area with eighty pieces of evidence.**
2. **A comment became a value.** `state: unheld   # unheld | held | waived | na` read as that whole
   string, so no state matched. A trailing `#` outside quotes is a comment.
3. **A flag was counted twice.** `--keeper "Vidarr"` produced `Vidarr Vidarr`, and two `--evidence`
   flags produced four.
4. **`yaml.safe_dump` of a scalar emits a `...` document-end marker**, which was written into every
   generated declaration and made the file unparseable. Scalar quoting is now `json.dumps`.

## What is not done

`areas/` is not yet in the ymir tree's own commit, Example3's branch is **not committed or
pushed** (the Allfather's word rules that), and the four repositories on 1.1.0 still need their
one-branch, one-PR re-seat, theirs to merge.

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: a client of the house. The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).
