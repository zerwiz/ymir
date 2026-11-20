## desktop · 2026-11-20 — the drawer door reads the window's kind from the app

### Why

The operator asked whether Óðrerir could be a Tauri app, beside the Electron one, with nothing retired until it
passes. A Tauri build is useless if the desktop cannot open it: every launcher entry runs `ymir-app <app>`, and
`bin/desktop/ymir-app` sent Óðrerir to the Electron shell by name, with no way for the app to say otherwise.

### The fix

- `bin/apps/app-kind.sh` (new, sourced): `app_kind <app> <home>` reads `kind:` from the app's own `app.yaml` —
  a scalar, or a per-platform map with `default:` — and prints `electron` or `tauri`. `app_launcher <home> <kind>`
  reads `launch: <kind>: <platform>:` and returns the launcher's path in the app's home. `app_window_class`
  reads `window_class`. `YMIR_APP_KIND_<APP>=tauri` overrides for one launch, so the spike can be tried without
  editing the app. An unknown kind, or a declared kind with no launcher here, is a refusal, never a guess.
- `bin/desktop/ymir-app`: before its old per-app road, it asks the app's kind. A `tauri` kind is opened by the
  app's own launcher, with the window placed on the user's desktop by the `window_class` the app declares and
  `YMIR_WINDOW_BUTTONS` sensed the same way the Electron shell senses it. Every `electron` kind keeps the road it
  had, untouched.

### Proof

- `tests/test_app_kind.sh` — 12 cases, fenced (a throwaway pin and app home): both shapes of `kind:`, the override,
  the refusals, and the door execing the Tauri launcher for a `tauri` kind and the Electron shell for an
  `electron` one. Last line: `ok    a tauri kind with no launcher here is refused, not guessed`.
- `tests/test_electron_home_app.sh` still passes.
- The Tauri window itself is proved in Óðrerir's own repo (branch `eindri/tauri-spike`, `docs/tauri-spike.md`).
