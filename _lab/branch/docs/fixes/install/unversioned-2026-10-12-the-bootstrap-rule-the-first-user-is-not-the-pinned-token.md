## install · unversioned · 2026-10-12 — the bootstrap rule: the first user is NOT the pinned token

### What

Measured on the heart while seating Gladsheim: continuwuity **ignores the configured
`registration_token` until the FIRST account exists**. It prints its own first-boot token,
which is the only one that works for that first account; from the second account onward the
pinned token governs. The ensure's comment asserted the opposite, so the first registration
failed with `M_FORBIDDEN Invalid registration token` — a real defect found by running it,
not by reading it.

The script now states the true sequence in its header and gains a **`bootstrap`** action that
prints the first-boot token and says plainly what to do with it:

1. the engine comes up and prints a first-boot token (or the admin console creates user 1);
2. create the **operator's** account with that token;
3. from then on the pinned `ROOM_BOOTSTRAP_TOKEN` registers every agent.

### Verified

- On the heart: the bootstrap action printed the engine's own first-boot token; the operator
  `@zerwiz:gladsheim.local` registered with it, and the **pinned** token then registered the
  agent `@brokk:gladsheim.local` — the documented order, in that order.

### Files

- `bin/room/gladsheim-ensure.sh`
