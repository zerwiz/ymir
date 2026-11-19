## apps · 2026-11-19 — every app gets its own home, and one door installs and updates it

### Why
The Allfather, 2026-11-18: *"we need installation and update logic for all apps"* and *"i dont wanna them come into the apps folder anymore if installed they need their own places."* Until now an app lived only in Ymir's `apps/` and was built inside every Ymir release; there was no way to install one alone, update one alone, or roll one back. This is Slice 0 of the split (plan 01): it moves no app, and every app keeps running exactly as before (every road `legacy`).

### What was built
- **The apps home** — `${YMIR_APPS_HOME:-${XDG_DATA_HOME:-~/.local/share}/ymir-apps}/<app>/` with `repo/`, `releases/<sha>/`, `current`, `previous`. State and config stay in the XDG dirs, never in a release.
- **The resolver** — `bin/apps/app-path.sh <app>` (and `--list` / `--check`): `dev` (`YMIR_APP_<NAME>_DIR`) → `home` → `legacy` (`apps/<dir>`) → `missing`. `bin/desktop/app-lib.sh`'s `app_dir` takes `dev` and `home` from it first, so every desktop script follows an app into its home with no change of its own.
- **The door** — `bin/apps/apps.sh list|install|update|check|rollback|remove|home` (logic in `apps.py`, stdlib). The release mechanics live here once: export the commit into `releases/<sha>`, the app's `install.sh` builds in place (or its `update.sh`), `install.sh --check`, flip `current` only on green, keep three, `rollback`. In a call it builds and waits to flip (desk law). An apps home inside Ymir's `apps/` or the pin's is refused.
- **The registry** — `config/app-repos.yaml` names all seven apps plus the archived phone app, each with `home:`, `kind:` and `contract:` (`0` = still in Ymir's tree).
- **The contract** — `.agents/templates/app-contract/`: `app.yaml`, `install.sh` (with `--check`), `start.sh`, `stop.sh`, `uninstall.sh`, README.
- **Gróa** runs `apps.sh update --all` after Ymir's own update (a red app never fails Ymir's); **Eir** has an `apps` surface (`apps.sh check`, mended by `apps.sh install --all`).
- **Rules appended** (not rewritten): RULES/11 (an app leaving with its history is a move), RULES/23 (the registry; `apps/` is the legacy road), RULES/29 (the guard follows the app to its home; a red release never flips), RULES/05 (an app's platform layers travel with it).

### Proof
- `bin/apps/tests/test_apps.py` — 10 tests on a throwaway app repo, fenced (apps home, registry, state, config, desk door in a temp dir): install builds, checks and flips; update flips and keeps `previous`; rollback; a red build and a red `--check` never flip; in a call it builds and waits, then flips when the call ends; prune keeps three; state survives `remove`; `remove` needs `--yes`; an apps home inside `apps/` is refused; the real registry installs nothing while every app is legacy, and `apps/` is untouched.
- `bin/apps/app-path.sh --check` on heimdall: all seven apps `legacy`, the phone app left out as archived.
- `bin/agents/tests/test_eir_register.sh` — 19 passed.

### Not yet
Each app's own slice writes its `install.sh` and flips its `contract:` to `1`; until then `apps.sh` reports it as legacy and installs nothing. `release.sh` still builds the in-tree apps for the same reason, and stops for each app in that app's slice.
