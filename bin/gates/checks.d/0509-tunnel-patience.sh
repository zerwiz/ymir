#!/usr/bin/env bash
# tunnel-patience — 2026-11-20: a surface that misses the first timeout is asked again before it is called
# down, so a cold AFFiNE does not ring the operator's phone every half hour; a second silence still fails.
gate tunnel-patience "a slow origin is asked twice before it is judged down, and a silent one still fails with the row saying so" \
     bash "$ROOT/bin/records/tests/test_tunnel_patience.sh"
