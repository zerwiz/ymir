## runtime · unversioned · 2026-09-23 — the Óðrerir door exists (the window can open)

### Why
- **Problem (Allfather):** *"odrerir don't start."* The Óðrerir launcher entry runs
  **`ymir odrerir`**, but `bin/ymir.js` had **no `odrerir` door** — the CLI knew
  `hlidskjalf` and `sessrumnir` and fell through to usage for `odrerir`, so the
  Electron window never opened. `scripts/electron.sh` already supports the view
  (`VIEWS=(hlidskjalf smidja odrerir)`, `pid_file`/`log_file`/`view_mark` all
  handle it); only the CLI door was missing.
- **Fix:** add the door —
  ```js
  odrerir: { script: 'scripts/electron.sh', about: "the live hall's window", args: ['start', '--view', 'odrerir'] },
  ```
  and list it in the CLI's header comment beside the other windows.

### Verified
- `node --check bin/ymir.js` clean; `ymir --help` now lists **odrerir** among the
  doors (Electron is not launched by the check itself).

### Files
- `bin/ymir.js`
