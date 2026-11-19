# The release names its own role, and the test's fake seat stays alive

**Date:** 2026-11-19 · **Component:** voice · **Door:** `bin/voice/rodd-arm.sh release` · **Test:**
`bin/voice/tests/test_rodd_arm.sh`

This follows `docs/fixes/voice/2026-11-19-a-hold-declares-the-callers-own-role.md`.

## What was wrong

The `voice-arm` gate failed 5 of 68 in CI, while the same test passed 68 of 68 on a seat. The CI log said a hold
returned rc=3, *"the session the lock resolves … is not alive"*, and the release line still read *"Rödd gives the
helm back"*.

Two causes:

1. **The test's fake pi seat died at once in CI.** Section 10 copied `sleep` to a file named `pi` and ran it. Where
   coreutils is one multi-call binary, a `sleep` renamed `pi` exits immediately. The session pid was dead before the
   hold, so the hold refused, and every check after it failed.
2. **A release with no sidecar named Rödd.** `release` read the role sidecar only from the home's state dir, while
   `hold` writes it into the lease's state dir when a lease exists. With no sidecar found, the release fell back to
   Rödd rather than to the caller's own role.

## What was forged

- The fake seat is now a small bash script named `pi` with an absolute interpreter path, so its comm is `pi` and it
  stays alive by waiting on a child. A new check proves it stands (alive, comm=`pi`) before the hold.
- `release` reads the sidecar where `hold` wrote it, and with no sidecar it names the releasing session's own role
  (the same resolution `hold` uses). Rödd is named only when the sidecar says `rodd`.
- A new check: a release whose sidecar is gone names the caller's own role.

The attach-only arm hook from the same batch is unchanged.

## Proof (measured)

```
bash bin/voice/tests/test_rodd_arm.sh                       → test_rodd_arm: 71 passed, 0 failed
the same, started with setsid -f (no harness in its tree)   → test_rodd_arm: 71 passed, 0 failed
```

> [!NOTE]
> The CI runner itself was not reached: `gh` did not answer from this seat. The cause is read from the recorded CI
> failure text, and the fix removes the copied binary entirely.
