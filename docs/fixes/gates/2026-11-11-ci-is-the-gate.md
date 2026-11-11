# CI is the gate — the check that had a name nobody could require

**Date:** 2026-11-11 · **Component:** gates · **Door:** `.github/workflows/ymir-gates.yml` · `.forgejo/workflows/ymir-gates.yml` · `bin/gates/main-red.sh` · `bin/gates/main-red.sh summary` in the run page

Plan 243 part E. The audit that opened the plan measured what pushes actually cost; this note records
what CI was doing while that happened, and what it does now.

## What was wrong

**Measured on `main`, 2026-11-11, four consecutive pushes** (`gh run list --branch main`):

```
before[4]{run,started,duration,conclusion}:
  "42935168451","00:55:54Z","10m37s","failure"
  "42936589842","01:07:22Z","10m16s","failure"
  "42939515037","01:31:01Z","7m30s","failure"
  "42941457521","01:47:20Z","10m19s","failure"
```

Four red runs on `main`, ten minutes each, and **nothing in the house said so**. The only way to
learn that `main` was red was to open a browser and find the latest run. Every seat and every agent
pushed into it blind, and every push then failed for drift it had not caused — which the same
night's audit recorded as *"main red tonight on inventory, registers, features, weave, public-data"*.

The failing rows of that last run, verbatim:

```
red[3]{gate,finding}:
  "compliance","hardcoded: bin/gates/tests/test_broken.sh(path) bin/gates/tests/test_finding_tally.sh(path) bin/gates/tests/test_pr_identity.sh(path)"
  "inventory","bin/gates/INDEX.md is STALE · bin/mcp/INDEX.md is STALE · bin/records/INDEX.md is STALE"
  "weave","features: broken-register.md is not catalogued · features: pr-identity.md is not catalogued · features: queue-warden.md is not catalogued"
```

Three more faults sat on top of that silence:

```
fault[4]{what,why_it_matters}:
  "the job was named `gates` under a workflow named `The gates`","nothing could be REQUIRED in branch protection without ambiguity — and no check was required at all, so a red tree merged"
  "`push:` had no branch filter","the full ten-minute suite ran on every throwaway branch nobody had opened a PR for, which is minutes spent proving a tree that will never merge"
  "there was no `concurrency`","three pushes in ten minutes queued three ten-minute runs of the same repository"
  "a red main was announced NOWHERE","the floor of the house was red and the only instrument that could see it was a browser"
```

## What it does now

**One required check.** The job is `whole-tree` in a workflow now named `The gate`, and the name is
the contract: branch protection requires `whole-tree`, and `docs/features/the-ci-gate.md` carries the
exact settings for the Allfather to flip.

**It runs where a delivery happens.** Every `pull_request`, and `push` on `main` — where it feeds the
alarm. A branch with no PR is not delivered and no longer costs ten minutes of runner time.

**A red main shouts, once.** `bin/gates/main-red.sh` reads the log's own TOON rows, so the issue
quotes the ward rather than a summary of it:

- **title** — `main is red: weave (+2 more) — every index names every rule, plan and feature page`
- **body** — each failing gate, the gate's own tail under it, the failing wards and their findings
- **the commit that broke it** — over the range from the **last green `main` run** to this one,
  narrowed by the paths the findings name. Measured on the real 2026-11-11 log with `--since HEAD~4`:
  `**the commit that broke it:** 56fb9c32 feat(plan): a plan belongs to whoever owns the work (#649)`
  — which is the commit that did it.
- it is **updated** on the next red run, never duplicated, and **closes itself** on the first green one.

**A red pull request opens nothing.** It is red in its own checks, it is the author's to fix, and an
issue per branch is an inbox nobody reads. The workflow guards the alarm on
`github.event_name == 'push' && github.ref == 'refs/heads/main'`, and a test proves that guard is exact.

**Minutes, not tens.** The checkout is full only on `main` (attribution needs the history) and one
commit deep on a PR; Node 24 is seated from cache keyed on the lockfile; `~/.cache/ymir` is restored
for the ward verdicts part F of plan 243 will key on content; and a superseded PR run is cancelled
instead of queued. The remaining minutes are the whole-tree sweep itself, which is the gate — the
pre-push is what got the *filter* (plan 243 part B/C).

## What was proved

- `bin/gates/tests/test_main_red.sh` — thirteen properties, no network: the alarm bites (a title that
  names the gate, a body that quotes the finding, the failing ward carried, attribution present), and
  it stays quiet (a green log files nothing; no token calls no API at all — proved with a fake `gh`
  that records every call and is asserted never to be called; `close` on a green main with nothing
  open is a clean no-op; only a `main` push may open the issue).
- The real log from run `42941457521` regenerates the issue above, with the right commit named.
- A deliberately red tree on a throwaway branch shows the check red and opens **no** issue, because
  issues are opened for `main` only.

## Carry

Nothing exotic to carry: the workflow files ride the repository (any clone runs them), and
`bin/gates/main-red.sh` is a `bin/` door, so `bin/engine/ymir-install.sh` seats it on every machine
with the rest of `bin/` and `bin/agents/groa-update.sh` fast-forwards it on every update. The new row
in `bin/gates/ci-verify.sh` means a seat that has the door also runs its test — so a machine cannot
carry the door without the proof.

## CHANGE LOG

- **2026-11-11** — Written with the workflow (both hosts), the door, its test, the `ci-verify` row,
  the feature page and the branch-protection settings. Before: four red `main` runs, 7m30s–10m37s,
  announced nowhere, nothing required. After: one required check named `whole-tree`, a red `main`
  named within one run in one issue that closes itself, and a superseded PR run cancelled rather than
  queued.
