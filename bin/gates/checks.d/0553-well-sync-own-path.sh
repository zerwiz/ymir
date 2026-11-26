#!/usr/bin/env bash
# well-sync-own-path — the well sync commits only its log, whatever else is staged.
gate well-sync-own-path "the well sync commits only its log, whatever else is staged" \
     bash "$ROOT/bin/time/tests/test_well_sync_own_path.sh"
