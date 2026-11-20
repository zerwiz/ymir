---
section: agents-work-collaboration
---
| Delivery | **The push road — a push judged once, on what it adds, inside its budget** (`.githooks/pre-push` · `bin/forge/park.sh` · `bin/forge/exec-bits.sh` · [how-to](docs/features/the-push-road.md)) | Plan 339.1, 2026-11-20: one push took over thirteen minutes and failed on four wards. The hook now judges the commits since the fork point (not main's changes, not untracked files), runs the cheap refusals first, holds the wards to a budget that cuts them off, prints every stage's time, and stamps a passed sha so a gathered head is not judged twice. `gather.sh` merges a moved base instead of refusing it; the public-data ward offers `--mask <path>:<line>`; errand briefs set the executable bit with `exec-bits.sh --fix`. `park.sh` is the survival push to `refs/parked/<errand>`, judged by the privacy wards only and off until the operator names a remote. A current branch went from 30.3 s to 9.6 s. Proved by `bin/gates/checks/push-road.test.sh` | [docs/features/the-push-road.md](docs/features/the-push-road.md) |

## CHANGE LOG

- 2026-11-20 — added with the push road.
