# The move broke his roots — every door that counted `..` pointed at `systems/`

**Date:** 2026-10-31 · **Component:** assistant · **Status:** fixed, and his service is up

## What the move did

`bin/assistant/` moved to `systems/skirnir/services/` — one level **deeper** than it was. Every door that
computed the repository root by *counting* `..` therefore landed one level short: `skirnir.py` and
`telegram.py` resolved to `/home/heimdall/ymir/systems`, `ground.py` used `parents[2]`, and `paths.py`
and `research.py` built the vault library's path as `<here>/../vault/hoard-lib.sh`, which does not exist.

The failure was quiet and expensive in exactly the wrong way: Skírnir's **Telegram service** reported
`telegram[1]{error}: "SKIRNIR_TELEGRAM_BOT_TOKEN is missing from the vault"` — because the vault door it
called was not there — and restarted every five seconds. The token was in the vault the whole time.

## The fix, in two halves

1. **The doors know where the root is by depth, not by guesswork.** `skirnir.py`, `telegram.py` and
   `ground.py` count three levels (services → skirnir → systems → repo), and `paths.py` / `research.py`
   point at `bin/vault/hoard-lib.sh` through the same three levels. Verified by resolving each and
   comparing to the repo root.
2. **The unit ships.** `tools/mill/systemd/skirnir-telegram.service` is the template (with
   `__YMIR_BIN_DIR__` / `__YMIR_HOME__` placeholders, as `snotra-detect.service` does), and the home's
   copy is generated from it rather than pasted from a how-to. The old home unit named
   `bin/assistant/telegram.py`, a path that stopped existing the day he moved.

## Measured

`systemctl --user restart skirnir-telegram` → `active`, one process, no restart loop; journal quiet.

## The lesson worth carrying

**A move is a migration for code too, not only for paths in a schedule.** Every relative root computed by
counting `..` is a silent break, and the py file that breaks is the one that only runs when something
speaks to the user. The ward has a `path-ledger-guard` for strings; it has nothing for arithmetic on the
filesystem. That gap is named here, not mended.
