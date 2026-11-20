## sessrumnir · 2026-09-24 — the seat-hall obeys the machine's graphics policy

### Why
Sessrúmnir (Electron 43.7.3) kept dying with SIGTRAP (`int3`, `si_code: SI_KERNEL`) —
coredumps PID 2755410 (2026-09-23) and PID 2135559 (2026-09-24). A coredump walk
resolved, via breakpad symbols, to Chromium's deliberate suicide for an unusable
GPU process: `GpuProcessHost::OnProcessLaunchFailed` →
`FallBackToNextGpuMode` → `IntentionallyCrashBrowserForUnusableGpuProcess` →
`LOG(FATAL)`. Not OOM (102 GiB free), no driver error at crash time.

The `2026-09-24` GPU-safety fix (P7) landed for `scripts/electron.sh`
(hlidskjalf / smidja / odrerir) but **never reached sessrumnir's launcher**: it
spawned `electron --no-sandbox <app>` with no GPU flags, so on this fragile
hybrid (a shared-memory iGPU beside the RTX A5000, `graphics_policy=software`)
its GPU process walked the real-hardware path, died for want of the software
renderer, and Chromium committed suicide. The launcher held an old comment —
"--disable-gpu is intentionally NOT passed" — which was the hole.

### What
The DECISION lives in the launcher, never a hardcode (P7):

- `bin/sessrumnir.sh` sources `bin/graphics-lib.sh`, resolves the ONE machine
  policy exactly as `scripts/electron.sh` does (human override
  `YMIR_DESKTOP_DISABLE_GPU` = 1/0/auto), and exports the EFFECTIVE override.
- `apps/sessrumnir/bin/sessrumnir.js` reads that override and appends
  `--disable-gpu --disable-gpu-compositing` when software.
- The box's install also mirrors this into the npm copy + realigns the desktop
  entry to the repo launcher (machine property; not in this change).

### Verified
- `bash ~/ymir/bin/sessrumnir.sh start` → electron runs with
  `--no-sandbox --disable-gpu --disable-gpu-compositing`; the GPU process starts
  as `--use-gl=disabled`; process family stable, no suicide.
- `bash -n` clean on `bin/sessrumnir.sh`; `node --check` clean on the app launcher.
- `graphics_policy` → `software` → effective override `1` confirmed on heimdall.

### Files
- `bin/sessrumnir.sh`
- `apps/sessrumnir/bin/sessrumnir.js`
- this note (same commit — a note travels WITH its change)