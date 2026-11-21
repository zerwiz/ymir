# The judge's seat opens the merge door, and only the door

**Date:** 2026-11-21 · **Component:** seat · **Doors:** `.agents/harnesses/claude-judge.settings.json` (new),
`.agents/harnesses/claude-worker.settings.json`, `src/ymir_runtime/claude_seat.py`, `src/ymir_runtime/harness.py`,
`bin/seat/claude-seat.sh`, `bin/seat/herdr-run.sh`, `bin/agents/einherjar-spawn.sh`, `bin/agents/eindri-review-spawn.sh`,
`.agents/assets/templates/review-brief.template.md`, `bin/agents/pr-seal.sh`, `bin/forge/smith-bin/gh` · **Tests:** `tests/test_claude_seat_roles.sh`,
`src/ymir_runtime/tests/test_claude_seat.py`, `bin/forge/tests/test_judge_merge.sh`

## What was wrong

RULES/08 was amended on 2026-11-21: every PR is reviewed by the judge, and an approval merges at once. Measured that night
on the dev machine, three judges (figure `forseti`) approved PRs and were refused at the merge. Every Claude seat was
launched with the one worker profile, which denies `Bash(gh pr merge:*)` for every worker, the judge included. The arm
holder had to merge by hand.

## What changed

- **The profile is chosen by role.** `claude_seat.profile_for(tree, role)` is the one table: role `forseti` gets
  `claude-judge.settings.json`, every other role (and no role) gets `claude-worker.settings.json`. The role is the
  argument only (see the rework below). A judge whose profile is missing is refused, never quietly seated as a worker.
- **The judge's profile opens exactly one road.** It allows `bin/forge/judge-merge.sh` and `bin/agents/pr-seal.sh seal`
  (the door built by errand judge-merges, #863, which re-checks checks, mergeability, draft, hold label, `.seal-hold`
  and the approved head at the moment of the merge). It still denies raw `gh pr merge`, the raw merge API
  (`gh api …/merge`), `git merge` and every push to main, so the door's checks cannot be skipped.
- **The worker profile refuses every merge road.** Besides raw merge it now also denies the door and the raw merge API.
- **Wiring.** `claude-seat.sh settings|args` take an optional role, and `claude-seat.sh profile [role]` prints the
  path. `herdr-run.sh` passes `$ROLE`. `einherjar-spawn.sh` takes `--role <figure>`, records `role=` in the task record,
  keeps it on `--relaunch`, and never inherits or exports a role. `harness.py` reads the same table. `eindri-review-spawn.sh`
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

## The rework after the judge's first review

The judge returned NEEDS-REWORK on the first head with three items, and all three were real.

1. **A guessed role opened the door to a coder.** `herdr-run.sh` fills an empty role from
   `eindri-role.sh choose`, and words like "check", "ship" and "pr" map to `forseti`. A coder's brief such as "fix the
   broken gate check and ship the PR" was therefore seated with the judge's profile. Now only an explicit `--role`
   (`ROLE_EXPLICIT`) reaches `claude-seat.sh`; the guess still picks the pi role file and nothing else. For the same
   reason the role is never read from the environment (`YMIR_SEAT_ROLE`) and `einherjar-spawn.sh` no longer exports
   it, so a spawn made inside a judge's seat cannot seat its child as the judge.
2. **The door was refused inside the judge's own seat.** The judge is seated like any worker: `YMIR_SMITH` set,
   `bin/forge/smith-bin` first on `PATH`, the cwd under `.yggdrasil/`. The smith shim refuses `pr merge` there, so the
   door's merge failed at its last step. `pr-seal.sh seal_judged` now resolves the real `gh` past any tree's shim
   (`door_gh`); the door's own checks are the guard on that road.
3. **Raw merge slipped the deny list.** `gh -R <repo> pr merge` and the GraphQL `mergePullRequest` / `mergeBranch`
   mutations matched no pattern. Both profiles now deny them, and the shim reads past `-R` / `--repo` before it reads
   the subcommand and refuses the merge API (REST `…/pulls/<n>/merge` and the GraphQL mutations).

The two PRs land as one batch: this branch carries #863.

Proof after the rework: `bash tests/test_claude_seat_roles.sh` gives `27 passed, 0 failed`, and
`bash bin/forge/tests/test_judge_merge.sh` gives `36 passed, 0 failed`. Its new seat case fails on the old
`pr-seal.sh` (`35 passed, 1 failed`) and passes on the new one. A real judge seat refuses
`gh -R zerwiz/ymir pr merge --help` and the GraphQL mutation, and still runs `bin/forge/judge-merge.sh --help`.

## CHANGE LOG

- 2026-11-21 — filed with the errand `judge-permissions`.
- 2026-11-21 — appended the rework after the judge's first review (#870: guessed role, the shim, raw merge forms).
