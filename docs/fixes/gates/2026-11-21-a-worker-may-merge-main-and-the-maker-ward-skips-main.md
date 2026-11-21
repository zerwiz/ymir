# gates · 2026-11-21 — a worker may merge main into its branch, and the maker ward skips commits already on main

## What was wrong

- `.agents/harnesses/claude-worker.settings.json` denied `Bash(git merge:*)`. That rule was meant to stop a worker from merging a pull request, but it also stopped the ordinary `git merge origin/main` a worker needs to bring its own branch current. Errand rework-864c was refused three times and could not resolve PR #864's conflict.
- `bin/gates/guards/maker-guard.sh push` ranged `rsha..lsha` for an existing remote branch. After a merge of main, that range included commits already on main, so the ward refused the push over two of main's own commit messages (c83b13d97, ea5c13118).

## What changed

- The worker profile no longer denies `git merge`. Every road that merges a PR on GitHub stays denied: `gh pr merge` in all its spellings, the REST and GraphQL merge calls, and `judge-merge.sh`.
- The maker ward ranges `rsha..lsha --not origin/main`, so it judges only the commits the push really adds.

## Files

- `.agents/harnesses/claude-worker.settings.json`
- `bin/gates/guards/maker-guard.sh`
