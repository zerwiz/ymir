# The alert fold kept apart only what was the same alarm

**Date:** 2026-11-21 · **Component:** notify (`bin/notify/send.sh`) · **Errand:** rework of PR #861 (that PR merged at its earlier head, so these fixes land as a follow-up PR)

## What was wrong

The review of PR #861 found that the new grouping hid real, distinct alerts for an hour.

| fault | where | effect |
|---|---|---|
| any key segment of 6 or more digits folded as a stamp | `bin/notify/send.sh`, the `STAMP` pattern | garmr's `garmr:{title}:{pid}` alerts for two 7-digit pids merged, so the second process was silenced |
| an unkeyed message folded every digit | `bin/notify/send.sh`, the auto key | `new PR #857 opened` and `new PR #858 opened` merged into one notice |
| the docs named the wrong template path | the first note and `docs/features/the-hotline.md` | they said `config/notify-owners.conf.example` |

## What changed

- A key folds only real stamp shapes: `20YYMMDD` with an optional hour, minute and second, a 10-digit epoch, and an
  ISO date or time. The ISO stamp is lifted from the whole key before it is split on `:`.
- An unkeyed message folds only measurements: a stamp or clock time, a number with a unit (`25895s`, `3 min`, `91%`),
  and a number after `age`, `old`, `rc`, `exit` or `took`. Any other number is kept as an identity.
- Both docs now name `.agents/config/notify-owners.conf.example`.

## The proof

```
$ python3 bin/notify/tests/test_alert_owner_road.py
Ran 19 tests … OK
```

The new tests: two pids in a key stay two lines; an epoch or ISO stamp still folds; two PR numbers and two ports stay
two lines each; changing measurements still fold into one. The live run on two machines is recorded on the PR.

## CHANGE LOG

- 2026-11-21 — written for the rework the judge asked for.
