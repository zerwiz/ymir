# The engine launched OpenCode in the dead shape

**Date:** 2026-11-12 · **Component:** harness · **Rule:** 13 (one shape, one door)

## The fault

Every OpenCode seat the engine started died in its pane. `src/ymir_runtime/harness.py` still built the v1
shape, `opencode --model M --prompt "…"`, and OpenCode v2.2.7 answers it with:

```
ERROR  Unrecognized flag: --model in command opencode
```

The shell road (`bin/agents/einherjar-spawn.sh`) had been moved to `opencode run` on 2026-11-06
(`docs/fixes/harness/2026-11-06-opencode-v2-launch-uses-run.md`); the engine's copy of the same shape was missed,
and its test pinned the broken line under the name "matches the shell road".

## The change

- **`bin/seat/opencode-launcher.sh`** — OpenCode's one launch door, as `pi-launcher.sh` is pi's: `print`, `write`,
  `run` (launch by hand) and `check` (opencode present, and `run` takes `--model` and `--auto`).
- The engine builds `env OPENCODE_CONFIG_CONTENT=… opencode run [--model M] --auto "<brief>"`; the shell road asks
  the launcher. A parity test (`test_opencode_shape_matches_its_launcher_door`) holds the two to one line.

## Proof

`opencode-launcher.sh run --model free "reply with the single word OK"` answered `OK` on opencode v2.2.7.
`python3 -m unittest ymir_runtime.tests.test_harness` — 27 tests, OK. The full runtime suite has the same 11
failures on `main` before and after this change.
