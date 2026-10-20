## hlidskjalf · unversioned · 2026-10-20 — Skrymir browses the right shelf

### What

The Files gate was missing the project trees and therefore every meeting folder. Two
causes:

1. **Wrong shelf.** `workspaceRoot('work')` resolved the workspace's `company`
   (`whynotproductions`) before the realm's own tree, so Skrymir browsed
   `svartalfaheim/whynotproductions` while the work projects (and Synteon's meetings)
   live under `svartalfaheim/work/projects`. The realm tree is now preferred; the
   company mapping is a display owner, not the shelf.
2. **Too shallow.** The walk stopped at depth 3; a meeting sits at depth 5
   (`projects/<project>/meetings/<meeting>`). Depth is now `SKRYMIR_MAX_DEPTH`
   (default 6).

### Verified

- `/api/files?realm=work` now returns `projects/synteon technologies/meetings/2026-10-20-roadmap`.
- API re-raised on `:3889`.

### Not verified

- No UI click-through; no symlink-loop guard beyond the depth cap.
