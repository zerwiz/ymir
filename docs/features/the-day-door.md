# The day door — your acts and the house's facts, in one read

**What it is.** One command that prints your day: the acts on your own list, then what the house
measured — the mail queue, the clock, the calendar, and the evidence gap that blocks a client-facing
page. Every derived line carries its source and an `as_of`, and a source that cannot be read prints
**unable** with the reason rather than a zero.

**Who it is for.** The operator, first thing and last thing. Every other surface (a telegram push, a
desk in the hall, a desktop pane) is meant to render this door rather than invent a second record.

## What you need

- The home at `$YMIR_HOME` (resolved from the environment, then `~/.config/ymir/home`).
- Your own list at `hodd/life/personal/me/todo.md`, with acts written as
  `- [ ] **The act** — what it unblocks`.
- Optional: the mail store (`hodd/memory/mail/messages.jsonl`), `config/cron.yaml`, and the calendar
  door. Each missing piece is reported, never guessed.

## The commands

```bash
bin/day/day.sh                 # the whole day, for your terminal
bin/day/day.sh --carry         # counts and acts only — the mode a notifier may call
bin/day/day.sh --json          # the same day as data, for a surface inside the house
bin/day/day.sh acts            # just your acts, numbered
bin/day/day.sh clock           # due · fired · missed · whose role owns each job
bin/day/day.sh open 3          # the door behind act 3
bin/day/day.sh open 3 --run    # …opened in a pane
bin/day/day.sh privacy         # the private-data contract, and a check of this door against it
```

## What it shows, and how honest each part is

| Section | Source | When the source is down |
|---|---|---|
| your acts | your own file, read only | says the file is not there |
| the mail | Gná's store, with the import's `as_of` | `unable` with the path |
| the clock | `config/cron.yaml`, this seat's role, `state/.cron-fired` | `unable` with the reason |
| the calendar | Mánagandr | `unable — stale — no_oauth_grant` (its real answer) |
| the evidence | the advantage gate over the client-facing claims | `unable` if the gate or the document is absent |

## Private data — the rule it is built to

- **Reads**: your file, the mail store, this seat's schedule and state, the plans ledger, the
  calendar. Never the vault, never another account, never another seat.
- **Prints**: to your own terminal — acts, senders, subjects, counts.
- **Carries**: acts, counts and dates only. A sender or a subject does not leave the house, so
  `--carry` withholds them and says so on the line.
- **Writes**: nothing. No cache, no log, no temp file — and `privacy` checks the door's own source
  for a write-mode `open()`, a vault path, or a second mail store, and refuses if it finds one.
- **Model**: never. Your mail is not sent to a model, not even to summarise.

Law: `RULES/04` (the hoard), `RULES/15` (the vault), and the reasoning in plan 207 §14.

## Limits

- The acts are read from **one** file. There is no second list and no board sync yet; a board card is
  a projection that has not been built (plan 207 phase 4).
- "Fired" means the schedule's stamp says today. It does not prove the job did anything useful — only
  that it ran.
- It reads mail **counts** from the store, not from the mailbox: freshness is the last import's, and
  that `as_of` is printed with it.
- The pane command (`open N --run`) needs the seat door (`bin/seat/herdr-run.sh`) and a seat that is
  inside a pane; without either it prints the act rather than guessing.

## If it does not work

- **`none open, or his half was not found`** — the acts file is missing or its acts are not written
  as `- [ ] **Act**`.
- **`unable — stale — no_oauth_grant`** on the calendar — the Mánagandr grant has not been minted;
  the door is telling the truth, not failing.
- **`missed` is large** — the scheduler runs only while a session is open, so a job due at 07:00 with
  no session at 07:00 is missed by design. That is the finding, not a bug in the report.
