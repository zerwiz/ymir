## agents · unversioned · 2026-11-19 — a wake is classed on write: voice, ask or report

### Why
Plan 328. Measured 2026-11-19 22:17, 22 wakes pending: the queue drained in arrival order and was mostly machinery, so Rödd's spoken line sat 17th behind sixteen errand reports and a colleague's mail sat 21st. The order cannot be fixed without knowing which line is a person. So each door that files a wake now names its class as a trailing class=<c> tab field, chosen by SOURCE: bin/voice/rodd-arm.sh tell writes class=voice for a person and report/ask when --from names an errand (agent <id>, eindri <id>, a pane id), with --class to state it outright; bin/agents/eindri-wake-lib.sh eindri_queue_wake takes an optional class, and eindri-acclaim.sh and eindri-handoff.sh pass ask for a QUESTION and report for done, corrected and a failed review spawn; the mail desk (bin/mail/gna_notify.py nudge) writes class=voice; the state door (ymir-state.sh queue append --class) carries the field through src/ymir_runtime/state/queue.py, whose Wake parses it off the payload. The field is TRAILING so every reader that matches the head of a line (the Sól stamp, the key in field 4, the dispatcher's lead stamp) is untouched; bin/dispatch/dispatch.py strips it before a question becomes a title. Proof: rodd-arm.sh --self-test 43 passed (new: Rödd is voice, an agent is report, an agent's question is ask, --class wins, a bad class refused); test_state 30 OK (the class round-trips); test_dispatch 51 passed.

### Files
- `bin/voice/rodd-arm.sh`
- `bin/agents/eindri-wake-lib.sh`
- `bin/agents/eindri-acclaim.sh`
- `bin/agents/eindri-handoff.sh`
- `bin/mail/gna_notify.py`
- `bin/dispatch/dispatch.py`
- `src/ymir_runtime/state/queue.py`
- `src/ymir_runtime/state/__main__.py`
- `src/ymir_runtime/tests/test_state.py`