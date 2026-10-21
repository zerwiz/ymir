# The feature page lagged the feature by one commit

**Component:** ward · **Seat:** heimdall · **Date:** 2026-10-21

## What the Allfather asked

*"are feature.md updated"* — and the honest answer was **partly**. `FEATURES.md` carried a Garmr
row and `features-guard` passed (every page is catalogued, exit 0), but the row described the
hound as it stood **before** three changes landed in the same session:

1. the **file-change senses** — identity files (`/etc/passwd`, `/etc/shadow`, `/etc/group`,
   `/etc/sudoers(.d)`, `~/.ssh/authorized_keys`) at CRITICAL, persistence surfaces (units, cron,
   autostart) at HIGH;
2. **`bin/ward/garmr-smoke.sh`**, the reusable 9-check test;
3. **`bin/ward/garmr.sh refresh`**, which Gróa calls after every pull.

And the feature page's sense table listed five senses while the code had seven.

## Why the guard did not catch it

`features-guard` asks **"is every page catalogued?"** — a presence question. It cannot ask
**"does the row still describe the thing?"**, because that is a judgement about prose. So the gate
was green and the document was stale: Rule 14's debt, exactly.

## The fix

- `FEATURES.md` gains a **corrected row** that cites the first (Rule 06: append, never rewrite) and
  states the additional senses and doors.
- `docs/features/the-guardian.md` — a living how-to, so it moves in place — now lists the
  file-change senses, `garmr-smoke.sh`, `refresh`, and says **why** the switch needs root.

## The lesson worth keeping

A presence gate is not a currency gate. When a feature grows a capability, the row and the page
are part of the change — and if the guard cannot see that, the reviewer is the guard.
