# The app contract

Every app that leaves Ymir's tree carries these files at its repo root. Ymir's
`bin/apps/apps.sh` installs and updates it from them, into the app's own home
(`$YMIR_APPS_HOME/<app>/`), never into Ymir's `apps/` and never into the pin.

| File | Does |
|---|---|
| `app.yaml` | name, kind (`electron` or `service`), window class, ports, units, launchers, icons, state and config dirs, the Ymir doors it needs |
| `install.sh` | builds the release in place; `--check` changes nothing and says what is wrong |
| `update.sh` | optional: replaces the build step for an update (fetch, flip and rollback stay Ymir's) |
| `start.sh` · `stop.sh` | raise and lower the app alone, on loopback |
| `uninstall.sh` | removes units and launchers; never state or config |

The release mechanics (export a commit into `releases/<sha>`, build, `--check`, flip
`current` only on green, keep three, roll back, wait out a call) live once, in Ymir's
`bin/apps/apps.py`, so no app carries its own copy. The how-to is
`docs/features/apps-install-and-update.md`; the plan is the split's plan 01.
