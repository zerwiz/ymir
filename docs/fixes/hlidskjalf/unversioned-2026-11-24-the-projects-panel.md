## hlidskjalf · unversioned · 2026-11-24 — the Worktrees tab becomes Projects (plan 367)

### Why

The panel showed one row, the runtime release, while the user works across many repositories. Collaboration-kit repos
reported nothing back.

### What changed

- **`bin/records/projects-status.sh`** (new, `projects_status.py`): one resolver joining the registry, this machine's
  clones, worktrees, the claims shelf, PRs and CI (`gh`, cached a minute) and the kit. This machine answers; `--fleet`
  fetches other seats itself and names each source seat.
- **`bin/records/projects.sh`** and the `ymir projects` door: `add`, `kit update`, `reap` (dry run unless `--apply`).
- **`bin/collab/standardise.py`**: `--report [--house]` writes `report{}` into `.collab-kit.json`; a later apply keeps it.
- **Hliðskjálf**: `/api/projects` (`?fleet=1`, `?view=shared`) and the Projects panel with filters and a worktree
  drill-down. The nav id stays `worktrees`.
- **`tests/test_projects_status.sh`**: 26 checks on fixtures.

### Decisions (the Allfather, 2026-11-24)

Default view is this machine's clones; other seats are opt-in. A repo reports only when seated with `--report`, to the
house that seated it only. The file stays `.collab-kit.json` (it already existed), not the plan's `.ymir-kit.json`.

### Not done

Kit update is run on this machine only; a remote seat's kit is shown, not changed.
