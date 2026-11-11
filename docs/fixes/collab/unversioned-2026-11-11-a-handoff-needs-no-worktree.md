# A handoff needs no worktree; only a code change does

**Date:** 2026-11-11 · **Component:** collab · **Asked by:** the Allfather — *"update the logic in the collab kit.
only handoffs don't need a new worktree. only code changes need a new worktree."*

## What was wrong

Kit RULES/17 sent every change through a worktree and a pull request, and the kit's `pre-push` refused every push to
`main`/`master`. A baton written at the end of a session therefore waited behind a pull request for the operator's
merge, and the next hand read the old one. In the Growth Agent repository on 2026-11-11, the baton to the next
developer had to be pushed past the hook by hand.

## What changed

| File | Change |
|---|---|
| `bin/collab/kit/RULES/17-one-agent-one-worktree.md` | an appended, dated section: code needs a worktree and a PR; a push carrying only `handoff/` goes straight to the default branch |
| `bin/collab/kit/.githooks/pre-push` | `handoff_only` — a push to `main`/`master` whose every changed file is under `handoff/` skips the pr-guard and the protected-branch refusal, and says so; anything else is refused as before; the checks still run |
| `bin/collab/tests/test_collab.sh` | section 9: a handoff-only push to `main` passes the hook, a push with code beside the baton is refused |

## Proof

`bash bin/collab/tests/test_collab.sh` — section 9 passes (both cases).

## CHANGE LOG

- **2026-11-11** — Written.
