## skills · unversioned · 2026-09-11 — Load the owning asset before editing a governed path (5 layers)

### Why
The runtime drifted from its documentation because the asset that governs a
subsystem was never loaded before the code changed. Five layers now prevent it:

- **1. `AGENTS.md`:** a new `governed[6]` table maps each governed path to the
  asset to load first, and `manual[]` gained `installation`, `ui`, `runtime-spec`.
- **2. Session digest:** `saga-session-start.sh` prints an `ASSET ROUTING` block
  every session, so the mapping is always in context.
- **3. Router loadable:** `galdr`'s `disable-model-invocation` is removed (it hid
  the one router that owns the assets); `tyr-check` keeps it (deliberate).
- **4. Enforced seatbelt:** new `bin/syn-asset-pretool-check.sh` denies an
  `edit`/`write` of a governed path until its asset was read (`state/asset-reads`);
  the Pi extension relays it and records asset reads.
- **5. Compliance gate:** `compliance-check.sh` gains an `assets` check that
  FAILS when a governed path changed without its asset (it caught this very
  change), and `runtime-compliance.md` documents G12 + the routing map.

### Files
- *(carried from the frozen CHANGELOG.md)*
