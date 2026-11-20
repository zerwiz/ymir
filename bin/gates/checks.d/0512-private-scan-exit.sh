#!/usr/bin/env bash
# private-scan-exit — 2026-11-20: a finding is WORK IN THE QUEUE, not a broken job. A scan that ran exits 0 (and
# still writes the queue, the brief and the count); a scan that could not run exits 2 and names the fault;
# --fail-on-findings is there for a caller that gates.
gate private-scan-exit "a scheduled scan with findings exits 0 and still writes its queue and brief, a scan that cannot run exits 2, and --fail-on-findings gates when asked" \
     bash "$ROOT/bin/time/tests/test_private_scan_exit.sh"
