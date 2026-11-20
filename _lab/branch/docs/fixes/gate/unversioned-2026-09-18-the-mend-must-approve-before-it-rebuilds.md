## gate · unversioned · 2026-09-18 — the mend must approve before it rebuilds

### Why
- rebuilt dependencies successfully is gated too: without `npm install-scripts approve electron` first it
  silently changes nothing, and the window still never opens. The mend now approves, rebuilds,
  and only then reports.

### Files
- `(see the body)`
