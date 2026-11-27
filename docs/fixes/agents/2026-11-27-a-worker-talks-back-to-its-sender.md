# A worker talks back to its sender

## What went wrong

A dispatched worker was told to write a report file and a question file. Its sender learned of either only through a
wake about a file. The brief did not name the sender, and a bare `reply.sh` in a new worker had nobody to answer. A
dispatch from a script, or from a session with no pane, stamped a sender with no road back.

## What changed

- `bin/agents/sender.sh` records the sender of each errand at dispatch and writes the brief section that names it.
- `eindri-start.sh`, `herdr-run.sh eindri`, `einherjar-spawn.sh` and the engine call it. `--sender` carries a sender
  in from another machine. A review judge answers the sender of the judged errand.
- `eindri-acclaim.sh` sends each new terminal line to that sender.
- `reply.sh --errand` answers the recorded sender, and `reply.sh --ask` files a question and sends it in one act.
- A sender with no pane is answered through its machine's arm holder, also for `fleet-tell.sh` lines.

## Proof

`bin/agents/tests/test_sender_direct.sh`: a stand-in worker goes down each road, and its sender receives the question
and the result while both files are written. The panes, tmux, ssh and the other machine are fakes. No live pane and no
second machine were used.

## CHANGE LOG

- 2026-11-27 — a dispatched worker sends its result and questions to its sender.
