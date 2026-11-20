# The TUI frame check

## What it is

A small tool that starts a real `pi` in a throw-away terminal of a chosen size, records exactly what
pi writes to that terminal, and tells you whether any line reached past the right edge — the fault that
makes a chat screen look torn: a rule from the `Working` header painted through a transcript line, a
stray bracket on the right edge, a line eaten.

## What you need

Nothing but `python3` and `pi` on the path. It opens its own pty, so it never touches the window you are
working in, and it makes no model call.

## Do it

```bash
bin/pi/tui-frame-check.sh                     # both TUI modes at 60x18
bin/pi/tui-frame-check.sh --cols 40 --rows 14 # the smallest window you actually use
bin/pi/tui-frame-check.sh --mode regular      # one mode only
```

You should see one line per mode, like:

```
  "regular","ok","5 rows drawn, none past column 60 · autowrap untouched"
  "fullscreen","ok","5 rows drawn, none past column 60 · AUTOWRAP DISABLED by pi (?7l) — an over-wide row is clipped, then the next repaint desyncs"
tui-frame-check: 2 mode(s) · columns 60 rows 18 · pass · 0 fault(s)
```

Any write past the edge is a `FAIL` with the row, the column and the bytes, and the exit code is 1.

## Notes & limits

- **`fullscreen` mode turns the terminal's autowrap off** when it starts and does not turn it back on.
  With autowrap off, a line one column too long is *clipped* rather than wrapped, and the next thing that
  repaints that line shifts what was already there. That is the tearing you saw.
- **`regular` mode never touches autowrap** and keeps no fixed band over the transcript, so that fault
  cannot happen there. This seat runs `"tuiMode": "regular"` in `~/.pi/agent/settings.json` for exactly
  that reason. To try fullscreen for one run: `pi --tui-mode fullscreen`.
- The check drives the **startup frame and a resize**, not a full model turn — it is a frame check, not a
  conversation test. It costs about eighteen seconds for both modes.

## If it does not work

- `SKIP: no ANSI stream captured` — `pi` was not interactive in the pty (a broken install, or a wrapper
  that refuses a tty). Run `pi` by hand once to confirm it starts.
- It passes, but your screen still tears — the tear is then in a component that only renders mid-turn
  (a widget or a loader). Capture it with `PI_TUI_WRITE_LOG=/tmp/pi.log pi`, reproduce, and replay the
  log with this script's scanner.
