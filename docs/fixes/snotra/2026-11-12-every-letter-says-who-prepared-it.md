# snotra · 2026-11-12 — every designed letter says it was made with Ymir, and by which agent

## Files
- `systems/snotra/services/letters/letter-design.py` — `made_by_line()`, the line under the footer, its header
  field `made_by:`, and two self-test proofs

## Why
The operator, 2026-11-12: *"I would like to have in the template also that it's actually Ymir and the agent name who
is making it at the bottom"* and *"for the house design I would like to have this in the template always."* A letter
an agent prepared did not say so, and Rule 44 asks every agent to say whose it is.

## What changed
Every letter rendered by `letter-design.py` now ends with a small line under its footer:
`Made with Ymir by <agent>`. The agent's name is the seat's sealed `primary=` from
`~/.pi/agent/extensions/.ymir-seat` (or `YMIR_AGENT_NAME`), so each operator's letters carry their own agent's name
and no name ships in this repository. The machine is never named (Rule 39). A letter can replace the line with
`made_by: <text>` or remove it with `made_by: off`. This is the operator asking for it on his own letters; it is not
an attribution line in code or a commit (Rule 53 is unchanged).

## Proof
`python3 systems/snotra/services/letters/letter-design.py --self-test` → `ok (14 types × 7 themes)`, including the
two new checks: the line names the agent, and `made_by: off` removes it. A real letter rendered on a sealed seat
ended with `Made with Ymir by <that seat's agent>`; an unsealed seat prints `Made with Ymir` alone.
