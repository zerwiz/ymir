# Three weekly passes — the mail balance, the pin's distance, the tunnels' uptime

Once a week, three numbers are written down: how much mail still waits on us, how far the pinned
runtime has drifted from `main`, and how many of Gimlé's published surfaces answer. Each pass adds one
row to its own history and says a word only when the week is not clean.

## What it is

The house measures a great deal by the minute and forgets it by the week. These three passes are the
opposite habit: a question that only matters monthly-ish, asked on a schedule, answered with one
number, kept in a series you can read backwards.

They are scheduled on the heart, on Monday morning — the week is judged before it is spent.

| When | Pass | What it answers |
|---|---|---|
| Mon 08:40 | `week-tunnels` | how many Gimlé surfaces answer, and which ones fail |
| Mon 08:50 | `week-mail` | how many conversations whose last word is theirs still owe a reply |
| Mon 09:00 | `week-pin` | how many commits the pinned runtime sits behind `main` |

## What you need

- A home at `$YMIR_HOME`. The numbers are kept in `state/<name>-week.jsonl`.
- For the mail balance: a mailbox the desk has imported (`bin/time/nornir-job-gna-mail.sh`).
- For the pin's distance: the pinned runtime (`~/ymir-runtime`, or `YMIR_RUNTIME_DIR`), and a working
  tree that is **not** the pin — the door refuses to report on itself from inside it.
- For the tunnels: `hodd/identity/services.yaml` with `public_url` per surface, and the tunnel configs
  in `~/.cloudflared`.

## Do it

Ask any pass now, without writing anything into the series:

```sh
bin/time/nornir-job-week-tunnels.sh --report
bin/time/nornir-job-week-mail.sh --report
bin/time/nornir-job-week-pin.sh --report
```

Run one for real — it appends its row and, if the week is not clean, sends one line:

```sh
bin/time/nornir-job-week-mail.sh
```

Read the history (one JSON object per week, oldest first):

```sh
tail -5 "$YMIR_HOME"/state/mail-week.jsonl
tail -5 "$YMIR_HOME"/state/pin-week.jsonl
tail -5 "$YMIR_HOME"/state/tunnels-week.jsonl
```

Put the rows on a schedule: install or update copies `config/cron.yaml.example` on a fresh machine,
and `.agents/migrations/0025-weekly-passes.sh` adds the three rows to an existing `config/cron.yaml`
(only rows it cannot find; the operator's own lines are never moved). Then restart the scheduler:

```sh
bin/time/nornir-cron-start.sh --stop
bin/time/nornir-cron-start.sh
```

## What the row says

Each row is exactly three keys — appended, never rewritten:

```json
{"at":"2026-11-17T08:40:00Z","value":7,"detail":"7 up · 0 failing"}
```

`value` is the pass's own number: the surfaces answering (tunnels), the conversations owing a reply
(mail), the commits behind (pin). When the door cannot answer at all, `value` is `null` and `detail`
says why — a pass never records a zero it did not measure.

## Limits

- **One line, and only when it matters.** A clean week writes its row, carves a no-op Rune and stays
  silent. A dirty week sends one message, keyed to the week, so a second run in the same week is the
  same message.
- **Exit code 0 on a dirty week.** The row, the Rune and the message carry the verdict; the scheduler
  is not asked to raise a second line for a fault already reported.
- **The mail count is the owed ones.** A notice, an invoice or a bulk sender whose word is last is the
  door's own `closed` lane, not a conversation waiting on you; the row's detail names the wider count
  beside it.
- **The pin number needs a tree that is not the pin.** Run it from your working tree; the door refuses
  to judge itself from inside.
- **The tunnels pass needs the network.** A surface that cannot be reached from this machine reads as
  failing; that is the measurement, not an error.

## If it does not work

- `week-…: could not measure` with exit 2 — the door is missing, or it printed no answer. Run the door
  by hand (`bin/mail/threads.sh --json`, `bin/engine/pin-refresh.sh --check`,
  `bin/records/gimle-tunnels-check.sh`) and read its own message.
- Nothing fires on Monday — `bin/time/nornir-cron-start.sh --status` prints `invalid=<n>` when a
  schedule line cannot be read. A weekly row is `Mon 08:40`, and an unreadable shape never fires.
- The rows are not in your schedule — run `bin/engine/ymir-migrate.sh apply`, which includes
  `0025-weekly-passes`.

## CHANGE LOG

- 2026-11-17 — written with the three weekly passes it describes.
