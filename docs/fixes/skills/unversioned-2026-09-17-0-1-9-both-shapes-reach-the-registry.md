## skills · unversioned · 2026-09-17 — 0.1.9: both shapes reach the registry

### Why
- **`ymir raise` works on a packaged install.** 0.1.8 shipped before the resolver,
  so a user who installed from npm hit `cd …/apps/hlidskjalf: No such file or
  directory` — every package had arrived, and eighteen scripts were looking in the
  clone's `apps/`. `bin/app-lib.sh` resolves a surface in either shape now.
- **A clone and a package are one tree to the scripts.** Proven against both: the
  five surfaces resolve from `$HOME/Ymir` and from an npm-installed
  package, and `ymir raise` against a packaged tree fetches the app's
  dependencies, raises the gate API, starts Nornir cron, and brings up Bifrost and
  the well.
- **The patience words** — `style_patience` — open the installer's long chain and
  the raise path's build, so a long hour says what it is doing.

### Files
- *(carried from the frozen CHANGELOG.md)*
