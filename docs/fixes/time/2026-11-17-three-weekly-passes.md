# Fix — three weekly passes, and the shape Nornir did not have

**What was built.** Three Nornir rows that each answer one question a week and answer it the same
way every time: a number, one line in a series, and a word to the Allfather only when the week is not
clean.

| pass | the question | the door |
|---|---|---|
| `week-mail` | how many conversations whose last word is theirs still owe a reply after 14 days? | `bin/mail/threads.sh --json` |
| `week-pin` | how far is the pinned runtime from `main`? | `bin/engine/pin-refresh.sh --check` |
| `week-tunnels` | how many Gimlé surfaces answer, and how many fail? | `bin/records/gimle-tunnels-check.sh` |

Each is thin: `bin/time/nornir-job-week-{mail,pin,tunnels}.sh` calls its door, turns the answer into
`value` + `detail`, and hands it to `bin/time/week-pass-lib.sh`, which owns the one law — append the
row, carve the Rune, speak once. Three jobs kept in step by hand would have drifted on the first
change.

**The row.** One JSON line per run in `<home>/hodd/state/<name>-week.jsonl`:

```json
{"at":"2026-11-17T08:40:00Z","value":7,"detail":"7 up · 0 failing"}
```

Exactly three keys — `at` · `value` · `detail` — appended, never rewritten: no truncation, no
compaction, no "latest only" file. A week that was dirty stays dirty in the record, and the count
never falls.

**Clean, dirty, and the one line.** Clean writes the row, carves `week.<pass>.ok`, and sends nothing:
a weekly cron that speaks every week is a cron nobody reads. Dirty writes the row, carves
`week.<pass>.fault`, and sends exactly one line through `bin/notify/send.sh`, keyed to the ISO week
(`week-mail-2026-W47`), so a second run in the same week cannot speak twice. A door that cannot
answer at all writes a row with `value: null` and exits 2 — absence is a failure, never a zero.

**The exit code is 0 on a dirty week, on purpose.** The scheduler raises its own HIGH line for any
non-zero row, and one fault would then speak twice — which the brief forbids. So the measurement
succeeds and the verdict lives in the series, the Rune and the cron log; the one line is the pass's
own. This deliberately differs from the daily briefing, whose scheduler line *is* its one line.

**The shape that did not exist.** The rows were ruled as `@heart Mon 08:40`, and Nornir had no weekly
shape — its shapes were `HH:MM` · `@daily` · `@hourly` · `@hourly:MM` · `@every:N`. An unreadable
shape is named in `state/.cron-invalid` and never fires, so the row would have been declared-but-dead
before its first Monday. The shape was added in every reader of the schedule:

- `bin/time/nornir-cron-start.sh` — `parse_line` joins the two words (`Mon 08:40` → `Mon@08:40`),
  `at_valid` accepts it, and the fire reads the weekday (`date +%u`) with the date as its stamp;
- `src/ymir_runtime/config/load.py` — the loader joined the same pair, and its gate detection was
  repaired: a token starting with `@` was taken as a role gate, so `@hourly 07:00 cmd` parsed as a
  gate named `hourly` with the clock as its command;
- `config/cron.schema.json` — the pattern gained the weekly shape and `@every:N`, which the
  scheduler already ran and the schema did not describe;
- `bin/records/cron-registry.sh` — the strip-regex names the command, not `08:40`.

**The rows run on an existing machine, not only on a new one.** `config/cron.yaml.example` is what a
fresh install copies; an existing home keeps its own schedule and is never overwritten. So
`.agents/migrations/0025-weekly-passes.sh` appends the three rows to a home that already has a
schedule — only the rows it cannot find, only at the end, never reordering what the operator wrote —
and defers (exit 3) on a home with no schedule at all.

**Proof.**

```
$ bash bin/time/tests/test_week_passes.sh
test_week_passes: PASS (40 assertions)

$ bash .agents/tests/nornir-schedule-shapes.test.sh
nornir-schedule-shapes: PASS
```

The 40 assertions cover, per pass and per kind of week: the row is written and is the only row of
that shape; `{at,value,detail}` exactly; the first row is byte-identical after a later run; the clean
week sends nothing and carves `ok`; the dirty week sends exactly one line, names the fault, and
carries the week key; a second run in one week repeats the key; an unanswerable door writes
`value: null`. The schedule test proves the row fires on its own weekday, not on the next day, not on
a later minute, and that the role gate still gates it from either side.

**Measured on this machine the day it shipped** — `--report`, writing nothing:

```
week-tunnels: clean — 7 up · 0 failing
week-mail:    NOT CLEAN — 5 conversation(s) whose last word is theirs still owe a reply after 14 days (of 155 inbound tails that age; oldest 55 d)
week-pin:     clean — the pin is at main at ca7cf755
```

The mail number is the owed ones, not every inbound tail: the door's own judge calls a notice, an
invoice or a bulk sender `closed`, and counting those would put a number in the hundreds in front of
the Allfather every week until he stopped reading it. The wider count is named in the row's detail.

## CHANGE LOG

- 2026-11-18 — review-mend: added missing heading for #817
