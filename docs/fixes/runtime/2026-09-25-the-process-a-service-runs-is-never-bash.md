## runtime · unversioned · 2026-09-25 — the process a service runs is never bash

### Why
The `.sh` audit (plan 58) found the damage is smaller than the count suggests —
the record services are already Python/Node/Bun — but named two genuine bash
daemons and two over-thick shims, and asked for a check so it cannot creep back.
This seats that check.

- **`bin/service-format.sh`** walks `tools/*/systemd/*.service` and reports three
  rules: **daemon-in-bash** (a long-running unit whose process *stays* a shell),
  **oneshot-loop** (a `Type=oneshot` whose body holds a foreground loop — a
  contradicting contract), and **service-in-shim** (a >40-line shell shim that
  only `exec`s a runtime). A shell that `exec`s a runtime is a thin **door**, not
  a service body, so a `bash -c '… exec …'` is not flagged.
- **Known debt is DECLARED** in `SERVICE-FORMAT.allow`, one `unit:rule` per line
  with its reason; a new finding **fails**, so the debt can be paid down but
  cannot grow. Declared today: `nornir` (oneshot-loop), `mill-worker`
  (daemon-in-bash), `mimir` · `bifrost` (service-in-shim).
- **The ward is seated in two places:** `bin/eir-doctor.sh` gains a `services`
  surface, and `compliance-check.sh` gains a `service-format` row (16 checks now).
- **`STRUCTURE.md` corrected** (Phase 8 ward): `bin/` no longer claims “158
  scripts” — it says the counted truth (355 files) — and it records that the tree
  `state/` is now a symlink to `$YMIR_HOME/state` (migration 0007), not a
  `.gitkeep`-guarded directory.

### Proved
- `bin/service-format.sh check` → 4 findings, **0 blocking**, exit 0 (all four
  declared). It also caught `hlidskjalf-spa.service` as a first-pass false
  positive, which proved the handoff rule: a `bash -c '… exec npx …'` is a thin
  door and is no longer flagged.
- `compliance-check.sh` → **16/16 PASS**, including the new `service-format` row.

galdr-reread: none (the ward's own allowlist is its record; plan 58's `.sh` audit
is the design).

### Files
- `bin/service-format.sh`
- `SERVICE-FORMAT.allow`
- `bin/eir-doctor.sh`
- `.agents/skills/galdr-ymirsystem/scripts/compliance-check.sh`
- `STRUCTURE.md`
