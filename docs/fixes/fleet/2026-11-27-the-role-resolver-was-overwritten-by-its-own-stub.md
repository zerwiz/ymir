# The role resolver was overwritten by its own forwarding stub

**Date:** 2026-11-27 · **Component:** fleet · **Found by:** the arm holder on a second seat, after a pin flip

## What broke

Commit a0900d8d0 (*forge: every branch that carried work is gathered into one delivery*) wrote the forwarding stub
meant for `bin/skuld/role.sh` over `bin/fleet/role.sh` as well. Both files became the same blob (7eec607e). The stub
execs `$_d/../fleet/role.sh` — which, for `bin/fleet/role.sh`, is itself: an endless exec loop.

The arm daemon (`python -m ymir_runtime watch run`) calls `role.sh resolve` before it writes its lease, so on a release
built from main the arm never comes up. A seat that flipped to main lost its arm; the nightly update would have done
the same to every seat.

## The fix

`bin/fleet/role.sh` is restored to the real resolver (blob 180f7cb, its content before a0900d8d0). The stub stays only
at `bin/skuld/role.sh`, forwarding to the resolver as plan 374 intended.

## The test

`bin/fleet/tests/test_no_stub_execs_itself.sh` scans every tracked shell script for the forwarding-stub shape and fails
if one execs its own path, and checks that `bin/fleet/role.sh --help` returns within 20 seconds. It fails on main before
this fix and passes after it.

## CHANGE LOG

- 2026-11-27 — review-mend: added missing heading for #973
