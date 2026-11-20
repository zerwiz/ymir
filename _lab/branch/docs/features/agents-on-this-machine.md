# Agents on this machine — the census

## What it is
`bin/agents/agent-census.sh` tells you exactly what is running on this computer: every coding-agent session (Claude,
Pi, OpenCode, Codex…), every herdr pane, which errand panes have already finished their work, which sessions run
outside herdr, and how many worktrees the repo carries. The session that holds the arm reads it at every start.

## What you need
Linux (`/proc`); herdr is optional — without it the herdr line says `skip`.

## Do it
```bash
bin/agents/agent-census.sh            # the full table
bin/agents/agent-census.sh --digest   # the short lines the session digest prints
bin/agents/agent-census.sh --json
```

## Limits
It reads; it never closes a pane or removes a worktree. `STALE_PANE` means the errand in that pane reported
`done`/`failed`/`needs-decision`/`paused` and no agent is detected there — closing it is your call.

## If it does not work
No herdr lines: `herdr status`. Zero worktrees: run it from inside the repo checkout.
