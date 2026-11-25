# The smithy's database stays in the home

## What went wrong

`smidja.service` came out with `CMD_DB=<pin>/smidja/smidja.db`. The database lives at
`$YMIR_HOME/smidja/smidja.db`. A `SMIDJA_DB` path inside the home was lost the same way.

## The cause

`bin/fleet/fleet-ensure.sh` rendered the right path. It then handed the unit to the pin's `units.sh write`, which
took the home for a Ymir tree and moved the path onto the pin. The cure is in
[the home is not a Ymir tree](../engine/2026-11-25-the-home-is-not-a-ymir-tree.md).

The first reading blamed `fleet-ensure.sh` itself. A test run against the old script showed that it already
rendered both paths correctly.

## What changed

`fleet-ensure.sh` now asks the home resolver for `HOME_ROOT` directly, and reads `SMIDJA_DB` inside
`web_app_dirs`. Neither changes what it renders. Both keep the answer in one place.

`tests/test_fleet_smidja_db.sh` renders the unit and lets the settle step run against a temporary pin. Its two
settle checks fail with the old `units.py` and pass with the fix.

## What is still owed

A machine that carries the stop-gap drop-in `smidja.service.d/10-home-db.conf` can remove it once its pin carries
this change.

## CHANGE LOG

- 2026-11-25 — review-mend: added missing heading for #957
