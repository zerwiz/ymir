# Fix: plan-watch clock

Added nornir-job-plan-watch.sh reporting plan arithmetic to state/plan-watch.json and one line via eindri-notify.

## CHANGE LOG

- **2026-11-09** — written with the job: the clock that reads every ledger, counts what is behind, asks the fleet
  for its claims, and sends one line to the arm.
