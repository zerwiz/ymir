#!/usr/bin/env bash
# hall-data-home — two checkouts of the hall share one data home and nothing is lost.
# While the hall is in this tree its own test runs here; once it has left for its own repo (the split,
# 2026-11-19) the same test runs in that repo's CI, and Ymir judges the installed hall through apps.sh check.
if [ -f "$ROOT/apps/bilskirnir/tests/data-home.sh" ]; then
gate hall-data-home "two checkouts of the hall share one data home and nothing is lost" \
     bash "$ROOT/apps/bilskirnir/tests/data-home.sh"
fi
