# The judge's seat opens the merge door, and only the door

**Date:** 2026-11-21 · **Component:** seat · **Doors:** `.agents/harnesses/claude-judge.settings.json` (new),
`.agents/harnesses/claude-worker.settings.json`, `src/ymir_runtime/claude_seat.py`, `src/ymir_runtime/harness.py`,
`bin/seat/claude-seat.sh`, `bin/seat/herdr-run.sh`, `bin/agents/einherjar-spawn.sh`, `bin/agents/eindri-review-spawn.sh`,
`.agents/assets/templates/review-brief.template.md` · **Tests:** `tests/test_claude_seat_roles.sh`,
`src/ymir_runtime/tests/test_claude_seat.py`

## What was wrong

RULES/08 was amended on 2026-11-21: every PR is reviewed by the judge, and an approval merges at once. Measured that night
on the dev machine, three judges (figure `forseti`) approved PRs and were refused at the merge. Every Claude seat was
launched with the one worker profile, which denies `Bash(gh pr merge:*)` for every worker, the judge included. The arm
holder had to merge by hand.

## What changed

- **The profile is chosen by role.** `claude_seat.profile_for(tree, role)` is the one table: role `forseti` gets
  `claude-judge.settings.json`, every other role (and no role) gets `claude-worker.settings.json`. The role is the
  argument, else `YMIR_SEAT_ROLE`. A judge whose profile is missing is refused, never quietly seated as a worker.
- **The judge's profile opens exactly one road.** It allows `bin/forge/judge-merge.sh` and `bin/agents/pr-seal.sh seal`
  (the door built by errand judge-merges, #863, which re-checks checks, mergeability, draft, hold label, `.seal-hold`
  and the approved head at the moment of the merge). It still denies raw `gh pr merge`, the raw merge API
  (`gh api …/merge`), `git merge` and every push to main, so the door's checks cannot be skipped.
- **The worker profile refuses every merge road.** Besides raw merge it now also denies the door and the raw merge API.
- **Wiring.** `claude-seat.sh settings|args` take an optional role, and `claude-seat.sh profile [role]` prints the
  path. `herdr-run.sh` passes `$ROLE`. `einherjar-spawn.sh` takes `--role <figure>`, records `role=` in the task record,
  keeps it on `--relaunch` and exports `YMIR_SEAT_ROLE`. `harness.py` reads the same table. `eindri-review-spawn.sh`
  seats the judge with `--role forseti`.
- **The review brief teaches the door.** It says raw merge is refused, the terminal act runs
  `bin/forge/judge-merge.sh act <review-id>`, and the judge runs it once by hand only if the act could not.

## Proof

- `bash tests/test_claude_seat_roles.sh`: `23 passed, 0 failed` on this branch. With #863 merged into a scratch tree:
  `24 passed, 0 failed`, including the door's own suite (`judge-merge: 34 passed, 0 failed`: red, pending, moved head
  and hold never merge).
- `python3 -m unittest ymir_runtime.tests.test_claude_seat ymir_runtime.tests.test_harness`: 42 tests, OK.
- Real Claude Code in `dontAsk`, one call per row on the scratch tree: judge profile runs
  `bin/forge/judge-merge.sh --help` and is refused `gh pr merge --help`. Worker profile is refused
  `bin/forge/judge-merge.sh --help`, `bin/agents/pr-seal.sh seal --help` and `gh pr merge --help`.

## CHANGE LOG

- 2026-11-21 — filed with the errand `judge-permissions`.
