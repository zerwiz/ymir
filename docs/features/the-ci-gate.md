# The CI gate — the whole tree is judged before anything merges

> **Status: live.** One required check, `whole-tree`, on GitHub. It runs the entire ward suite on
> every pull request and on `main`, and it opens one issue when `main` goes red.

## What it is

The local pre-push hook is a **fast filter**. It runs in your own terminal, on the diff you are
about to push, and it exists so that a mistake costs seconds instead of a round trip.

**This check is the binding half.** It runs on GitHub's runner, on a tree nobody has touched, with
no hook to bypass and no local state to explain away. It is the same suite — one command,
`bin/gates/ci-verify.sh` — so the two can never disagree about what a rule is.

Two things came with it on 2026-11-11, and both are the point:

- the job has a **stable name**, `whole-tree`, so branch protection can require it. A check nobody
  has required is a check a red merge walks past.
- a red `main` now says so out loud: **one** issue, labelled `main-red`, naming the failing gate,
  quoting the ward's own finding, and naming the commit that broke it. It is updated while `main`
  stays red and **closes itself** the first time `main` is green again.

## What you need

- A GitHub account with write access to the repository (to push a branch and open a PR).
- Nothing local: the runner pins Node 24 itself, and the npm and ward caches are restored between
  runs. You do not install anything to make the check pass.

## The commands

```bash
bin/gates/ci-verify.sh          # exactly what CI runs — the whole suite
bin/gates/guards.sh             # just the tree wards
bin/gates/main-red.sh summary --log gate.log   # what a red run says, as the run page says it
bin/gates/main-red.sh report  --log gate.log   # the issue it would file, printed, no network
```

To reproduce a red run locally you do not need the log: run `bin/gates/ci-verify.sh`, and every
failing row prints its own finding underneath itself.

## How to read a red

The run page opens with a summary table: the failing gate, and its own words. Under it, the full
log. Read it in this order:

1. **A gate name** — `ward`, `inventory`, `weave`, `compliance`, `no-delete`, `public-data`.
2. **The line under it** — the ward's finding, which names the file. `bin/gates/INDEX.md is STALE`
   and `features: broken-register.md is not catalogued` are both actionable without opening
   anything else.
3. **Run that one gate on its own** — `bash bin/gates/guards/inventory-guard.sh check`. It takes
   seconds and prints the same refusal.
4. **If the finding is in a file your change never touched**, `main` is red and it is not yours.
   The `main-red` issue names the commit that did it. Do not fix it inside an unrelated PR unless
   you mean to; say so on the PR.

If `main` itself is red, the open issue is the one place to look. Do not open a second one.

## Making it required — the exact settings

The check is only a gate when the branch refuses to merge without it. This is the Allfather's to
flip, once, in **Settings → Rules → Rulesets → New branch ruleset** (or **Settings → Branches** on
the classic page), targeting `main`:

```
require[6]{setting,value,why}:
  "Require a pull request before merging","ON","RULES/08: the Allfather seals merges, and a PR is what Glitnir's Reviews surface judges"
  "Required status checks → add `whole-tree`","ON","the job name in .github/workflows/ymir-gates.yml. This is THE gate"
  "Require branches to be up to date before merging","OFF","a repair of already-proven work must not re-earn the whole suite (the law of 2026-11-09). With it ON every rebase re-runs ten minutes"
  "Dismiss stale pull request approvals when new commits are pushed","ON","a PR whose head moved is a PR nobody read. This is what makes merge commits safe"
  "Allow merge commits","ON","a squash drops the follow-up commits of a reviewed branch — #639 was squash-merged at its first commit and Forsetti's six mends never landed"
  "Allow squash merging","OFF","the same fault, chosen by a button. Use rebase instead when linear history is wanted"
```

Three details that matter and are easy to get wrong:

- **The name to search for is `whole-tree`.** GitHub lists it as `The gate / whole-tree`; typing
  `whole-tree` in the search box finds it. If the job is ever renamed, the protection points at a
  check that no longer exists — which GitHub reads as satisfied, quietly.
- **Do not enable "Require linear history" together with merge commits.** They are opposites; pick
  merge commits (the default here) or rebase-and-linear, never both.
- **Do not let an administrator bypass the ruleset.** A bypass turns the gate into advice, and the
  house has already paid for one night of `--no-verify`.

## Limits

- The alarm speaks **GitHub's** issue API. The Forgejo mirror runs the same gate and does not
  alarm — it has no required check and no issue door, and it says so in its own workflow comment.
- A red **pull request** opens no issue. It is already red in its own checks, it is the author's to
  fix, and an issue per branch would be an inbox nobody reads.
- Attribution names the commit that **touched the files the finding names**, in the range from the
  last green run on `main`. When several commits touched them, it names all of them rather than
  guessing one.
- The run takes minutes, not seconds. The heavy part is the whole-tree sweep, which is the point:
  the pre-push is the filter, this is the gate.

## If it does not work

- **The check never appears in branch protection's list.** The job has not run on a PR yet, or the
  job name changed. Push a PR, wait for the run, then search again.
- **`main-red` says "no earlier green main run was recorded".** There has not been a green `main`
  run since the alarm landed. The ward and its finding are still exact; the blame is the whole
  range, and `git log` on the files it names finds the hand.
- **The alarm step fails with `unavailable`.** The workflow's token cannot write issues: check that
  the job still declares `permissions: issues: write`.
- **A gate is red on `main` and every local push is fine.** That is expected and is exactly what
  the `main-red` issue is for — `main` is red, not your branch.

**See also:** [`the-wards-the-delivery-gate.md`](the-wards-the-delivery-gate.md) ·
[`finding-tally.md`](finding-tally.md) · `RULES/46-a-push-proves-the-rules.md`

## CHANGE LOG

- **2026-11-11** — written with the change it describes (plan 243 / plan 192 §11).
