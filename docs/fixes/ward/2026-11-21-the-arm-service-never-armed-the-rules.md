# The guardian's arm service never armed the rules

**Date:** 2026-11-21 · **Component:** ward (`tools/mill/systemd/garmr-arm.service`) · **Errand:** `garmr-arm-fix`

## What was wrong

On heimdall the garmr hound has been running since 20 October with a heartbeat from 31 October. The audit
rules file exists (2460 bytes) but `auditctl -l` returns 0 rules — nothing reached the kernel.

The cause: the ExecStart line contained `\#` in a case pattern, which systemd interprets as an unknown
escape sequence and strips the backslash. The resulting shell command never matched comment lines, and the
`while IFS= read -r line` loop's exit status was masked by `|| true`, so the service reported success
while loading nothing.

## What was built

Removed the backslash. `#` inside a `case` pattern needs no escaping in shell, and systemd does not
interpret it.

## What this does not decide

- **The installed service on heimdall still has the old line.** Fixing it needs `sudo bash garmr.sh install`
  on that machine, which needs the operator's password.
- **The hound must be restarted** after the rules are armed.

## CHANGE LOG

- 2026-11-21 — written when the heartbeat was found 21 days old.
