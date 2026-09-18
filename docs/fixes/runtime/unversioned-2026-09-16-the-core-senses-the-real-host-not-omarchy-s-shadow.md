## runtime · unversioned · 2026-09-16 — the core senses the real host, not Omarchy's shadow

### Why
- **`bin/ymir-install.sh` `step_host` ran the wrong sensor.** The core host step
  called `bin/omarchy-sense.sh` — the **Omarchy-only** sensor — so on any
  non-Omarchy host it learnt nothing and printed the sensor's own SKIP row as a
  host snapshot: `host snapshot:   sensor,SKIP,not an Omarchy host…`. On a Fedora
  workstation that is the whole discovery step, reporting a skip as fact.
- **Now it senses THIS machine with `bin/host-sense.sh`** — the portable sensor
  (the same one behind `ymir sense`) — on **every** host (Rule 05). Recording
  stays the Omarchy layer's job: `omarchy-sense observe`, the post-update hook,
  desktop placement, the plugin offer, and the alarm channel remain gated behind
  `step_omarchy`. Nothing here assumes Omarchy; nothing here skips the core
  machine either.
- `step_host` no longer branches on `--check`; it senses once and reports once:
  `host sensed: <os> / <id> / <family> / <session> / <desktop>`.
- The owning asset reflects it in the same change:
  `.agents/skills/galdr-ymirsystem/assets/installation.md` — the `host` step row,
  the Verify list, the two-layer table (recording, not learning), and the
  "Omarchy branches" note.

### Files
- *(carried from the frozen CHANGELOG.md)*
