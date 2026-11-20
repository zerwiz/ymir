# Ymir may name no app

**2026-11-20.** The Allfather: *"why doesn't Bilskirnir start from my app drawer?"* — the entry was correct, the
door behind it was not.

`bin/desktop/ymir-app` carried a `case` line per app, each pointing at `$pin/apps/<app>/start.sh` — a tree the
split removed. So Bilskirnir, Óðrerir, Sessrúmnir and Smíðja all resolved to paths that no longer existed, and
the menu entry did nothing without saying why. The same fix had to be made **twice**: once in the installed copy
`~/.local/bin/ymir-app`, and again here, or the next update re-seats the stale one.

Now the door **names no app**. It resolves the install (`ymir-apps/<app>/current`), reads that install's own
`app.yaml` for its `launch:` (falling back to `start.sh`), and only then the pin — for the one app that still
lives in Ymir. Anything else is refused **by name**, with both paths it looked in.

The rule this leaves: **an app's launcher is the app's own business.** Its repo ships `app.yaml`, `start.sh`
and its platform templates; Ymir keeps only the machinery that reads them. A door that lists app names must be
edited every time an app is added or retired, and that is the drift this removes.
