# gates · unversioned · 2026-11-14 — the mocks scan could not tell a fixture from a stub

The `mocks-vocabulary` gate has been red on `main` for days. The scan
(`.agents/skills/galdr-ymirsystem/scripts/mocks-scan.sh`) greps shipped code under `bin/` for the four
words that name something unfinished — `mock · stub · placeholder · todo` — and on tonight's tree it
found **89 hits in six files**, none of them a stub.

## What it was actually finding

| File | Hits | What the word is there |
|---|---|---|
| `bin/records/tests/test_comms.py` | 53 | a test's own fixtures (`todo = seed()`, a `stub` script it runs) and assertion text |
| `bin/records/comms.py` | 21 | the operator's todo ledger — `--todo`, `todo-matches`, `todo-apply`, the `todo` tag; the feature's NAME |
| `bin/voice/voice_tools.py` | 4 | the voice's template prompt ("fill every placeholder") and the ledger's own verbs |
| `bin/seat/tests/test_everything_up.sh` | 2 | a test calling the MCP face's real `todo()` tool, and an assertion about a placeholder file |
| `bin/gates/tests/test_review_seat_verdict.sh` | 4 | a declared fixture (`herdr` on PATH in a temp dir) |
| `bin/forge/gather.sh` | 5 | the batch manifest's own state key `todo=` (rewritten to `merged=`/`pending=` as it walks) |

> [!IMPORTANT]
> The gate is about SHIPPED BEHAVIOUR. A test stands a fake by definition, and the todo ledger is a
> feature whose name is the word. Neither is a stub — but the exemption must not swallow a real one.

## What changed

- **A test's fixtures are excused by class.** Any hit under a `tests/` directory is skipped: a `stub`
  variable and a `todo` fixture in a test are the test.
- **Two vocabulary files are declared, with their reason** — `bin/records/comms.py` (the ledger's own
  verbs and tag) and `bin/voice/voice_tools.py` (the template's word and the ledger's verbs). This is the
  idiom the scan already used for Pi's tool names in the mcp doors and for `advantage-audit.sh`.
- **`gather.sh`'s `todo=` manifest key** is excused only on lines that carry the key, so a real `stub`
  in that file is still caught.
- **`test_review_seat_verdict.sh`** joins `test_seat_reap.sh` as a declared fixture.

## Proof

`.agents/tests/mocks-scan.test.sh` — **10 checks, 0 failures**, and it proves the new excuses stay
narrow at both ends:

```text
ok - a test's fixtures are excused by class (bin/door/tests/)
ok - the tests-dir excuse stays narrow: a stub outside tests/ is still caught
ok - the ledger's own vocabulary (bin/records/comms.py) is excused
ok - the vocabulary excuse stays narrow: a stub beside the declared file is still caught
ok - the shipped tree passes its own scan
```

## Files

- `.agents/skills/galdr-ymirsystem/scripts/mocks-scan.sh`
- `.agents/tests/mocks-scan.test.sh`

## CHANGE LOG

- 2026-11-14 — written with the mend; the excuses are declared in the scan, as its own doctrine demands.
