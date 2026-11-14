---
title: "Areas — held, waived or never"
status: "accepted"
owner: "the project's collaboration-kit owner"
updated: "2026-11-11"
---

# Areas — how a repository says what it answers for

**What this is.** Eighteen areas of work that every software project has to answer for, whether or not
anybody writes it down: the database, multi-tenancy, identity, the API contract, the interface, design,
background jobs, integrations, money, observability, the wards, tests, delivery, docs, performance,
privacy, the fleet, and agents. This shelf makes the answers a file in the repository instead of a
memory in somebody's head.

**Why a file.** An area nobody held looks exactly like an area that was finished. That is the cheapest
lie in software, and it is not caught by tests — the tests pass for the areas somebody thought about.

## The four states

| state | means | what the gate does |
|---|---|---|
| `held` | a named keeper, with at least one piece of evidence | nothing — but a `held` with no evidence is reported **unproved** |
| `waived` | a named person waived it, with a reason and an end date | nothing |
| `na` | it does not apply here, with a reason | nothing |
| `unheld` | nobody has taken it | **refuses** a change under its `may_write` |

`unheld` is legal and honest. What is not legal is silence: no file at all, or a state that is none of
the four.

## Start one

```bash
bash scripts/areas.sh init          # 18 files, every one honestly unheld
bash scripts/areas.sh check         # what is unanswered, and what is unproved
bash scripts/areas.sh estate        # the one line the baton carries
```

Then take the areas that have work in flight:

```bash
bash scripts/areas.sh claim tenancy \
  --keeper "Ada Lovelace" \
  --path "apps/ct_core/lib/ct_core/domains/" \
  --path "apps/ct_core/test/tenancy/" \
  --evidence "apps/ct_core/test/tenancy/isolation_test.exs — 6 of 11 contexts" \
  --lens isolation
```

And waive what genuinely has no work yet — with your name on it:

```bash
bash scripts/areas.sh waive perf --by "Ada Lovelace" --why "no traffic until pilot" --until 2027-01-31
```

## What the gate refuses, and what it does not

`scripts/gates/areas-guard.sh` runs at **pre-push**. It refuses a range that changes a path inside an
`unheld` area's `may_write`, and it names the area and the file. It does not judge whether the
evidence is good, it does not decide what the areas are, and it does not require everything to be
held. A repository that never ran `init` gets a printed skip — a skip is a pass, a silent green is a
lie.

The override is loud and deliberate: `YMIR_SKIP_AREAS_GUARD=1 git push …` and say why in the commit.

## Keeping it honest

- **A claim needs an artefact.** `claim` refuses `--evidence` left empty. If you cannot name the thing
  that proves the area, the area is not held yet.
- **A waiver needs a name and an end date.** A waiver with neither is a disappearance.
- **Corrections are appended, not erased.** When an area stops being held, set it back to `unheld` and
  say why; the file is the record of what this project answered and when.
- **Re-read the canon when the kit moves.** `areas/canon.yaml` is versioned with the kit, and a
  question can be sharpened. An answer given against an older question is *stale*, and the kit's
  version says so.

## If it does not work

`bash scripts/areas.sh check` names every fault with the command that fixes it. If the door itself
fails, run it directly (`python3 scripts/areas.py check`) — it needs nothing but python3. If the gate
refuses a push that has nothing to do with the named area, the `may_write` prefix is too wide: narrow
it in that area's file, in the same pull request.

## CHANGE LOG

- **2026-11-08** — Opened with the shelf: the four states, the doors, and the gate.

## References

- `RULES/18-an-area-is-held-or-waived.md`, `areas/canon.yaml`, `scripts/areas.sh`
- `docs/headers.md` — the header and References format this document follows
