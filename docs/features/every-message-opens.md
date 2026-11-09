# Every message opens — a toast that goes somewhere

> A notification that looks clickable and does nothing is worse than one that plainly cannot be
> clicked: it teaches you to stop trying. So every message the house shows carries a **target**,
> and one door — `bin/notify/open-target.sh` — both shows the toast and opens the target.

## What it is

One door with two jobs. It **sends** the desktop toast, and it **opens** what the toast points at
when you click. Every subsystem that used to call a notifier itself now goes through it, so the
manner cannot drift and a dead link cannot hide.

A target is one of four kinds:

- a **file** — `file:<path>`, absolute or home-relative (`hodd/…` resolves inside your home);
- a **plan** — `plan:230`, resolved to that number's file in the plan ledger;
- a **pull request** — `pr:https://…`, opened in your own browser;
- a **Hlidskjalf route** — `yl:fleet`, opened at `http://127.0.0.1:3888/#/fleet`.

## What you need

Nothing new: `xdg-open` (or `open` on macOS) for opening, and either Omarchy's own
`omarchy-notification-send` or `notify-send` for the toast. If neither notifier exists the message
is still recorded — a silent host is not a lost message.

## The commands

```sh
bin/notify/open-target.sh --check                      # what this seat can open and show with
bin/notify/open-target.sh resolve plan 230              # does it exist? prints the file, changes nothing
bin/notify/open-target.sh file hodd/docs/INDEX.md       # open it now
bin/notify/open-target.sh toast --title "Meeting digest" --body "3 rows" --target file:<digest.md>
bin/notify/send.sh --source snotra --severity MEDIUM --message "the digest is ready" \
    --target file:<digest.md>                          # the hotline carries the target too
```

## Limits — what it will not do

- **A message with no target says so in its title**: `(no link)`. That is deliberate; you learn at
  a glance which few messages are dead ends.
- **A target that has gone says `(target missing)`**, opens nothing, and files one finding with the
  hotline so the dead link gets fixed instead of clicked again.
- **A route is not a promise.** `yl:` opens the gate's own URL; if the gate is down the door says
  so (exit 4) and opens nothing.
- A file opens in your editor when `$VISUAL`/`$EDITOR` is set, otherwise in the desktop's default
  handler.

## If it does not work

`open-target.sh --check` names each piece and whether it answers: the opener, the editor, the gate
and the notifier. If the click does nothing, run `open-target.sh resolve <kind> <value>` — it is the
same resolver the click uses, and it says what it found.

## Files

`bin/notify/open-target.sh` · `bin/notify/send.sh` · `bin/notify/tests/test_open_target.sh`
