# Yolo is real: the worker's permission posture follows the home's setting

**Date:** 2026-11-21 · **Component:** seat · **Doors:** `src/ymir_runtime/role_config.py`, `src/ymir_runtime/harness.py`,
`src/ymir_runtime/claude_seat.py`, `src/ymir_runtime/seat.py`, `src/ymir_runtime/__main__.py`, `bin/agents/einherjar-spawn.sh`
· **Tests:** `src/ymir_runtime/tests/test_role_config.py`, `bin/agents/tests/test_judge_coder_kit.sh`

## What was wrong

`--yolo on|off` was only written into the errand's record. A Claude worker always ran in `dontAsk` (the engine road) or
`acceptEdits` (the shell road), so a tool outside the allow list was silently denied or stopped at a dialog nobody answers.
That is how `git merge` was refused three times on 2026-11-21.

## What changed

- `yolo on` launches Claude with `--permission-mode bypassPermissions`; `off` with `dontAsk`. Both roads use the one
  table, `role_config.claude_permission_mode`, and the merged settings carry the same `defaultMode`.
- **Every deny rule in the profile still holds in bypass mode.** Proven live: a seat launched with the coder profile in
  `bypassPermissions` ran `echo` with no prompt and was refused `gh pr merge --help`. The unit test asserts the deny list
  is identical in both modes for the coder and the judge profile.
- Pi and opencode already run allow-all, so their posture is reported, not tightened.
- The default comes from the home: the role's `yolo:` (a machine file over the fleet file), then `yolo: {default: …}`,
  then the house default (on for the coder, off for the rest). `--yolo` on the command wins.
- `einherjar-spawn.sh` prints one `posture …` line saying which posture took effect and where it came from.
