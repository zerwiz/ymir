#!/usr/bin/env bash
# hall-data-home — two checkouts of the hall share one data home and nothing is lost.
gate hall-data-home "two checkouts of the hall share one data home and nothing is lost" \
     bash "$ROOT/apps/bilskirnir/tests/data-home.sh"
