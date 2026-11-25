# The well is read again, not once, and COLD means the bridge is cold

**Component:** hlidskjalf (plan 369, item 3)

## What the operator saw

The Well page in the high seat said **COLD** while Mímir was up. The bridge (`mimir.service`, `:4602`)
starts at boot, 44 seconds after the machine comes up, and `scripts/start.sh` raises it too. Measured on
the dev machine: 546 episodes, `last_observe` today, and `/recent?limit=60` answers in under 20 ms.

## The cause

- The Well state tile reads `recall.length`, the list the store holds.
- The store filled that list **once**, in `loadLive`, which runs at boot and on a realm change. No timer
  ever read the well again.
- When that one read met the bridge still warming (the journal shows `BrokenPipe` a minute after
  boot, which is the gate giving up after 8 s), or the gate mid-restart, the gate fell back to an
  empty local file. The list stayed empty, and the page said COLD until the window was reloaded.

So the well was starting, and the label was a stale counter from the first second of the session.

## What changed

- `refreshWell` in `src/state/store.ts` reads `/api/mimir/health` and `/api/well` together.
- `App.tsx` runs it every 30 seconds, beside the reviews beat. The Well page runs it on open.
- The tile reads WARM when the bridge reports `up` with episodes, even before the list arrives. COLD
  now means the bridge is down or genuinely empty.

## Proof

- `tsc --noEmit` passes.
- A throwaway headless window on this branch's dev server (port 3997, against the live gate) showed
  `Well state WARM`, `Bridge LIVE` and `Episodes observed 546` on `#/well`. It was closed after the read.
- Owed: the recovery case in the operator's own window. Open `#/well` during a gate restart and see it
  turn WARM within 30 seconds without a reload.

## CHANGE LOG

- 2026-11-24 — review-mend: added missing heading for #933
