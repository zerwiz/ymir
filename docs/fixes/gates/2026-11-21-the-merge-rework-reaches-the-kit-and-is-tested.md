# gates · 2026-11-21 — the merge rework reaches the kit and is tested

This follows the fix note `2026-11-21-a-worker-may-merge-main-and-the-maker-ward-skips-main.md`. The judge's review of #875 found three gaps in it.

## What was wrong

- The kit's copy of the maker ward, `bin/collab/kit/scripts/gates/maker-guard.sh`, still used the old push range. `bin/gates/tests/test_maker_names.sh` failed because the two copies differed.
- The worker profile's `$comment` still said `git merge` was denied. It had also been written with escaped dashes (`—`).
- No test covered either change.

## What changed

- The kit copy of the ward is the house copy again, byte for byte.
- The `$comment` now has a correction saying `git merge` is allowed for bringing a branch current. Every road that merges a PR stays denied. The file is written with its own dashes.
- `src/ymir_runtime/tests/test_claude_seat.py` checks that a worker may use `git merge`, that the PR-merge roads stay denied, and that the file has no escapes.
- `bin/gates/tests/test_maker_names.sh` pushes a branch that merged main. Both copies of the ward must pass it, and a later commit on the branch that names a harness must still be refused.

## Not in this change

- `bin/collab/kit/scripts/gates/maker-allow.txt` differs from `bin/gates/maker-allow.txt` on main already. The house file carries the house's own commit allowances. That drift is older than #875 and still fails one row of the test.

## Files

- `bin/collab/kit/scripts/gates/maker-guard.sh`
- `.agents/harnesses/claude-worker.settings.json`
- `src/ymir_runtime/tests/test_claude_seat.py`
- `bin/gates/tests/test_maker_names.sh`
