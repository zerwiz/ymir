#!/usr/bin/env bash
# Unit test for tools/mill/worker.sh — the mill worker waits when its queue cannot be read.
#
# The defect this test exists for (2026-11-21): the queue read was
# `job="$(command -v redis-cli && … blpop …)"; [ -n "$job" ] || continue`. On a machine with no
# redis-cli (the heart) the loop never waited, and the worker held a whole core for six days.
# A redis that refused at once spun the same way. Both roads must now say it ONCE and sleep.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKER="$ROOT/tools/mill/worker.sh"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
# A PATH with the tools the loop needs and, by default, no redis-cli.
# (`sleep` is NOT linked: run_for writes its own counting `sleep` here, and writing through a link
# would write the system's binary.)
for t in bash date sed grep head cut printf timeout python3 dirname; do
  p="$(command -v "$t")" && ln -sf "$p" "$TMP/bin/$t"
done

# run_for <seconds> — run the worker, count its loop turns through a fake `sleep` that logs each call
run_for() {
  : >"$TMP/sleeps"
  rm -f "$TMP/bin/sleep"
  printf '#!/bin/sh\necho x >>"%s/sleeps"\nexec %s "$@"\n' "$TMP" "$(command -v sleep)" >"$TMP/bin/sleep"
  chmod +x "$TMP/bin/sleep"
  PATH="$TMP/bin" HOME="$TMP" MILL_IDLE_SECONDS=1 timeout "$1" bash "$WORKER" >"$TMP/out" 2>&1
}

# 1. no redis-cli: said once, and the loop sleeps between tries (a few turns, not thousands)
run_for 4
said="$(grep -c 'unreadable (no redis-cli' "$TMP/out")"
turns="$(wc -l <"$TMP/sleeps")"
[ "$said" = 1 ] && ok "no redis-cli: said once" || bad "no redis-cli: said $said times"
[ "$turns" -ge 2 ] && [ "$turns" -le 6 ] && ok "no redis-cli: waits ($turns turns in 4 s)" \
  || bad "no redis-cli: $turns loop turns in 4 s (spinning, or never waiting)"

# 2. redis-cli that refuses at once: said once, waits
printf '#!/bin/sh\necho "Could not connect to Redis at 127.0.0.1:6379: Connection refused"\nexit 1\n' >"$TMP/bin/redis-cli"
chmod +x "$TMP/bin/redis-cli"
run_for 4
said="$(grep -c 'unreadable (redis-cli failed' "$TMP/out")"
turns="$(wc -l <"$TMP/sleeps")"
[ "$said" = 1 ] && ok "refusing redis: said once" || bad "refusing redis: said $said times"
[ "$turns" -ge 2 ] && [ "$turns" -le 6 ] && ok "refusing redis: waits ($turns turns in 4 s)" \
  || bad "refusing redis: $turns loop turns in 4 s"

# 3. a queue that answers: the job is still dispatched by its class
printf '#!/bin/sh\n/bin/sleep 1\nprintf "mill:jobs\\n{\\"class\\":\\"nosuch\\"}\\n"\n' >"$TMP/bin/redis-cli"
run_for 3
grep -q 'unknown job class: nosuch' "$TMP/out" && ok "a job is still dispatched" || bad "a job was not dispatched"

exit "$fail"
