# Every ask carries its return address, and a worker cannot end without answering it

Date: 2026-11-24 · Component: agents · Plan 365 (R1 to R4), in the plan 366 pull request

## What was wrong

Workers finished and reported to nobody: the sender polled their panes. The doors existed (`report.sh`, `hermes-tell.sh`, `eindri-send.sh`, the wake road), but nothing made the sender give an address or the worker use it.

## What changed

- R1: `bin/agents/reply-to.sh` resolves a return address (`hermes:`, `herdr:`, `seat:`, `telegram:`, `issue:`) from `--reply-to`, `$YMIR_REPLY_TO` or the caller's own identity, and refuses an ask with none. `einherjar-spawn.sh` and `eindri-dispatch.sh new` take `--reply-to`, keep the address with the errand, and the brief tells the worker to answer it. `ymir work send` writes the sender's address into the issue; intake gives Mjölnir `issue:<repo>#<n>` as the address.
- R2: `bin/agents/answer.sh <errand>` is the one answer door. It needs the seven-field handoff first, sends by the kind of the address, and queues the answer when the sender is busy; `answer.sh retry` (a one-minute Nornir row) lands it once and never resends it.
- A `hermes:` address is answered by a waiter, not a typed line: a line sent into a desktop Hermes session never shows in its chat, so `answer.sh wait <errand>` is started by the sender as a background task at dispatch, blocks until the handoff lands, prints the answer and exits, and that exit is the wake. With no live waiter the answer stays queued and is never reported as handed.
- R3: `.claude/hooks/errand-stop.sh` is a Claude Code `Stop` hook, seated by `harness-extensions-install.sh`: inside an errand with a return address it blocks the stop until `answer.sh guard` passes, and lets go on the second try. The same `answer.sh guard <errand>` is what the pi extension, the opencode plugin and Codex notify must call; those three wirings are not in this change.
- R4: `ymir work` shows queued answers and names a worker silent for two hours or more (`answer.sh silent`).

Everything runs on one machine: the sender and the worker may share it, and `herdr:` or `issue:` answer there.

Proof: `bash tests/test_answer_door.sh`.
