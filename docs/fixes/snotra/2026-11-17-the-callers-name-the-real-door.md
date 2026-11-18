# Fix — the callers name the real door, not the shim

**What was wrong.** The Snotra doors moved out of `bin/time/snotra/` into `systems/snotra/services/` on 2026-10-24
(plan 129), and one flat shim per door was left behind at the old spelling so an un-repointed caller would keep
working. Thirty-eight call sites were still that caller: the cron driver, the five doors that exec a Python door, the
transcript-ingest module path, the shipped schedule, a runtime docstring, a comment naming the call gate's owner, and
the whole Snotra test shelf.

**Why it matters.** A shim is a courtesy, not a home — and a courtesy that is never retired turns into a second way to
reach every door. The tests were the worse case: they proved the door worked *through the redirect*, so the shim was
the thing under test. Every such run also printed

> `snotra: bin/time/snotra/ has MOVED to systems/snotra/ — call systems/snotra/services/record/snotra-evidence.sh (plan 129)`

beside a check that had passed, which is the line that stops being read.

**What was done.** Every live caller now names the door the shim itself named. No shim was deleted, no behaviour
changed, and the redirect was left in place for any hand this change has not reached.

| call site | was | now |
|---|---|---|
| `systems/snotra/services/cron/snotra-cron.sh` (7) | `bin/time/snotra/…` | `systems/snotra/services/approve/snotra-signoff.sh`, `…/cron/snotra-trello.sh`, `…/cron/snotra-friday-synch.sh`, `…/cron/snotra-grooming.sh`, `…/cron/snotra-card-moves.sh`, `…/letters/mail-send.sh` |
| the five exec doors (`snotra-rules`, `snotra-route`, `snotra-friday-synch`, `snotra-card-moves`, `snotra-grooming`) | `bin/time/snotra/<door>.py` | `systems/snotra/services/cron/<door>.py` |
| `snotra-ingest.sh` (2 `sys.path` rows) | `{root}/bin/time/snotra` | `{root}/systems/snotra/services/cron` |
| `.agents/config/cron.yaml.example` (3 rows) | `bin/time/snotra/…` | `systems/snotra/services/cron/…` |
| `src/ymir_runtime/config/load.py` (docstring) | `bin/time/snotra/hall-snapshot.sh` | `systems/snotra/services/cron/hall-snapshot.sh` |
| `snotra-detect.sh` (comment) | `bin/time/snotra/snotra-iscall.sh` | `systems/snotra/services/ear/snotra-iscall.sh` |
| `tests/test_snotra_sensitive.sh` (10) | `…/snotra-provenance.sh`, `…/snotra-evidence.sh` | `systems/snotra/services/record/…` |
| `tests/integration.sh` (6) | store · autojoin · calendar-ask | `…/record/` · `…/ear/` · `…/calendar/` |
| `tests/test_snotra_store.sh`, `test_snotra_bot.sh`, `test_snotra_autojoin.sh` | one each | `…/record/snotra-store.sh`, `…/ear/snotra-bot.sh`, `…/ear/snotra-autojoin.sh` |

**What was deliberately left alone.** Four comments are the *record* of the move rather than a caller —
`snotra-capture.sh`, `snotra-detect.sh`'s preamble, `mail-send.sh`'s "the door that moved", and
`systems/snotra/domain.yaml` — and rewriting a record to hide where something used to be is the opposite of a fix.
The two references to `bin/time/snotra/tests/test_outbound_gate.py` in `calendar-invite.sh` and `mail-send.sh` stay
for the same reason the 2026-11-16 note gives: `tests/` under that shelf did **not** move, so that path is already
correct. `bin/time/INDEX.md` and `.agents/paths-ledger.yaml` are derived registers and are left to their weavers.

**Proof.** The tests are the same tests, judged through the new path — every row identical to the run taken before the
change, and the shim's `MOVED` line gone because nothing goes through the redirect any more:

```
$ bash tests/test_snotra_sensitive.sh      → 10 pass, 0 fail     (MOVED lines: 6 before, 0 after)
$ bash tests/test_snotra_store.sh          → 20 passed, 0 failed  (MOVED lines: 2 before, 0 after)
$ bash tests/test_snotra_bot.sh            → 17 passed, 0 failed
$ bash tests/test_snotra_autojoin.sh       → 17 passed, 1 failed  (the ping-platform row; same before)
$ bash tests/integration.sh                → 4 pass, 2 fail, 1 skip (external: ping 530, tailnet MCP)
```

Every repointed target was also resolved and run on its own: `snotra-rules.sh defaults`, `snotra-ingest.sh sources`
and `… list gong` (which proves `transcript_ingest` now imports from the real shelf), the four exec doors' usage text,
`hall-snapshot.sh` to a temp file, and `test_outbound_gate.py` in all three modes (16 tests, OK).

**What this unblocks.** Deleting the 105 shims is a separate change, and it can only be made once no caller reaches
for them — which is what this note records.

## CHANGE LOG

- 2026-11-17 — the 38 call sites repointed at the doors their shims name; no shim deleted.
