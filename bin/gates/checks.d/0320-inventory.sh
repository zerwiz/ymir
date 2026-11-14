#!/usr/bin/env bash
# inventory — the bin/backend index is current.
gate inventory  "the bin/backend index is current"            bash "$ROOT/bin/gates/inventory.sh" --check
