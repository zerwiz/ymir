# A refusal's key ignores the clock stamp, and the helm test is current again

**Component:** voice (plan 369, item 2)

## What was wrong

`bin/voice/tests/test_rodd_helm.sh` failed 7 of 31 on main. Two faults were in the code and the test:

- **Code.** The wake drain now prefixes every `WAKE` line with Sól's local stamp
  (`2026-11-24 21:36 CET — …`). `rodd-helm.sh`'s `instruction_of` stripped only an ISO stamp, so the
  local stamp went into the refusal key. The key changed every minute, and the same refused
  instruction raised a fresh notification each time. That is the night-after-night toast plan 254 B7
  was meant to stop.
- **Test.** It still looked for a spoken refusal in a `said.log` stand-in that no longer exists (the
  refusal speaks through the notify door). It matched the old room text `refused: please merge…`. It
  carried the phrase its own last check forbids, and it read `apps/rodd/src`, which left for its own
  repository on 2026-11-19. Its dedupe checks relied on `send.sh --dry-run` writing the dedupe ledger,
  which #861 stopped.

## What changed

- `instruction_of` strips the local stamp as well as the ISO one, so the same request has the same key.
- The test checks the refusal reached the notify stand-in. It matches the current room line and reads
  only directories this tree has. Its stand-in answers `duplicate` for a key it has already seen,
  because what Rödd owns is a stable key. The one-line-an-hour rule belongs to the notify door.

## Proof

`bash bin/voice/tests/test_rodd_helm.sh` prints `31 passed, 0 failed`. Before the change it printed
`24 passed, 7 failed`, and with only the test changed, `both attempts carried the same key` still failed.
