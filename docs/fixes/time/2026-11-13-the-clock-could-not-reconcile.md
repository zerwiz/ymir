# time · 2026-11-13 · The clock could not reconcile

## What

`home-sync-clock` was seated to keep the home level. It refused three times in one night with the same message:

```
refused,a real conflict — reconcile by hand
```

The cause was never a conflict of content. It was **an untracked file the merge would overwrite**: a door had
written a `plans/README.md` at a project shelf, the heart then committed that same path, and git refused the
merge before a single line was compared. Twelve such files in one pass.

## Why

The clock treated every refusal as a conflict, and a conflict as a hand's job. But "would be overwritten" is not
a disagreement — it is bookkeeping, and it has a lawful answer: move the stray aside (Rule 11), then merge.

## The fix

Before declaring a refusal, the clock reads the merge output. On *"would be overwritten"* it moves each named
file into `hodd/state/untracked-premerge-<stamp>/`, prints `moved-aside,<shelf>` and retries — up to six times.
Only a genuine content conflict still refuses, and still names itself.

## Proof

```
$ bash bin/vault/home-sync-clock.sh
home-sync-clock,pulled=0,pushed=0,left=0
```

and, on the night's real collision, twelve READMEs moved aside and the merge completed with the room file
unioned by hand — after which this change makes the hand unnecessary.

## Change log

- **2026-11-13** — written with the fix, after three identical refusals.
