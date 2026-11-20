# YGGDRASIL Git Worktree Manager (Isolation)

Branch isolation for zero-collision parallel editing across Ymir.

## Worktree Locations
Created dynamically as `.yggdrasil/<agent-id>/` inside the target repository.

## Intended Skills
- `yggdrasil.ts` — core worktree CLI harness
- `yggdrasil_manager.ts` — worktree creation, sync, merge & cleanup