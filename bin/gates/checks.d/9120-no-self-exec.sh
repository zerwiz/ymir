#!/usr/bin/env bash
# no-self-exec — a forwarding script never execs its own path (2026-11-27: bin/fleet/role.sh did, and every arm looped).
#
gate no-self-exec "no forwarding script execs itself, and the role resolver answers" \
     bash "$ROOT/bin/fleet/tests/test_no_stub_execs_itself.sh"
