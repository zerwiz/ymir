# Quality gates

Run before anything leaves the room. A failed gate stops dispatch; it never
produces a partial document.

| Gate | Check | Fail behaviour |
|---|---|---|
| G1 Evidence | Every decision and action has a timestamp and a quote | Mark unverified and exclude from dispatch |
| G2 Ownership | Exactly one named owner per action | List as an unassigned risk, never as a task |
| G3 Dates | ISO date; relative language resolved and flagged | `date unresolved` + `decide_by`; cannot be closed |
| G4 Schema | Record validates against `meeting-schema.json` | Stop; publish nothing |
| G5 Second pass | Independent pass looks for omissions and invented items | Show disagreements to the reviewer; do not auto-resolve |
| G6 Review | The meeting secretary approves the draft | Nothing dispatched |
| G7 Confirmation | Participants confirm or correct within two business days | Item stays provisional and is flagged weekly |
| G8 Privacy | No meeting content in the repository; classification respected | Withhold the record and report the incident |

## The second pass

Ask a second reader, human or model, three questions and record the answers:

1. Which decision in the transcript is missing from the record?
2. Which entry is not supported by its quote?
3. Which owner or date is inferred rather than stated?

Disagreements are surfaced, never silently resolved. A record that cannot
withstand these three questions is not ready.
