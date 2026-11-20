## runtime · unversioned · 2026-09-12 — The dashboards stop crash-looping on the iGPU

### Why
- **`scripts/electron.sh` decides its own GPU path.** Both dashboards appeared to
  work while `coredumpctl` filled with SIGSEGV cores from
  `electron --type=gpu-process`. An iGPU backs its graphics memory with system
  RAM (GTT), a local model served on that same iGPU held 5.8-8.0 GiB of it, and
  the amdgpu driver then failed the desktop's command submissions — which
  Electron turned into a NULL dereference at a constant offset. Only the GPU
  process died, so the windows stayed up and the failure was easy to miss.
  `igpu_vram_small()` now reads the render device's VRAM carve-out and switches
  to software rendering under `YMIR_IGPU_VRAM_SMALL_MIB` (default 2048). The old
  comment promised this auto-detect; now it exists. `YMIR_DESKTOP_DISABLE_GPU`
  still overrides, both ways.
- **Verified:** with the fix, the amdgpu submission errors stop and the
  gpu-process runs SwiftShader (`--use-angle=swiftshader-webgl`) rather than the
  hardware path; no new cores.

### Files
- *(carried from the frozen CHANGELOG.md)*
