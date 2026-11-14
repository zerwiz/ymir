# Find the agent by its work — `seat-find`

Every live agent pane is a screen, and the screen says what that agent is actually working on. This
door reads them and names the panes that printed your words, so you brief the right worker instead of
the one whose tab title looks close enough.

## What it is

`bin/seat/seat-find.sh` asks herdr for every pane that carries an agent, reads each one's recent
output, and prints one row per matching pane: the pane, the agent, its status, which of your words
matched, the last matching line, and the pane's title.

It answers the question the hall got wrong once: a tab title is what someone typed when the pane was
opened; the screen is what the agent knows.

## What you need

- `herdr` on this machine, with agents standing in it.
- A word or two that only that work would print — a client, a file, a phrase from the brief.

## The commands

| Command | What it does |
|---|---|
| `bin/seat/seat-find.sh "<words>"` | panes that printed **every** one of the words |
| `bin/seat/seat-find.sh "<words>" --any` | panes that printed **any** of them |
| `bin/seat/seat-find.sh "<words>" --lines 800` | searches further back in each screen (default 400) |
| `bin/seat/seat-find.sh "<words>" --all` | includes your own pane |
| `bin/seat/seat-find.sh "<words>" --exclude <pane>` | skips one more pane |

The answer:

```
seat-find[2]{pane,agent,status,match,line,title}:
  "<pane>","<agent>","<status>","<words matched>","<the last matching line>","<title>"
help: own pane <pane> was skipped — `--all` includes it
```

## Limits

- It reads a bounded window of each screen (`--lines`, default 400). Work that scrolled further back
  is not found; raise the window.
- Words are matched literally, case is ignored, and a multi-word query is split on whitespace. `a.b`
  is a dot, not a wildcard.
- Only panes with an agent are searched. A bare shell is not a worker.
- Your own pane is skipped by default, because the words you are searching for are usually in your
  own scrollback. `--all` includes it.
- A pane that cannot be read is named in the help line and counted. "No match" and "could not look"
  are never the same answer.

## If it does not work

| What you see | What it means |
|---|---|
| `seat-find[0]` and exit 1 | nothing printed those words; try `--any`, fewer words, or `--lines 800` |
| `help: N agent pane(s) could not be read (…)` | those panes are gone or unreadable; the rest were searched |
| `no agent stands in any pane of this herdr` | there is nothing to search on this machine |
| exit 3 | herdr did not answer at all |

Fix notes: `docs/fixes/seat/2026-11-14-the-find-door-reads-the-work.md`.

## CHANGE LOG

- 2026-11-14 — written with the change it describes (plan 293 part 6).
