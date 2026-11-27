#!/usr/bin/env bash
# no-stub-execs-itself — a forwarding stub never execs its own path (2026-11-27: bin/fleet/role.sh did, and every arm looped).
#
gate no-stub-execs-itself "no forwarding stub execs itself, and the role resolver answers" \
     bash "$ROOT/bin/fleet/tests/test_no_stub_execs_itself.sh"
