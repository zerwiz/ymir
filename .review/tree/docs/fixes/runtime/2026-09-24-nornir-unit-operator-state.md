# 2026-09-24 — the nornir unit never pointed at the operator's state

## What
- The cradle's `nornir.service` (tools/web/systemd/nornir.service, rendered by
  `fleet-ensure.sh`) set only `PATH`; `nornir-cron-start.sh` then defaulted
  `BROKK_STATE_OVERRIDE`/`BROKK_CONFIG_OVERRIDE` to the code tree's state — while
  the compliance smoke reads the operator's home state (`$YMIR_HOME/state`). On a
  fresh systemd cradle the cron row was red: "Nornir cron is not running".
- Fixed at the seam: the template now carries
  `BROKK_STATE_OVERRIDE=__YMIR_OPERATOR_STATE__` and
  `BROKK_CONFIG_OVERRIDE=__YMIR_OPERATOR_CONFIG__`, and `fleet-ensure.sh` renders
  those placeholders from `$HOME_ROOT` (the home the operator chose at install —
  `bin/hoard-lib.sh`), so every future seat points its scheduler at the operator's
  state and schedule, never the tree's.

## Verified
- Host-side proof: a systemd drop-in with the same two envs (this machine, before
  the template fix) turned the smoke's cron row green and wrote
  `$HOME/Documents/ymirhome/state/cron.pid` with a live pid.
- Template render path confirmed: `fleet-ensure.sh`'s `sed` now substitutes the
  two placeholders from `$HOME_ROOT` (line 28: `HOME_ROOT="$AUTOBOOT_HOME_ROOT"`,
  which resolves `$YMIR_HOME` → `~/Documents/ymirhome`).

## Files
- tools/web/systemd/nornir.service — two Environment lines with the placeholders
- bin/fleet-ensure.sh — two `sed` substitutions (operator state/config)
- .agents/skills/galdr-ymirsystem/assets/nornir-jobs.md — §1.4 note (asset law)