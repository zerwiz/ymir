# The areas shelf — every project says what it answers for

**What it is.** A project's work is divided into eighteen **areas** — the database, multi-tenancy, identity,
the API contract, the interface, design, background jobs, integrations, money, observability, the wards,
tests, delivery, docs, performance, privacy, the fleet, and agents. Each project keeps one small file per
area in its own repository under `areas/`, saying who holds it, what they may write, and what evidence
closes it. A gate refuses a change to ground nobody holds.

The point is narrow and it is the whole point: **an area nobody held looks exactly like an area that was
finished.** This makes the silence visible.

**What you need.** Nothing but the repository. The shelf is plain YAML and the doors are bash + python3
(no package to install). Nothing runs in the background and nothing is sent anywhere.

## The commands

Writing one in a project's repository:

```bash
bash scripts/areas.sh init                       # 18 files, every one honestly `unheld`
bash scripts/areas.sh list                       # area · state · keeper · open questions
bash scripts/areas.sh check                      # names what is unanswered or unproved
bash scripts/areas.sh estate                     # one line: held · unproved · waived · na · unheld
bash scripts/areas.sh claim tenancy --keeper "Craig Martin" \
     --path "apps/ct_core/lib/ct_core/domains/" \
     --evidence "apps/ct_core/test/tenancy/isolation_test.exs"
bash scripts/areas.sh waive perf --by "Craig Martin" --why "no traffic yet" --until 2027-01-31
```

Driving a project's estate from Ymir (the same answers, plus the seat):

```bash
bin/agents/areas.sh canon                        # the eighteen areas and the question each must answer
bin/agents/areas.sh init example-3           # by registry id, or by path
bin/agents/areas.sh list example-3
bin/agents/areas.sh check example-3
bin/agents/areas.sh estate example-3
bin/agents/areas.sh brief example-3 tenancy   # the brief a keeper is given, generated
```

The constellation card, generated from the same shelf:

```bash
bash scripts/a2a.sh card --write                  # one skill per HELD area
bash scripts/a2a.sh check                         # protocol, fields, no secret, no loopback
```

## The four states

`held` — a named keeper and at least one piece of evidence. `waived` — a named person, a reason, an end
date. `na` — does not apply, with a reason. `unheld` — nobody has taken it: legal, honest, printed, and
refused the moment a change touches that area's ground.

## Limits

It does not judge whether the evidence is good, and it does not decide a project's areas beyond the
canon. `held` with no evidence is reported as **unproved**, never as a pass. The gate checks paths, not
the quality of a test. A repository that never ran `init` gets a printed skip — a skip is a pass, a
silent green is a lie.

The card is generated, but the kit serves nothing: it publishes an address you supply, or none at all.
A card is an invitation to ask, never a grant.

## If it does not work

`bash scripts/areas.sh check` names every fault with the command that fixes it. If the door itself fails,
run it directly — `python3 scripts/areas.py check` — it needs nothing but python3. If the gate refuses a
push that has nothing to do with the named area, the `may_write` prefix is too wide: narrow it in that
area's file, in the same pull request. The loud override is `YMIR_SKIP_AREAS_GUARD=1 git push …`, and it
should come with a reason in the commit message.

The planning and the reasoning: plan 219 (`plans/219-the-areas-of-a-project.md`). The canon of questions
is `.agents/areas.yaml`; the copy that travels is `bin/collab/kit/areas/canon.yaml`.

## CHANGE LOG

- **2026-11-08** — Opened with the capability: the eighteen-area canon, the estate door
  (`bin/agents/areas.sh`), the travelling kit shelf and its gate, the card generated from the shelf, and
  the first two estates measured (Ymir: 6 held · 12 unheld; Inmost's Example3: 4 held · 14 unheld,
  with the tenancy folder scoped and refused). Plan 219.
