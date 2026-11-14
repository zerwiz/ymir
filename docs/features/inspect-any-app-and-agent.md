# Doors — inspect any app and any agent

Hlidskjalf's **Fleet** page lists two kinds of door, so you can look into anything that is
running **without restarting it**.

## What it is

- **An app's door is its DevTools (CDP).** Every Ymir app opens its own on a fixed loopback
  port from one table (`bin/desktop/app-lib.sh app_devtools_port`):

  | App | Port |
  |---|---|
  | Hlidskjalf | 9411 |
  | Smíðja | 9412 |
  | Óðrerir | 9413 |
  | Sessrúmnir | 9414 |
  | Bilskirnir | 9415 |
  | Rödd | 9416 |

  Point a Chrome DevTools window at `http://127.0.0.1:<port>`. The Fleet page marks each one
  **up** only when the port really answers CDP this second, and says **down** when it does not.

- **An agent's door is its herdr pane.** `herdr agent read <pane>` prints what the agent is
  doing. It reads; it never steers the agent, so it is safe to use while the agent works.

## What you need

Nothing. The ports are on from the moment an app starts, and the pane list is read from herdr
itself. An explicit `YMIR_DEVTOOLS_PORT` still overrides the table for one launch.

## The commands

```bash
bin/desktop/hlidskjalf-doors.sh          # every door as JSON (what the page reads)
bin/desktop/hlidskjalf-doors.sh --toon   # the same as a table for a terminal
herdr agent read w39:p0                  # one agent's pane, by the id the page shows
```

## Limits

- Only the apps listed in the table have a fixed port. An app not in the table has no door,
  and the page says so rather than guessing a number.
- A **down** door is not a bug in the list: it means that app was launched before the table
  existed, or is not running. Relaunching it is a separate step and is never done for you
  while the desk is in a call.
- An agent has a door only while a pane really holds it. A roster figure nobody runs has no
  pane, so it has no door.

## If it does not work

- **Every app door says down.** The apps were started before this change; relaunch one and its
  port appears. Check with `curl -s http://127.0.0.1:9411/json/version`.
- **The page lists no agents.** herdr holds no pane with an agent in it, or the herdr CLI is not
  on the gate's PATH. Check `herdr pane list`.
