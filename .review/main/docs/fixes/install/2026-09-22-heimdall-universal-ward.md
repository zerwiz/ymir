## install · unversioned · 2026-09-22 — Heimdall is universal: the ward rides the install

### Why
The ward existed only on the Omarchy seat (fetched by hand, until now). The
Allfather's word: **entry to every computer comes through Heimdall** — one
published GitHub key opens every warded machine, Omarchy or Ubuntu alike, and
a fresh seat must stand warded at setup, not by a later errand. An external
**Ubuntu drive** seat is planned; it must carry the ward without a special
errand.

### What
- **`bin/heimdall-ensure.sh` (new):** ensure surface in the house pattern
  (like `hermes-ensure.sh`). `status` reports `heimdall[1]{ward,version,
  gh_users,keys,timer,linger,sshd}`; `ensure [--install]` fetches the ward to a
  **stable path** (`~/.local/bin/heimdall-ssh-keys.sh`, never the repo tree so
  the systemd user timer survives upgrades), records the operator's GitHub user
  (env `HEIMDALL_GH_USERS` → `~/.config/heimdall/gh-users` → the distro
  remote's owner), fetches/validates/merges the keys, and arms the 15-minute
  timer. `--install` may add `openssh` via pacman/apt (sudo, system package) —
  never silently.
- **`bin/ymir-install.sh`:** new `heimdall` step (after `host`, before
  `sandbox`), `STEP_TOTAL` 19→20. Runs `heimdall-ensure.sh ensure --install`;
  reports the ward honestly, a bare seat is a WARN not a failure.
- **`bin/ymir-plan.sh`:** phase-6 `wire` row — a warded seat is a `SKIP`, a bare
  one a `DO` (never a BLOCKED: a seat can stand without it, it just has no
  second door).
- **`bin/heimdall-ssh-keys.sh`:** 1.0.0 → **1.1.0**, portability documented
  (proven Omarchy + Ubuntu/Debian, Debian `ssh` unit vs Arch `sshd` handled).
- **Galdr asset** `installation.md`: the `heimdall` steps row, the count
  25→26, the phase-6 gate line, and a Heimdall section.

### Files
- `bin/heimdall-ensure.sh` (new)
- `bin/ymir-install.sh`
- `bin/ymir-plan.sh`
- `bin/heimdall-ssh-keys.sh`
- `bin/README.md`
- `.agents/skills/galdr-ymirsystem/assets/installation.md`

### Rollout (fleet)
- `zerwizserver` (.103) and `whynot` (.111): ward seated this day from omarchy
  — 10 keys each, timer live (`~/.local/bin/heimdall-ssh-keys.sh`); desktop
  seats first, then the heimdall box via `bootstrap-heimdall-ward.sh` (the
  private shelf), then the Ubuntu drive seat at install time.
- One console action outstanding: `sudo loginctl enable-linger whynot`.