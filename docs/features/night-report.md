# The night report — what the fleet did while you slept

**What it is.** One report, written each morning, about the night's work across every seat. It covers
what finished, what did not and why, which pull requests merged, which are still open and why, the
alarms that rang, and what is still waiting on you. It also ticks items off your to-do list, but only
where the work is proven done. One short Telegram message points you to it.

**Who it is for.** The operator, at the first coffee. The full report lives in the home. The message
carries only the counts and the three things that need you first.

## What you need

- The home at `$YMIR_HOME`, resolved from the environment and then from `~/.config/ymir/home`.
- Your list at `life/personal/me/todo.md`, with items written as `- [ ] **The act** — the detail`.
- `gh`, signed in as you, to read the pull requests of every repository the project registry names
  (`hodd/identity/projects.yaml`, each row's `git:` block).
- Optional: an ssh road to each other seat, from `hodd/data/fleet.json`. A seat that does not answer
  is named in the report, and its errands are left out rather than guessed.
- Optional: a board with `decision` cards (plan 335), reached through the registry's `board:` block.

## The commands

```bash
bin/day/night-report.sh --dry-run                # print the report and the message; write nothing
bin/day/night-report.sh --dry-run --json         # the gathered facts, as data
bin/day/night-report.sh                          # write it, tick the list, ship the home, send one message
bin/day/night-report.sh --since 2026-11-20T22:00 # choose the window's start
bin/day/night-report.sh --repo owner/name        # read one more repository (repeatable)
bin/day/night-report.sh --fallback               # a seat standing in for the heart
```

By default the window starts at the last report. When there is none, it starts at 22:00 the evening
before.

## What each section means

| Section | Read from | Counted when |
|---|---|---|
| Errands done | every seat's `state/<id>.status` and `state/eindri-reports/<id>.md` | the last state line is `done:` |
| Errands not done | the same files | `failed`, `needs-decision`, `blocked`, `paused`, `false-done`, or silent for two hours |
| PRs merged | GitHub | merged inside the window |
| PRs open, and why | GitHub | open now: red gate, gate running, conflict, rework asked, draft, on hold, no gate ran, or green |
| Alarms and mends | the Runes ledger | a `notify` row at HIGH or CRITICAL, and every `mend` row |
| Waiting on you | your half of the list, the boards and the voice ledger | open, and not under *Held* |

Every line names its source, so you can open the record behind it.

## How an item is ticked

An open item is ticked only when its **subject** names exactly one thing, and that thing is proven
closed. The subject is the bold lead, or the words before the first ` — `.

- If the subject names one pull request, that PR must have merged, and not before the item was written.
- If it names one errand in backticks, that errand must have ended `done`. When the errand names a PR,
  that PR must have merged too.

A tick changes `- [ ]` to `- [x]` and appends `(done: <date> — <proof>; ticked by the night report)` to
the item's last line. The item's own words are never rewritten. A PR named only in an item's reasons,
such as *"Unblocks: every PR's gate, #831 first"*, never ticks it.

## When it runs

The schedule is in the home's `config/cron.yaml`:

```
@heart 06:30 bin/day/night-report.sh
@dev 06:50 bin/day/night-report.sh --fallback
```

The heart is always up, so it writes the report. Each dev seat stands by at 06:50. It waits a fixed
while of its own, pulls the home, and stands down when today's report already exists.

## Limits

- `state/` does not travel with the home's git, so another seat's errands are read over its ssh road.
  A seat that is dark or unreachable is named under *What could not be read*.
- The message is one line block with three buttons: open the report, merge what is green, and show
  what is stuck. It goes through `bin/notify/send.sh`, so it is recorded in the Runes ledger.
- A second run on the same day appends a section to the report. It never replaces the first.

## If it does not work

- **"the home could not be pulled first"**: run `bin/vault/home-sync.sh status`, mend the conflict it
  names, and run the report again.
- **A repository is under *What could not be read***: run `gh auth status`. A network drop is retried
  three times before it is reported.
- **No message arrived**: run `bin/notify/send.sh --source cron --severity INFO --ask --dry-run
  --message test`. If the dry run is clean, check the Telegram keys in the vault.

The logic is `bin/day/night_report.py` and `bin/day/night_seat.py`. The tests are
`bin/day/tests/test_night_report.py`.

## CHANGE LOG

- **2026-11-21** — written with the change it describes.
