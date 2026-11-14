# A page is not a session — the Runtime page runs `--page`

**Plan:** 275, item 36b. **Date:** 2026-11-14. **Owner:** the errand `digest-head`.

## What was wrong

The helm saw Hlidskjalf's Runtime page print `session lock held (pid 3997773)` and
`helm: Hœnir · unknown`. Both were one fault.

`apps/hlidskjalf/server/index.ts` asked for the digest with **no argument**
(`bash bin/time/saga-session-start.sh`), and the no-argument call **is a session start**: it
takes the lock. So drawing a page became a hand on the helm. It printed the gate's own pid as
the lock's owner, and then read back the identity-less lease that the acquisition had just
written — which renders as `unknown`, because RULES/44 renders an absent field rather than
inventing one.

## The fix

A mode, not the caller's honour:

| Call | What it is |
|---|---|
| *(no argument)* | a session start: the stages, then the head — takes the lock |
| `--head` | the head alone; the lock is only read (the compaction path) |
| **`--page`** | **the head for a page that DRAWS it: no lock, no lease, no marker** |

`--page` says in words that it takes nothing (`lock: read-only — this run takes nothing,
refreshes nothing and holds nothing`), and the arm it names comes from the arm lease
(`bin/seat/helm-identity.sh --line`), so a page always shows the arm that is really held.
`apps/hlidskjalf/server/index.ts` now passes `--page`.

## How it was proved

- `bin/time/tests/test_saga_head.sh` section 4b, six checks: a `--page` run in a fresh machine
  state dir leaves that directory **empty**; it never prints "held by this session"; its lock
  line says it takes nothing; the head names itself `(read-only page)`; the helm line it prints
  is the lease's arm (gen 48, pid 2966876 when this was written) and never the gate's pid; and
  Hlidskjalf's server asks for `--page`.
- The whole head test: **42 checks, all green.**

## Not done, and why

The running hall still serves the old tree — apps and harness hooks both run from the pin
(RULES/02 §7) — so the live Runtime page shows this after the next release
(`bin/engine/release.sh build --ref main`, then `flip <sha>`). Drawing the page itself is item
25's errand (`one-hlidskjalf`); 36b only makes the digest run it invokes read-only.

## CHANGE LOG

- **2026-11-14** — written with the change it describes (plan 275, item 36b).
