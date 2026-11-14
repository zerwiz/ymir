#!/usr/bin/env bash
# cron-seats — the Hlidskjalf cron board reads its server seats from the fleet registry.
#
# Plan 278: the board takes its server seats from the registry, never names in the code. bun is the
# server's runtime, but the test is written on node:test so CI's pinned Node runs it.
gate cron-seats "the Hlidskjalf cron board reads its server seats from the fleet registry" \
     node --test "$ROOT/apps/hlidskjalf/server/server-seats.test.ts"
