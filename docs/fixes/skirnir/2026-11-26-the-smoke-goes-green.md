# Skírnir's smoke test is green again, and its failures mean something

**2026-11-26.** The nightly row `smoke.sh --quiet` had failed every day with 13 to 16 failures.

## What was wrong

| Fault | Cause | Fix |
|---|---|---|
| "the engine: no output", digest and canary counts, retention, seat guard, idle-stop, the pitch ×3 | Under `--quiet`, `ok()` returned non-zero. Each check reads `test && ok … \|\| bad …`, so a passing check was also booked as a failure. | `ok` and `skip` always return 0. No threshold changed and no fact was approved. |
| The mouth, mouth raise, voice restart, idle-stop lease | Another web server held the speech engine's port, so the engine's unit crash-looped. The smoke's own probe accepted the stranger's HTTP 501 as "kokoro answers". | The probe now needs real audio. The mouth and the smoke name the program that holds the port. |
| "what is ymir" returned a pile of labels | The pitch without a model joined whatever shared a keyword: document titles, a two-word label, the assistant's own capability page. | The pitch is built from public sentences only, in telling order: what it is, who does the work, how the work is kept. |
| The pitch with a model | The model was told to use "the facts" and was given none. It was also called for a stranger. | The chosen facts travel with the brief. A stranger never reaches a model. |
| "what is gimle" answered "bin/gimle — moved out of Ymir" | Facts made from backups, retired records and moved-away records could answer. | Those records are never an answer. |
| `AttributeError: 'str' object has no attribute 'get'` | The Trello map in the home has another shape (`boards` is a mapping). | The smoke prints a skip. `trello-map.sh --resolve` says why instead of crashing. |
| A note from an earlier run could satisfy a later check | Voice notes had fixed names under `/tmp`. | Each run uses its own temporary folder and removes it. |

## One check was wrong

The matcher check used `gimle` as a subject the house does not hold. The house has since written many records about
it, so the premise was false. The check now asks about an invented word and expects a refusal. A second check keeps
the original guard: `gimle` may not be answered as the Ymir pitch, or from an archived record.

## What proves it

- `bash systems/skirnir/services/smoke.sh` and `… --quiet` exit 0.
- `bash systems/skirnir/tests/test_smoke_verdicts.sh`: one verdict per check, and a squatted port is named.
- `systems/skirnir/services/test_pitch.py`: what the pitch may be built from, and what may never answer.

## Still open

`walls-test.sh` is a separate suite. It fails the same 8 checks before and after this change.

## Files

- `systems/skirnir/services/smoke.sh`, `skirnir.py`, `mouth.sh`, `test_pitch.py`
- `systems/skirnir/tests/test_smoke_verdicts.sh`
- `bin/voice/kokoro-lib.sh` (`kokoro_port_squatter`)
- `systems/snotra/services/cron/trello-map.sh`

## CHANGE LOG

- 2026-11-26 — review-mend: added missing heading for #964
