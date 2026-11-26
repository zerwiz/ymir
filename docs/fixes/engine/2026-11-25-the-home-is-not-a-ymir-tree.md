# The home is not a Ymir tree

## What went wrong

`bin/engine/units.py` calls a directory a Ymir tree when it holds `RULES/` and `bin/engine/ymir-install.sh`.
An operator's home can hold both. Every unit line naming the home was then judged to be off the pin.

On a dev machine, `units.sh check` reported eleven good lines as `OFF-PIN`. One was `hlidskjalf-gate`, only
because of `EnvironmentFile=-<home>/.env.local`.

`units.sh write` was worse. On 2026-11-23 and 2026-11-25 it rewrote home paths onto the pin. The replaced lines
are in `<home>/state/units-replaced.log`.

`heart-doors.service` was also reported `UNREGISTERED`, because the register did not name it.

## What changed

- A path inside `$YMIR_HOME` is the home. `stray_roots` and `names_ymir` no longer count it.
- `heart-doors` is in `config/units.yaml`, owed by the `forge`, `dev` and `hand` roles.
- Five checks in `bin/engine/tests/test_units.sh` expected launchers for apps that left this repository. They now
  check the two launchers this tree ships.

## How it was proved

`test_units.sh` plants the rewritten lines in a home that carries `RULES/` and an installer, then runs
`units.sh write`. It fails on the old `units.py`. With the fix the file reports 53 passed, 0 failed.

A read-only `units.sh check` on the dev machine went from 12 problem rows and exit 1 to none and exit 0.

## What is still owed

- The fix takes effect when the pin carries it. Until then the pinned `units.sh write` can rewrite the lines again.
- `write` never retargets a path written `EnvironmentFile=-<path>`, while `check` does report one. This change
  leaves that as it was.

## CHANGE LOG

- 2026-11-25 — review-mend: added missing heading for #957
