# runtime · 2026-09-24 — the launcher's mend has no top-level `local`

## Why
The mend road added in the desktop-runtime guarantee (PR #176) declared
`local mend_pkg` / `local _edir` (and the first-run block `local _installd`)
at **script top level**, where bash refuses `local` — `local: can only be used
in a function`. Every launcher invocation printed those errors before its
mend, and the mending muddled its way on regardless (slower, noisier — and an
app-local probe error could echo into the window log).

## What
- `scripts/electron.sh`: the three top-level declarations are now plain
  assignments (`mend_pkg`, `_edir`, `_installd`) — names are mend-scoped by
  position, with a comment citing the law so the mistake is not rebuilt.
- Function-scoped `local`s (view_pids, start_one, ensure_electron_binary, …)
  are untouched.

## Verified
- `bash -n scripts/electron.sh` clean; no top-level `local` remains; a real
  launcher run no longer prints the `local` errors.

## Files
- `scripts/electron.sh`