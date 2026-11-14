# desktop · 2026-11-12 — apps run from a proved release, on one Electron, from one command

## Files
- `bin/engine/release.sh` (new): build, prove, flip, rollback, adopt and status for releases behind one link
- `bin/engine/runtime-deploy.sh`: a pin that is a link is updated by building and flipping a release, never by `git reset`
- `bin/desktop/ymir-app` (new) and `bin/desktop/shortcuts.sh` (new): one command for every shortcut; the Linux entries,
  the Windows Start-menu shortcuts from WSL, and macOS `.app`s
- every `*.desktop.in`: `Exec=__YMIR_APP__ <app>`, `Icon=ymir-<app>`, `Name=Ymir · <App>`; `units.py`,
  `desktop-place.sh` and `apps/bilskirnir/setup.sh` render `__YMIR_APP__`
- `bin/desktop/desktop-place.sh`: the Omarchy SUPER keys run `ymir-app`
- `bin/fleet/fleet-deploy.sh`: acts only from the pinned runtime or a global npm install
- `bin/desktop/electron-lib.sh`: the `local` lines no longer read `$app` before setting it; the fetch uses the locked version
- `apps/{hlidskjalf,rodd,sessrumnir}/package.json` and both lock files: Electron pinned exactly at 43.8.9
- `apps/rodd/start.sh`, `apps/bilskirnir/start.sh`: the one resolver; no `/usr/lib/electron*` fallback
- `scripts/electron.sh`, `bin/desktop/sessrumnir-launch.sh`: no call guard on dashboards (plan 275 S8); `YMIR_DEVTOOLS_PORT`
- `bin/agents/groa-update.sh`, `bin/engine/ymir-install.sh`: every shortcut written on each run; the install opens no window

## Why
Plan 275, parts one and two: the pin was moved in place under open windows; Electron was never installed by the update;
five Electrons ran six apps; Hlidskjalf served Vite's dev server and Sessrúmnir built at the click; launchers named
whatever folder wrote them; npm's postinstall redrew the Omarchy keys from any folder npm ran in; and no Windows
shortcut was ever written.

## Proof
heimdall and nidavellir: a release of local main builds and proves with all five apps on Electron 43.8.9 from inside
the release. `bin/engine/tests/test_units.sh` 50/50; `bin/desktop/tests/test_launcher_worktree_guard.sh` 8/8. The
WSL and macOS roads are written and not yet proved on a real machine.

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: a dev machine. The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).
