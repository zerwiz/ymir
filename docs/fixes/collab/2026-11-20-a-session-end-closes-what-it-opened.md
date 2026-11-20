# Session end closes what a session opened; hooks seat per checkout; the kit passes a product's own laws

**2026-11-20 · component: collab**

## What was wrong

1. **A session ended and its work stayed.** Worktrees, servers, test databases and development stacks outlived the
   session that made them. The operator: *"at handoffs and ends of sessions we need to clean up the sessions we have
   coded on."*
2. **Seating the hooks still changed every checkout.** `core.hooksPath` in the shared config moves the hooks of the
   main clone and every worktree, including branches with no `.githooks/` — whose hooks then silently stop.
3. **The installed kit failed a product repository's own gates**: documents without a diagram or a table, a direct
   process signal outside that repository's platform helper, and one shared guard naming its maintainers' settings
   and a home cache path.

## What was forged

| Change | Where |
|---|---|
| `work.sh session-end [--session S \| --agent A \| --all]` — stop each worktree the session opened, remove what is safe on the remote, salvage what the checks refuse, clear scratch, dev stack off when no other worktree of the app is open, one paragraph in `.git/kit-handoffs/` | `scripts/kitlib/work.py`, `scripts/kit.py` |
| `work.sh start` records the session id (`KIT_SESSION` or the harness's) and the agent | `scripts/kitlib/work.py` |
| `.claude/settings.json` gains a `SessionEnd` hook beside existing ones; Hermes and OpenCode hooks documented with sources | `standardise.py`, `kit/docs/harness-hooks.md` |
| hooks are seated in **this checkout's** config (`extensions.worktreeConfig`); the shared setting is untouched; new worktrees get them too | `scripts/kitlib/hooks.py`, `worktrees.py` |
| process stopping lives in one platform module, through kill(1) | `scripts/kitlib/platform.py` |
| every kit document carries a diagram and a table | `kit/RULES`, `kit/docs`, the workbench skill, the tickets shelf |
| the shared maker matcher is rendered on install with the kit's own setting names | `standardise.py` `INSTALL_RENDER` |
| `project.yaml` `install.skip` — a piece that does not fit a repository is not installed | `standardise.py`, the monorepo profile |
| `link_mode: reflink` — a copy-on-write copy of a dependency folder, for tools that refuse a link leaving the project root (Next.js Turbopack refused `web/node_modules`); falls back to a symlink where the filesystem cannot reflink | `scripts/kitlib/worktrees.py`, the monorepo profile |
| `deploy.sh --dry-run` reports the disk floor instead of stopping before the plan | `scripts/kitlib/deploy.py` |

## What was run

```
python3 bin/collab/tests/test_work.py   → Ran 13 tests … OK (a session with two worktrees ends with both handled,
                                          another session's worktree untouched, and the dev stack off)
python3 bin/collab/tests/test_kit.py    → Ran 40 tests … OK (the shared hooksPath is not taken)
bash bin/collab/tests/test_collab.sh    → 28 passed, 0 failed
```

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #841
