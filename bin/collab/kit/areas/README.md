# areas/ — what this repository answers for

A project's work is divided into **areas**, and every area is answered in exactly one of four ways:
`held` (a keeper, and evidence), `waived` (a named person, a reason, an end date), `na` (it does not
apply, with a reason), or `unheld` (nobody holds it — legal to say, and refused the moment work
touches the area).

**Why it exists.** An area nobody held looks exactly like an area that was finished. This shelf is
how a repository says, in its own words, which of its concerns have a keeper — so that a database
decision is not made by whoever happens to be holding the frontend task.

**The eighteen areas** (the full question for each is in `canon.yaml`):

```
areas[18]{id,what it owns}:
  "data","schema, migrations, constraints, the money type — can the database be built from the repo, and rolled back"
  "tenancy","the tenant on the token, scoping at query time — can one tenant read another's row"
  "identity","login, sessions, roles, policies — does the server refuse, or only the interface hide"
  "api","the backend contract, versioning, the error shape — can a caller see the contract"
  "frontend","screens and their empty · loading · error · narrow states, keyboard"
  "design","tokens, primitives, the words — is every screen made of declared pieces"
  "jobs","queues, retries, idempotency, dead letters — what breaks if this runs twice at once"
  "integrations","third parties, webhooks, keys by reference — what if it is down, slow, or answers twice"
  "money","rounding, tax, reconciliation, append-only entries — does every öre reconcile"
  "observability","logs, traces, metrics, alerts, runbooks — what tells us at 03:00"
  "ward","secrets, injection, dependencies, the gate on the door — what may not be committed"
  "tests","the pyramid, fixtures, the regression test — is the test that would have caught the last bug here"
  "delivery","branch, pull request, gates, the fix note — how does a change leave, and who seals it"
  "docs","the how-to, the decisions, the tickets, the baton — can a stranger run this"
  "perf","budgets, N+1, pagination — what is the slowest thing a user waits for"
  "privacy","personal data, retention, region, NDA material — what do we hold, and when may it leave"
  "fleet","every role answers, with its road named — does this work on a machine that did not build it"
  "agents","the well, MCP, A2A, skills — can an agent recall this project and act on it"
```

**The doors.**

```bash
bash scripts/areas.sh init        # one file per canon area, every one honestly `unheld`
bash scripts/areas.sh list        # area · state · keeper · open questions
bash scripts/areas.sh check       # names what is unanswered or unproved; exits 1 on a fault
bash scripts/areas.sh estate      # the one line: held · unproved · waived · na · unheld
bash scripts/areas.sh claim tenancy --keeper "Ada Lovelace" --path "apps/ct_core/lib/ct_core/domains/" \
                                  --evidence "apps/ct_core/test/tenancy/isolation_test.exs" --lens isolation
bash scripts/areas.sh waive perf --by "Ada Lovelace" --why "no traffic yet" --until 2027-01-31
```

The gate `scripts/gates/areas-guard.sh` runs at pre-push: a change under an `unheld` area's
`may_write` is refused by name. A repository that has not adopted the shelf prints a clean skip —
a skip is a pass, a silent green is a lie.

**What this is not.** It is not a second backlog, not a checklist to tick once, and not a way to
claim work is done. `held` without evidence is reported as **unproved**, on the baton and on every
status line, until the evidence lands.

## CHANGE LOG

- **2026-11-08** — Opened with kit 1.2.0: the eighteen areas, their states, and the two doors.
