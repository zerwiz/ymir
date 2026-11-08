# agents · 2026-11-08 — the voice could not see the panes, so it guessed at the work

## What

The Allfather asked the voice, four times in one conversation, how many agents were active in herdr —
*"Can you look how many agents are active in Herder?"*, *"Yes, I have like five six"*, *"No, there are
agents active in Herder. How many can't you find them?"*, *"Don't you have a tool? We have tools for her
there."* Each time the voice answered **"no active agents; most are done, stale or failed"**, because the
only hand it had for the question was `errand_state`, which reads this seat's **recorded errand statuses**
(`state/*.status`) — a different question from *what panes hold a live agent right now*.

The panes were there all along: herdr held **22 panes, 6 carrying an agent, 1 working**.

So the door was made, and the voice was given it:

- **`bin/seat/seats.sh brief`** — one table a human, a terminal and a voice can all read:
  `seats[1]{panes,live,working,shells}` then `panes[N]{id,agent,status,cwd}`. It reads herdr's own JSON and
  falls back to tmux. One implementation, no second parser in the tool.
- **`seats` in `bin/voice/voice_tools.py`** (the voice's 35th hand) — the table, or one pane's recent
  output with `seats(pane="w39:p5")`. `pane_read` remains for a second look.
- **both house briefs** (the patched `DEFAULT_INSTRUCTIONS` and the shell's `HOUSE_INSTRUCTIONS`) now say
  plainly that `seats` is the door for "how many agents are working", and that `errand_state` knows only
  this seat's *recorded* errands.

## Why

A voice that answers "nobody is working" while six agents sit in panes is worse than a voice that says it
cannot see: the operator believes the halls are empty and starts work twice. The fault was not the model's
— it had a tool whose name promised more than its body delivered, and no other.

**One implementation detail worth keeping:** the first `brief` printed an empty table because the JSON was
piped into `python3 - <<'PY'` — a heredoc owns stdin, so the pipe streamed nothing. The JSON now goes
through a file, and the reason is written in the comment beside it.

## Verified

- `bin/seat/seats.sh brief` → `seats[1]{panes,live,working,shells}: "22","6","1","16"`, then the panes with
  `w39:p5 pi working ~/ymir` first.
- through the toolbox (the exact path the window's face calls):
  `POST /tool {"name":"seats"}` → the same table, live panes only, and the 16 plain shells summarised.
- in the live page, over Chrome DevTools MCP: `evaluate_script` fetching the toolbox → `35 tools | seats: true`.
- `bash -n bin/seat/seats.sh` clean; the tmux fallback prints its own header when herdr is absent.

## Not verified / owed

- `seats(pane=…)` was exercised against a *named* pane only from the shell, not yet from his voice.
- `errand_state` still cannot say out loud that it knows only recorded errands; the brief now compensates,
  but a line in the tool's own answer would be better.
- Sessrúmnir has **no door at all** for the voice (Electron IPC only): the same class of fault, one app
  further out. Named in plan 132 §43.4 and owed its own face.
