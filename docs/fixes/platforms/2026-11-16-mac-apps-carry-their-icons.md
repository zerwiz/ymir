# The Mac apps carry their icons

**Date:** 2026-11-16 · **Component:** platforms / desktop · **Found while:** checking the Ymir apps in a Mac's Applications

## What went wrong

`bin/desktop/shortcuts.sh` wrote a small `.app` per Ymir app on macOS, but with no icon. Every app showed the blank
generic icon in Finder, Launchpad and the Dock. Linux and Windows already received each app's icon.

## What changed

`mac_apps` now turns the app's declared PNG into an `.icns` with macOS's own `sips` and `iconutil`. It places the file
in `Contents/Resources` and names it in `Info.plist` (`CFBundleIconFile`). When either tool is missing, the app is
still written, without an icon, as before.
