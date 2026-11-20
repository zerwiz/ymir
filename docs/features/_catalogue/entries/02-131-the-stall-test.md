---
section: agents-work-collaboration
---
| The stall test | A worker that is alive but has stopped moving is caught, steered once, and told to you once | The arm reads every `working` errand's pane every ten minutes (`bin/time/nornir-job-eindri-stall.sh` → `bin/agents/eindri-stall.sh sweep`): no change for 20 minutes, or one command past its 30-minute limit, wakes the helm with the pane's last 15 lines and types one line into the worker; ten minutes later, if nothing has moved, one Telegram message goes to you with buttons *look at the pane · stop it · let it run*. Silent on a moving fleet. One number for the limit: `bin/agents/cmd-limit-lib.sh` | [docs/features/the-stall-test.md](docs/features/the-stall-test.md) |

## CHANGE LOG

- 2026-11-20 — the stall test: the arm watches, Rödd speaks (the two errands that sat for hours).
