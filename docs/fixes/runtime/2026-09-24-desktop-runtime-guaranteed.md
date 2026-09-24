## runtime · unversioned · 2026-09-24 — the desktop runtime is guaranteed, not assumed

### Why
Three silent failures made the installation guarantee nothing on heimdall:

1. **The install was broken by its own workspace declaration.** `package.json`
   declares `workspaces: [apps/hlidskjalf, apps/odrerir, apps/sessrumnir,
   apps/smidja-factory]`, so npm HOISTS each app's electron to the **ymir root**
   (`ymir/node_modules/electron`). Every runtime probe looked only at the app
   dir — `scripts/electron.sh` `real_electron()` →
   `$APP/node_modules/electron/dist/electron`, `ensure_electron_binary()` →
   the same, `bin/electron-lib.sh` `electron_runtime_state()` →
   `$dir/node_modules/electron` — a path npm will never create. Observed in
   `state/electron.log`: `env: '<pkg>/apps/hlidskjalf/node_modules/electron/
   dist/electron': No such file or directory`.
2. **The guard was inverted.** `ensure_electron_binary()` held
   `[ -d "$APP/node_modules/electron" ] || return 0` — SUCCESS when the runtime
   was absent — so the mend was skipped and the launcher proceeded into the
   path that never existed. Absence was success; nothing was told.
3. **The launcher deleted its own cure.** First run ran `npm install` INSIDE
   the app dir; being a workspace member, npm reconciled the tree and REMOVED
   the app-local `node_modules` the probes looked at.

The crash that exposed it: Hlidskjalf's Electron GPU process aborted (SIGABRT,
`si_code SI_TKILL`) with `abort ← libgallium ← dri_create_fence_fd ←
libEGL_mesa ← EGL_CreateSyncKHR`, prefixed by
`gbm_pixmap_wayland.cc: Cannot create bo ... SCANOUT` and
`intel: the execbuf ioctl keeps returning ENOMEM` — 108 GiB RAM free, no OOM,
so GPU-side buffer/fence failure on the i915 GPU process. The only GPU gate,
`igpu_vram_small()`, read `mem_info_vram_total` — **not exposed by i915** — so
on this Intel+discrete hybrid the guard never fired.

### What
- **The one resolver** — `bin/electron-lib.sh`: `electron_bin`,
  `electron_pkg_dir`, `electron_place_dir`, `electron_runtime_state`,
  `electron_fetch_runtime`, `fetch_electron_zip` now search every shape npm
  leaves behind, in order: app-local, the nearest ancestor hoist (walking up,
  halting at a foreign ymir root), then the sibling package. No caller
  hardcodes an app-local electron path.
- **Truth-telling guards (P2)** — `ensure_electron_binary` (scripts/electron.sh,
  bin/sessrumnir-ensure.sh) returns failure unless the resolver yields an
  executable that answers `--version`. The absent branch's `return 0` is gone;
  the guard shape is proven by `.agents/tests/electron-lib.test.sh`.
- **The first-run install never deletes the runtime (P3)** — installs at the
  workspace root when the app is a member, app-local only for a standalone app
  (`electron_is_workspace_member`), and fetches land in the resolved dir.
- **The GPU guard sees Intel (P7)** — `bin/graphics-lib.sh` classifies DRM
  cards (integrated/discrete/hybrid), reads GTT where exposed, and decides the
  effective policy: software rendering on a fragile hybrid unless
  `YMIR_DESKTOP_DISABLE_GPU` overrides. `igpu_vram_small` and the launcher's
  auto path both read that one policy.

### Verified
- `.agents/tests/electron-lib.test.sh`: app-local, workspace-hoisted, and
  sibling shapes each resolved; absence reports `absent`/failure; a gated
  postinstall reports `partial`; member placement lands at the root hoist.
- On heimdall, `graphics_block` reports `renderD128 = nvidia`,
  `renderD129 = i915`, classification `hybrid`, policy `software`, display
  `card2` (i915 drives fb0).

### Files
- `bin/electron-lib.sh` · `bin/graphics-lib.sh` (new) · `scripts/electron.sh`
- `bin/sessrumnir.sh` · `bin/sessrumnir-ensure.sh` · `.agents/tests/electron-lib.test.sh`