# Rule 22 — The home has a layout, and nothing is created outside it

> Adopted 2026-10-13: *"we clearly need to tighten the way Ymir is allowed to find and create
> documents inside the Ymir home."*

The operator's home (`$YMIR_HOME`) is the vault of private material. Left unstated, files land
wherever a script, a template or a person happens to be standing — state outside the home,
company documents inside the personal shelf, a stray `~/hodd`. So the layout is **law**: every
shelf has one purpose, one resolver finds them all, and **creation is refused anywhere else.**

## The law

```
home_layout_law[6]{rule}:
  "ONE RESOLVER — every script finds the home through bin/vault/hoard-lib.sh (ymir_home_root). No hardcoded path, no guessed fallback, ever"
  "ONE PURPOSE PER SHELF — a shelf holds one kind of thing; a file belongs to exactly one shelf"
  "STATE IS IN THE HOME AND NOWHERE ELSE — $YMIR_HOME/state; never inside the repo, never outside the home"
  "A COMPANY DOCUMENT LIVES IN A COMPANY OR PROJECT SHELF — never in the personal shelf (hodd/life)"
  "DISCOVERY IS BY REGISTRY, NOT BY WALKING — a document, project or company is FOUND through its index, never by searching the tree"
  "CREATION OUTSIDE A SHELF IS REFUSED — by the script, by the template, and by a ward; the refusal names the right destination"
  "ONE NAME, ONE MEANING — a realm and a shelf may not share a name (two things called 'work' is how a file lands in the wrong one)"
```

## The shelves, and what each holds

```
hodd/identity/projects.yaml          the ONE registry of projects (kind · company · realm · path · git)
hodd/identity/                       the operator's own identity, and the registry — nothing company-shaped
svartalfaheim/<company>/             A COMPANY IS A REALM: its memory, its projects, its products, its marketing
hodd/memory/                         the well, the daily logs, the append-only audit ledger
hodd/plans/                          live personal working plans
hodd/docs/                           machine notes, runbooks, diagnostics, reference
hodd/security/                       the secrets design (values live in hodd/secrets/)
hodd/data/                           records about machines, the fleet, inventories
hodd/life/                           THE OPERATOR'S OWN — his personal life, the meetings he attends, the marketing he runs, his own working notes. NOT a company's and NOT a project's
svartalfaheim/<realm>/projects/<project>/   a project, inside its realm
config/                              agents.yaml · cron.yaml · the room · per-machine overlays
state/                               RUNTIME STATE — ephemeral; never committed, never elsewhere
vault/                               the encrypted document vault
smidja/                              factory databases (ephemeral)
```

**The test for any file:** *which shelf is this?* If the answer needs a sentence, the file is in
the wrong place.

## The three faults this rule exists to end

Measured on 2026-10-13:

1. **State outside the home.** `~/Documents/Ymir/state` (a case-variant directory holding
   `sessrumnir.pid`, `sessrumnir.log`, `version`), and state *inside the public repo* at
   `ymir/.agents/state` and `ymir/bin/state` — git-ignored, so the guards could not see it either.
2. **A stray hoard.** `~/hodd/` existed because one line of instructions named it; it held one
   misplaced document.
3. **Company and project material in the operator's own shelf.** `hodd/life/marketing/`,
   `hodd/life/meetings/` and `hodd/life/work/` hold material belonging to a **company** or a
   **project** — a WayOf/ForemanAI meeting, marketing for a company, and seven project notes
   (`investready-project.md`, `treasury-demo-project.md`, `wayofteams-tickets-ui-anatomy.md`).
   A company's material belongs in its company shelf; a project's, in the project's shelf.
4. **Two things share one name.** `svartalfaheim/work/` is a **realm**; `hodd/life/work/` is a
   **shelf**. A name may not mean two things in one home — that is how a person, and a script,
   lands in the wrong place.

## The three kinds — company, product, project

```
COMPANY   a realm               svartalfaheim/<company>/     e.g. Whynot Productions · WayOf
PRODUCT   what a company makes  belongs to its company       e.g. GIMLE — a product of Whynot Productions, for the operator's server
PROJECT   the work behind it    the project shelf            e.g. the code, plans and docs of a product or a venture
```

**A product is not a company.** Filing one as the other is how a shelf is created twice — and how
`hodd/identity/companies/gimle/` came to exist, wrong in the **tree** and wrong in the **kind**
(measured 2026-10-13, on the Allfather's word: *"gimle are not a company that's a product for my
server from whynot productions"*).

## Finding: the registry, not a search

**A file is found by asking its index, never by walking the tree.**

- a **project** → `hodd/identity/projects.yaml`
- a **company** → `hodd/identity/companies/<company>/`
- a piece of **machine knowledge** → `hodd/docs/INDEX.md`
- a **plan** → the project's own `plans/` shelf
- a **decision or a record** → the place's record, or the audit ledger

A search that finds a file the index does not know about is **a fault to record**, not a success.

## Machine-local, and checked

The layout map (`.ymir-layout.yaml`) describes **this machine** and is generated, never
hand-edited. Its entries are checked: a path that does not exist on this machine fails the check
— which is exactly how a map can silently describe another computer, as ours did (it pointed at
another seat's home for every path).

## Enforced, not remembered

Every scaffold and template that creates a file **resolves the home through the one resolver and
refuses to write outside a shelf**. A script that cannot name its destination does not write.
The ward fails on: state outside the home · state inside the repo tree · a company-named document
outside a company or project shelf · a layout-map entry that does not exist · a registry path that
does not resolve.
