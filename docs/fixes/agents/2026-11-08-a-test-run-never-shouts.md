# A test run never shouts into the chat

**2026-11-08 · component: agents**

The smoke suite exercises `report.sh write`, and every report now injects its line into the arm
holder's chat — so each run left one line in the one window that has to stay readable. Four runs, four
lines, all of them noise.

`eindri-notify.sh` now treats `YMIR_NO_INJECT=1` as `--dry`, and the suite sets it around the report
case. The shelf is still written and still deleted; the chat stays quiet.

Verified: `bash bin/gates/tests/test_areas_and_injection.sh` → 19 passed · 0 failed, no line injected.

## CHANGE LOG

- **2026-11-08** — Opened with the guard and the suite's use of it.
