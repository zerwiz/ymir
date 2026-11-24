# A commit weaves only when it touches what the registers read

**Component:** gates (plan 369, item 9) · the pre-commit hook

## What was wrong

A commit took 8 to 15 minutes on the dev machine. The pre-commit hook ran `bin/records/weave.sh` on
every commit, and that rebuilds the inventory (`bin/gates/inventory.sh`, 115 s measured) and the
capabilities register (`bin/gates/capabilities.sh`, 295 s measured) from the whole tree. A fix note, a
doc or the body of one script paid the same price as a new door. Two commits in parallel took longer.

## What changed

- `bin/records/weave-needed.sh` is new. It reads the staged name-status list and says whether anything
  a register is built from is staged:
  - a door added, deleted, renamed or copied under `bin/`, `src/ymir_runtime/`,
    `.pi/shared/extensions/`, `.agents/skills/` or `.agents/tests/`;
  - a door's header (lines 1 to 12, where "the job" is read);
  - anything that names or tests a door (`AGENTS.md`, a skill page, any `tests/` file);
  - a register's own input or writer.
- `.githooks/pre-commit` asks it first. It weaves only on a yes and prints the one-line reason either
  way. `YMIR_WEAVE=1` forces a weave and `YMIR_SKIP_WEAVE=1` skips one.
- The weave ward and CI still judge drift, so a skip is never a pass.

## Proof

- `bin/records/tests/test_weave_needed.sh`: 15 passed, 0 failed.
- On a staged edit at line 200 of `bin/voice/rodd-helm.sh` it says no. At line 3 it says yes.

## Owed

A seat whose `<git-dir>/hooks/pre-commit` is a copy, not `core.hooksPath .githooks`, keeps the old
hook until the install step `gates` seats it again. The release clone on the dev machine is one such seat.

## CHANGE LOG

- 2026-11-24 — review-mend: added missing heading for #938
