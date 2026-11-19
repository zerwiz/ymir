## rodd · 2026-11-19 — the smoke finds the window's DevTools port, and a listening host is not called down

### Why
`smoke.sh` is the check that answers *"would the operator get an answer if he spoke now?"*. Run against the live window
from the apps home, it said:

```
tunnel to the host seat                        DOWN
live window (socket · accepted · audio)        SKIP  app not started with --remote-debugging-port=9222
```

The host was listening on `127.0.0.1:8890`, and the window was answering DevTools on 9416.

### Cause
- **The port.** The live step and `smoke/live.py` asked DevTools on a fixed 9222. `start.sh` never gives the window that
  port: it takes the app's own port from Ymir's `bin/desktop/app-lib.sh` (9416 for Rödd). So the one step that hears
  assistant audio was skipped on every run.
- **SIGPIPE under pipefail.** `ss -tln | grep -q ':8890'` runs with `set -o pipefail`. When `grep -q` finds its match it
  exits early, `ss` dies of SIGPIPE, and the pipeline fails. A listening host reads as down. `start.sh`'s tunnel check
  had the same shape.

### The fix
In `zerwiz/rodd`, commit `9a79ba7` on branch `eindri/e2e-rodd`:

- `smoke.sh` reads the window's port from the running window's own command line, and `RODD_DEVTOOLS_PORT` wins. It
  passes the port to `live.py`, which takes it from the environment and keeps 9222 only as the last default.
- `smoke.sh` and `start.sh` read the listener list whole first, then match it.

### Proof
`smoke.sh 45` from `~/.local/share/ymir-apps/rodd/current`, every line green:

```
tunnel to the host seat                        PASS
host accepts a session                         PASS
the page opened a socket to the pipeline       PASS  ws://127.0.0.1:8890/v1/realtime
the server accepted the session                PASS
assistant audio arrived                        PASS  390144 bytes
live window (socket · accepted · audio)        PASS
```

## CHANGE LOG

- 2026-11-19 — review-mend: added missing heading for #826
