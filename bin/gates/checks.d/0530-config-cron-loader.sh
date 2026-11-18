#!/usr/bin/env bash
# config-cron-loader — the loader reads the schedule exactly as the scheduler does.
#
# PLAN 305. `src/ymir_runtime/config/load.py` validates the operator's cron.yaml, and it refused
# shapes the scheduler and the schema both accept (@daily, @hourly) — so one file was legal to the
# clock and illegal to the validator. It also had to learn the DAY gate (`@heart Mon 09:15 …`).
# One proof now covers every shape and every gate order, plus the refusals that must stay loud.
gate config-cron-loader "the cron loader reads every shape and gate the scheduler reads (plan 305)" \
     python3 "$ROOT/tests/test_config_cron.py"
