# Fix — the last errand of a batch calls the gather

**What was wrong.** A batch errand's brief promises it will never push and never open a pull request:
the helm gathers the batch into one push and one PR (`RULES/08`, the batch road). The worker keeps its
side. Nothing ever told the helm the batch was ready, so on 2026-11-14 twenty-two clean batch branches
were sitting on `origin`, gone stale within hours, and four had been merged. A batch errand was
"finished" the moment its worker went quiet, and its work was nobody's to ship.

**What was done.** A new door, `bin/forge/gather-notice.sh <errand-id>`, is asked whenever an errand
reaches a terminal word — from the arm's close (`bin/agents/eindri-dispatch.sh close`) and from the
worker's own terminal act (`bin/agents/eindri-acclaim.sh`). If that errand was the last unfinished
member of its batch, the door puts **one** line in the durable wake queue:

```
batch <wave> is finished — gather it: bin/forge/gather.sh <ids…> (errands: <id>,<id>)
```

It is silent for a lone errand, silent while any other member of the batch is still open, silent the
second time (a per-batch marker), and it never names an errand that already shipped. The house and
fleet for the PR signature are read from the home's own registry at run time; where they cannot be
read the command is printed without them rather than invented.

**Membership is the record, not a second registry.** The dispatch already writes `mode=batch` and
`wave=<wave>` into `state/<id>.meta`, so the batch is exactly that set: every errand whose meta says
`mode=batch` and carries the same `wave`. Nothing new is written to remember a batch.

**How it is proved.** `bin/forge/tests/test_gather_notice.sh` builds a checkout with the batch's
branches and a state dir with the members' metas and status lines, then asserts: a lone errand is
silent; a batch with an open errand is silent; the last one finishing prompts once with the exact
command; a second run does not prompt again; an errand marked shipped is excluded; a batch finished
with nothing to gather prompts nothing; and both hooks call the door. It runs in CI as the
`gather-notice` gate.

**Files.** `bin/forge/gather-notice.sh` (new), `bin/agents/eindri-dispatch.sh`,
`bin/agents/eindri-acclaim.sh`, `bin/forge/tests/test_gather_notice.sh` (new),
`bin/gates/ci-verify.sh`, `docs/features/gather-a-batch.md`.

## Change log

- **2026-11-14** — written with plan 293 part 4.
