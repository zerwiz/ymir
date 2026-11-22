# A Veil resend counts only when it landed

**Date:** 2026-11-22 · **Component:** agents (`bin/agents/veil.sh`) · **Plan:** 350 part B

## What was wrong

On the first live report, the sweep typed an unanswered report into the arm holder's pane. The pane door,
`bin/agents/eindri-notify.sh`, answered "herdr did not accept the turn … the chat injection did not happen",
and exited 0. The Veil recorded the item as resent, so it never tried again. The holder never saw the line.

## What was built

A resend counts only when it landed. The Veil reads the door's words as well as its exit code. A resend that did
not land is recorded as `undelivered` and tried again on the next sweep, three times at most
(`VEIL_PANE_TRIES`). The trouble panel's `receipts` row still turns red at 10 minutes. It did so live on the same
report: "1 report(s) with no RECEIVED from the arm holder, the oldest 23 min".

## Proof

`bash bin/agents/tests/test_veil.sh` — 26 passed, including "a resend the pane did not take is not recorded as a
resend" and "a failed resend is retried, three times at most".
