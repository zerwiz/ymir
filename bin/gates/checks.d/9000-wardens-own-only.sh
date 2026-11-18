#!/usr/bin/env bash
# PLAN 290 §3, the Allfather's word of 2026-11-14 (*"users must get these updates on installations"*): the
# update road turns every outward warden OFF on an existing install and records what the old install was
# running, so nothing acts outward by inertia and the operator can turn back on what he owns. Proved on a
# copy of an old-shaped home, with systemd stubbed.
gate wardens-own-only "a fresh home seats no outward warden, a foreign repository is refused, a mismatched identity is refused, a named door works" \
     bash "$ROOT/bin/gates/tests/test_warden_lib.sh"
