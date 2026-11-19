# Apps — every app in its own home: install, update, roll back

## What it is

Each of Ymir's apps (Smíðja, Bilskirnir, Sessrúmnir, Óðrerir, Rödd, Hvergelmir) is moving to its own repo. Once installed, an app lives in **its own home**, never inside Ymir's `apps/` folder:

```
~/.local/share/ymir-apps/<app>/
  repo/              the app's clone
  releases/<sha>/    one built copy per update
  current            the release that runs
  previous           the one before it, for a rollback
```

One command, `bin/apps/apps.sh`, installs, updates, checks and rolls back every app. Hliðskjálf stays inside Ymir.

## What you need

- Ymir, with `git` and `python3`;
- for each app: its own repo carrying the app contract (`app.yaml` and `install.sh`). Until an app's move lands, it still lives in Ymir's tree, and `apps.sh` says **legacy** for it and installs nothing.

## The commands

| Command | Does |
|---|---|
| `bin/apps/apps.sh list` | Every app, with its kind, where it runs from (`dev`, `home`, `legacy`), and its `current` and `previous` releases |
| `bin/apps/apps.sh install <app>` (or `--all`) | Clones the app into its home and builds its first release |
| `bin/apps/apps.sh update <app>` (or `--all`) | Fetches, builds a new release, runs the app's own check, and switches to it only when the check is green |
| `bin/apps/apps.sh check` | Runs each installed app's own check |
| `bin/apps/apps.sh rollback <app>` | Switches `current` and `previous` |
| `bin/apps/apps.sh remove <app> --yes` | Removes the releases and the clone. Your app data and settings stay |
| `bin/apps/app-path.sh <app>` | Prints where the app runs from. `--list` prints every app |

Gróa's update (`/updateymir`) runs `apps.sh update --all` after Ymir's own update. Eir's `apps` surface runs `apps.sh check`.

To work on an app from your own checkout, set `YMIR_APP_<NAME>_DIR=/path/to/checkout` and every Ymir script will use it.

## Limits

- An update never switches to a release whose check is red. The app stays on the release it was on.
- While you are in a call, an update builds but does not switch or restart anything. It switches on the next update after the call.
- Ymir keeps the last three releases of each app.
- `YMIR_APPS_HOME` moves the apps home. A home inside Ymir's `apps/`, or inside the release folder your apps run from, is refused.
- App data and settings live in `~/.local/state/<app>` and `~/.config/<app>`. They are never inside a release, so no update, rollback or removal touches them.

## If it does not work

- **`legacy` for an app**: it has not moved to its own repo yet, so it still runs from Ymir's tree. That is expected until its slice lands.
- **`red` after an update**: the new release failed its build or its check. `current` is unchanged, and the line says why.
- **`built, waiting`**: you were in a call. Run `apps.sh update <app>` again afterwards.

## CHANGE LOG

- **2026-11-19** — written with Slice 0 of the split: the apps home, the resolver, the door, the contract.
