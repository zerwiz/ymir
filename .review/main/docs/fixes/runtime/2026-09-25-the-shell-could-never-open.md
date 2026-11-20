## runtime · unversioned · 2026-09-25 — the shell that could never open: two defects, each hiding the other

### Why
The Allfather asked for the desktop window back, and said he had been running the
UI before. It had never opened, and two faults were stacked in one file.

- **The mend was handed an empty path.** `scripts/electron.sh` called
  `$(app_dir hlidskjalf)`, but `app-lib`'s `app_dir` takes an OUT-PARAMETER
  (`app_dir <name> <var>`) and prints NOTHING. The printing version existed only
  at line 257, BELOW the mend check at line 234. So `electron_bin` received an
  empty app dir and refused it, and `ensure_electron_binary` declared a runtime
  that was present entirely unmendable. The trace named it plainly:
  `+ electron_bin '' /home/craigema/dev/Way-Of/ymir hlidskjalf`. One `app_dir`
  printer now stands above its first caller, and it is defined nowhere else.
- **The mend clobbered its own cure.** The proven zip road ran FIRST, then
  `npm rebuild electron` re-ran the gated postinstall, emptied `dist/`, and the
  launcher refused a runtime the zip road had already placed. The npm roads now
  run first and the zip road runs LAST, as the last word. `npm install-scripts
  approve electron` answers "Nothing to approve; allowScripts unchanged", so the
  npm gate is not the cause here; the ORDER was.
- **The runtime itself was never the fault:** the fetched binary answers
  `v33.4.11`, with no missing shared libraries. Absence was never the problem;
  an empty argument was.
- **Proved:** `electron[1]{view,state,pid,url}:` reports
  `"hlidskjalf","up",3992973,"http://127.0.0.1:3888/"`, with the host SPA raised
  on :3888 to back it. The log shows only a GL vsync warning, which is harmless.
- **One defect named, not fixed:** `view_host` hardcodes `:3888` / `:8437` /
  `:4322` instead of resolving the port from the env the runtime already writes
  (`~/.config/ymir/ymir.env`), which is a Rule 07 smell. The `smidja` view stays
  down until something serves `:8437` on the host.

galdr-reread: `hlidskjalf-ui.md` (the desktop door).

### Files
- `scripts/electron.sh`
