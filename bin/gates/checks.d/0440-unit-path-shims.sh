#!/usr/bin/env bash
# PLAN 275 item 26 — a unit whose PATH stops at /bin cannot see a mise-installed `gh`, so the
# digest said "not installed" while every shell found it. Every house unit names the shims.
gate unit-path-shims "every house unit's PATH reaches the house's tools (mise shims, after /usr/bin)" \
     bash "$ROOT/bin/engine/tests/test_unit_path_shims.sh"
