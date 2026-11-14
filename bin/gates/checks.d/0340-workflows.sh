#!/usr/bin/env bash
# workflows — every Actions workflow parses.
gate workflows  "every Actions workflow parses"               bash "$ROOT/bin/gates/checks/workflow-check.sh" --quiet
