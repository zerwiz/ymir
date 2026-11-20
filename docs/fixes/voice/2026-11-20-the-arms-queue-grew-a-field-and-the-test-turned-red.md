# The arm's queue grew a field, and a test that counted to five turned the whole tree red

**Date:** 2026-11-20 · **Component:** voice (`bin/voice/tests/test_rodd_arm.sh`) · **Errand:** `gather-20261120-020351`

## What was wrong

Every pull request, on every branch, was blocked by one assertion:

```
"voice-arm","FAIL","Rödd knocks on the arm, and refuses when nobody is holding it (plan 223)"
    test_rodd_arm: 70 passed, 1 failed
```

Measured on `main` as well as on the branch, so it was not the branch's fault. The failing line was this:

```bash
[ "$(printf '%s' "$line" | awk -F'\t' '{print NF}')" = 5 ] && ok "the message's tabs did not become fields"
```

The queue line it judged, printed with `cat -A`, was:

```
1795142661^I1^Isignal^Irodd-1795142661^IRM-CM-6dd (the voice) to the arm holder: hand this on with a tab^Iclass=voice
```

Six fields, not five: the state module's queue grew a `class=` field (plan 328, the wake's class), and the
count in this test was left behind. Nothing about the message was wrong — the tabs inside it had been
flattened exactly as intended — so the assertion was measuring the queue's **arity** while claiming to
measure the message's **tabs**.

## What was built

The assertion now compares like with like: the field count of a line whose message carries tabs is compared
with the field count of a line whose message carries none. The arity is the state module's business; the tabs
are the test's.

A second assertion in the same block had the same disease — `NR = 2` after two tells — and now counts the
lines before and after a tell and requires exactly one more, so a future format change cannot fail it a third
time.

## The proof

```bash
$ bash bin/voice/tests/test_rodd_arm.sh | tail -1
test_rodd_arm: 71 passed, 0 failed
```

Before: `70 passed, 1 failed`, on `main` and on every branch.

## What this does not decide

- **It does not change the queue.** The `class=` field is a real contract that arrived with plan 328; this
  change is only the proof catching up with it.
- **It does not explain why it was green once.** The assertion passes when the queue line has five fields, so
  it was true until the class field landed — which means the gate was red from that merge until now, and
  that is worth knowing: a red gate was merged over once already.

## CHANGE LOG

- 2026-11-20 — written while a merge queue waited on it.
