#!/usr/bin/env bash
# cron-invalid — --status counts today's unreadable rows, and a retiring clock throws no shell error (plan 369 item 12).
gate cron-invalid "the clock counts the invalid rows of the live schedule and retires without a shell error" \
     bash "$ROOT/bin/time/tests/test_cron_invalid.sh"
