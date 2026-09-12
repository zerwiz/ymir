# Desktop shell — Hlidskjalf · Smíðja (Electron)

The control plane runs as a native desktop app: one Electron shell per view,
selected by `YMIR_DESKTOP_VIEW` (`hlidskjalf` default, or `smidja`). Managed by
`scripts/electron.sh start|stop|status`; `scripts/start.sh` raises the stack.

## Automatic guarantees (in `apps/hlidskjalf/electron/main.cjs`)

- **Single instance per app identity** — `app.requestSingleInstanceLock()`. A
  second launch **focuses the existing window**; it never opens another. (This
  was the cause of windows stacking when agents started.)
- **Single window** — `openWindow()` reuses the live `win` and focuses it
  instead of constructing a new `BrowserWindow`.
- **Second-instance → restore + focus** — minimized windows come back.
- **Titles stay "Ymir"** — `page-title-updated` is suppressed.
- **External links** open in the browser; the app's own origin stays in-window
  (so auth redirects don't leave the app).

## The auth rule (one login, one window)

The shell must show **one** login and stay in **one** window. The gate session
login (`HLIDSKJALF_AUTH`) is the interim; **Heimdall (oauth2-proxy)** is the
target. The GitHub hop and the second window were both symptoms of two auth
systems at once — see the private plan `hodd/docs/electron-auth.md`.

## "The UI is gone"

Often the **backend is fine** (SPA `:3888`, gate `:3889`, visualizer `:8437`,
tunnel up) and only the **window** closed. `scripts/electron.sh status` should
verify a **live window**, not just a pid. Recovery: `stop` then `start` forces a
real window (a plain `start` on a stale pid is a no-op).

## Known script fixes

- `scripts/electron.sh`: a stray `local` outside a function (stop path) and the
  smidja pid-file write — both flagged; harden `status` to check the renderer.
