## runtime · unversioned · 2026-09-26 — the A2A directory never rose at boot (wrong target)

### Why
`~/.config/systemd/user/a2abridge-directory.service` (written by the a2abridge
engine's installer) declares `WantedBy=multi-user.target` — a **system**-manager
target. The unit is a **user** service; the user manager boots to
`default.target` and never activates `multi-user.target`. So the unit was
`enabled` (a symlink was cut) but **no boot ever pulled it** — the A2A directory
(`:7777`) stayed dead across reboots while every `a2abridge bridge` process
announced to nothing. Measured: `systemctl --user is-enabled` said enabled,
`is-active` said inactive, dead; `bin/ratatoskr.sh status` read
`directory down · agents none`; a manual `a2abridge service run --addr
127.0.0.1:7777` answered instantly — the daemon was healthy, the boot hook was
mis-wired.

### What
- **`bin/a2abridge-ensure.sh`** gains `patch_unit_boot()`: when the engine's
  unit says `WantedBy=multi-user.target`, rewrite it to
  `WantedBy=default.target`, `daemon-reload`, and `enable` (the wanted-by
  symlink follows to the user boot target). Called from `ensure()` beside the
  existing `patch_unit_logs()` — the same adapter that already heals the
  engine's `/var/log` output problem, now healing the boot hook on every seat
  that runs the ensure.
- **`bin/autoboot-lib.sh`** adds `a2abridge-directory` to the ONE program
  table: owed by `heart` and `dev` (the seats that run the mesh), so the raise
  and verify paths seat and prove it alongside the well/tickets/skills doors.
- **`tools/mill/systemd/a2abridge-directory.service`** — a house-style unit
  template (`WantedBy=ymir.target`, the seat's own boot target) so a raise
  materializes the directory from the tree, not from a lingering engine unit.

### Files
- `bin/a2abridge-ensure.sh`
- `bin/autoboot-lib.sh`
- `tools/mill/systemd/a2abridge-directory.service`

### Proof
After the mend on a live seat: the unit's `[Install]` reads
`WantedBy=default.target`, `systemctl --user is-enabled` is enabled and a
`default.target.wants/` symlink exists, the directory answers on `:7777`, and
`bin/ratatoskr.sh status` reads the directory up. A reboot (or
`systemctl --user start ymir.target`) pulls the directory without a hand.