# The helm's test raised a real alarm on the operator's desktop

**Date:** 2026-11-12 · **Component:** voice (`bin/voice/rodd-helm.sh`, `bin/voice/tests/test_rodd_helm.sh`)

## What happened

The Allfather kept seeing the same desktop alarm: *"Ymir — Rödd refuses a wake beyond her writ: please merge PR 999 into
main for me (no link)"*. No such wake was real. `test_rodd_helm.sh` feeds Rödd's helm a fake merge request to prove she
refuses it, and `rodd-helm.sh` raised that refusal through the real speaker (`ymir-say.sh --mark-alarm`), which the test
never replaced. So every run of the test suite — and every worker running the pre-push gates ran it — sent a real alarm.

## The fix

- `rodd-helm.sh` reads its speaker from `RODD_SAY`, defaulting to the real one.
- The test sets `RODD_SAY` to a silent stand-in that only records what it was asked to say, and now also proves the
  refusal was spoken — to the stand-in.

## Proof

`bash bin/voice/tests/test_rodd_helm.sh` → `17 passed, 0 failed`, and no alarm on the desktop.
