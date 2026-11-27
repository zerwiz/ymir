# main's whole-tree gate is green again: the lost clock-lock change and a dangling Snotra link

**Component:** gates (with time and harness) · **Date:** 2026-11-27

## What was wrong

`whole-tree` on `main` failed on three rows, and every PR inherited them:

- `clock-lock` / `test_clock_lock`: the stray-pointer refusal, the refused stop, `--stop --why` and the dead-owner
  refusal were missing from `bin/time/nornir-cron-start.sh`.
- `compliance`: the `harnesses` row named `.opencode/agents/snotra.md(dangling)`.

## Why

- Plan 369 item 17 (`4dd47412c`) changed `bin/time/nornir-cron-start.sh`, `src/ymir_runtime/state/lock.py`,
  `bin/ward/trouble.py` and `scripts/stop.sh`, with its test. When the recovery merge (#962) resolved its conflict
  against #954, the script kept #954's side only. The other three files and the test landed, so the test failed.
- Plan 374 renamed `snotra-documenter.md` to `snotra-ear.md` and left the OpenCode link behind.

## The fix

- Item 17's diff to `bin/time/nornir-cron-start.sh` is applied again on top of #954. In the one overlapping spot
  (`--status`), both are kept: the refused-pointer warning and #954's count of invalid rows.
- `.opencode/agents/snotra.md` points at `../../.agents/agents/snotra-ear.md`; the harness asset says so.

## Proof

`bin/time/tests/test_clock_lock.sh` PASS (12 ok), `test_cron_invalid.sh` PASS, `test_nornir_mend.sh` 4 passed.
`compliance-check.sh`: every row PASS.

## CHANGE LOG

- 2026-11-26 — review-mend: added missing heading for #967
