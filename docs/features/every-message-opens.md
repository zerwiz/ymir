# Every message opens something

## What it is

Every notification the house sends now carries a **target**: the thing it is about. Click the toast and it
opens — the digest, the plan, the pull request, the hall's own page. A message that has nothing to open says
so in its own title, `(no link)`, so you learn at a glance which few are dead ends instead of clicking and
being disappointed.

## What you need

A desktop with a notification daemon (Omarchy's own notifier, or `notify-send`), and a browser or editor for
`xdg-open` to hand the target to.

## Do it

Send yourself a message with a target:

```
bin/notify/send.sh --source notify --severity INFO --message "a plan to read" --target plan:230
```

The toast says what it opens; click it and the plan opens. The four kinds:

```
file:<path>      a file under the home or the tree
plan:<number>    the ledger file for that plan number
pr:<url>         a GitHub pull request, opened in your own browser
yl://<route>     a Hlidskjalf page (only while the gate answers)
```

Verify a target without opening anything:

```
bin/notify/open-target.sh --check plan:230
bin/notify/open-target.sh --check file:hodd/memory/daily/2026-11-09.md
```

## Notes & limits

- A missing target is refused and filed as a finding — it is never offered as a click.
- A `yl://` route is refused while the gate is down (`gate-down`); the door does not open a dead URL.
- One toast door draws every toast (`bin/notify/desktop.sh`), so no subsystem can invent its own behaviour:
  `grep -rn notify-send` finds only `bin/notify/`.
- An approval still works as a click that **runs** something (`--exec`), which is how "approve" is one
  gesture.

## If it does not work

- The toast appears but has no action — the notification daemon does not support actions; the target is
  still printed in the message and in the ledger line.
- `no-opener` — set `YMIR_OPEN_CMD` to your opener (default `xdg-open`).
- `target missing` in the title — the path moved; the finding is in the runes ledger.
