# YGGDRASIL Git Worktree Manager (Isolation)

Branch isolation for zero-collision parallel editing across Ymir.

## Worktree Locations
Created dynamically as `.yggdrasil/<agent-id>/` inside the target repository.

## Intended Skills
- `yggdrasil.ts` — core worktree CLI harness
- `yggdrasil_manager.ts` — worktree creation, sync, merge & cleanup

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
