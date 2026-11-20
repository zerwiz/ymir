## install · unversioned · 2026-09-17 — npm-only: the hall answers on its own port, and the marks land on any desktop

### Why
The Allfather turned off every service running from the clone and asked for the
npm path alone to be true.

- **The SPA never listened on `:3888`.** `scripts/start.sh` raised it with a bare
  `npm run dev`, so Vite took 5173 — then 5174 — while `ymir-validate.sh` and
  every door looked for `:3888`. The port is now our decision
  (`--port "$HLIDSKJALF_PORT" --strictPort`), a packaged install serves its built
  `./dist` through `vite preview` instead of a dev server, and the raise prints
  the last lines of the log when the port does not answer instead of claiming
  success.
- **Óðrerir was skipped on a packaged install** — `HALL_DIR="$ROOT/apps/odrerir"`,
  the clone's layout again. It resolves through `bin/app-lib.sh` now
  (`app_dir odrerir`), like every other surface.
- **The launcher entries and the icons are the freedesktop half, not Omarchy's.**
  Both halves of `bin/desktop-place.sh` sat behind the Omarchy gate, so a GNOME
  operator got *nothing* — no entries, no rune icons — which is why the desktop
  marks from the clone existed and the ones from npm never appeared. `entries` is
  its own verb now (any Linux desktop), the installer's `marks` step calls it, and
  the desktop database and icon cache are refreshed afterwards.
- **A user can see what moved.** `npm install -g` says *"changed 266 packages"* and
  no versions. The CLI records the version it last ran and says

### Files
- *(carried from the frozen CHANGELOG.md)*
