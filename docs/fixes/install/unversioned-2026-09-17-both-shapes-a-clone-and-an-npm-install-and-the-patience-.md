## install · unversioned · 2026-09-17 — both shapes: a clone and an npm install, and the patience words

### Why
- **`ymir raise` failed on a packaged install** — and the reason was ours, not
  npm's. Every package had arrived; the scripts looked for the apps in the clone's
  `apps/`, where a package keeps nothing. `scripts/start.sh` died on
  `cd …/apps/hlidskjalf: No such file or directory`. **Eighteen files assumed the
  clone's layout.**
- **One resolver, both shapes:** `bin/app-lib.sh` — `apps/<surface>` in a clone,
  `node_modules/@zerwiz/<package>` in a package, with the surface→package map
  (`smidja` → `@zerwiz/smidja-factory`). Wired into the raise path, the windows,
  the invite door, the seat-hall, Eir, the icons, the placement, the hall snapshot
  and the installer's own SPA and shell steps. `bin/smidja-lib.sh` delegates to it
  now, so there is one truth about where things live.
- **Proven in both trees**: all five surfaces resolve from `$HOME/Ymir`
  (a clone) and from an npm-installed package. And `ymir raise` run against the
  packaged tree no longer dies — it fetches the app's dependencies, raises the
  gate API, **starts Nornir cron**, and brings up Bifrost and the well.
- **A trap worth naming:** `printf -v <name>` writes to the *function's* scope, so
  a helper whose scratch variable shares the caller's requested name swallows the
  answer. Every scratch name in the resolvers is function-prefixed for that
  reason.
- **The patience words.** A long install shoul

### Files
- *(carried from the frozen CHANGELOG.md)*
