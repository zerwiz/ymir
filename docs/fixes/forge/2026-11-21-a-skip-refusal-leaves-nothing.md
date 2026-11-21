# forge · 2026-11-21 — a skip refusal leaves nothing behind

## Files

- `bin/forge/yggdrasil.sh` — the "would still be checked out" refusal removes the worktree and branch; usage stops at the exit line
- `bin/forge/tests/test_yggdrasil_slim.sh` — proves both
- `bin/gates/checks.d/0550-yggdrasil-slim.sh` — runs the test as the gate `yggdrasil-slim`
- `bin/room/gladsheim-ensure.sh` — the engine also carries `project=gladsheim`
- `docs/fixes/fleet/2026-11-20-the-room-engine-carries-its-owner.md` — cites the real rule and reader

## Why

The review of pull request #873 found four faults in the slimmer worktree and the room engine label:

1. `yggdrasil.sh --help` printed `set -u` under the usage, because its range ran one line too far.
2. The slim test ran nowhere: no gate named it.
3. The room engine's fix note cited a kit `RULES/21` and an `ymir.owner` reader. Neither exists.
4. `--skip README` (a file, which sparse-checkout cannot leave out) refused with exit 1 and left the
   worktree and the branch behind. The other refusals clean up.

## Fix

- The usage range is `2,30`, which ends at the `Exit:` line.
- A `--skip` of something that is still checked out removes the worktree and branch, then refuses.
- The test covers both, and `checks.d/0550-yggdrasil-slim.sh` runs it with the gates.
- The engine is labelled `project=gladsheim` as well as `ymir.owner=gladsheim`. The kit's container rule
  is `bin/collab/kit/RULES/23-containers-build-here-run-there.md`, and its reader,
  `bin/collab/kit/scripts/kitlib/containers.py`, filters on `label=project=<project>`.
  `bin/records/running-inventory.sh` reads only compose projects, and the note now says so.

## CHANGE LOG

- 2026-11-21 — added with the rework of #873.
