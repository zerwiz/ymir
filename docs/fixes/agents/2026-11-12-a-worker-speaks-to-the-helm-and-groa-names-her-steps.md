# agents · 2026-11-12 — a worker's wake reaches the helm, a review ends in a verdict, Gróa names her steps

## What was wrong

Four faults in the roads a worker and the updater use to tell the helm what happened (plan 272, faults 1, 2, 5, 6).

- A worker's wake and report went to the worker's own seat directory, because the seat sets `BROKK_STATE_OVERRIDE` to its private state. The helm's queue stayed empty while the desktop note fired.
- Gróa's apply ran past the caller's 590 s limit with no word of which step stalled.
- A review seat that went idle was filed as a generic "finished without a terminal word".

## What changed

| Fault | Fix | Where |
|---|---|---|
| Wake and report in the seat | One resolver, `eindri_helm_state`: the seat's own override is ignored for what is for the helm; any other override is honoured | `bin/agents/eindri-wake-lib.sh`, `eindri-acclaim.sh`, `eindri-handoff.sh` |
| Gróa's silent stall | `gstep`: every step that can wait has its own limit, prints one stamped line with its time, and a stopped step is named | `bin/agents/groa-update.sh` |
| Review without a verdict | The sweep recovers a verdict left in `REVIEW.md`, `REPORT.md` or the status line, else files "REVIEW ENDED WITHOUT A VERDICT" with the reasons and the next command | `bin/agents/eindri-handoff.sh` |

## Proof

`bin/gates/tests/test_worker_speaks_to_helm.sh`, `test_groa_steps.sh` and `test_review_seat_verdict.sh`, each in a temp home.

## What is not measured

Which Gróa step ran past 590 s was not found: the read-only forms of every step total about 70 s here, and the apply forms restart services, which this errand may not do. The next slow apply names its step.

## CHANGE LOG

- **2026-11-12** — written with plan 272.
