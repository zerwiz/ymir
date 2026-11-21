## gate · 2026-11-21 — an apps note covers the app registry

### Why

The judge on PR #871 cited the fixes-guard line *"none names a path this range touched"*. The PR changed
`.agents/config/app-repos.yaml` and carried a note under `docs/fixes/apps/`. The note was the right record, but the
guard could not tell, because `path_component()` in `bin/gates/guards/fixes-guard.sh` had no row for the app registry.
A correct `apps` note therefore covered nothing. Correcting the path in the note's prose could not fix that.

### What changed

- `path_component()` maps `.agents/config/app-repos.yaml` and `bin/apps/*` to the `apps` component. This is the same
  kind of row the forge, ward and vault rows added.
- `bin/gates/tests/test_fixes_regate.sh` gains case 4: an `apps` note in a range that changes the registry is reported
  as speaking to the change.

### Files

- `bin/gates/guards/fixes-guard.sh`
- `bin/gates/tests/test_fixes_regate.sh`
- this note

## CHANGE LOG

- 2026-11-21 — first entry.
