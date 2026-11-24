# An unseated Eindri reads READY, not DOWN

**Component:** hlidskjalf (plan 369, item 4)

## What the operator saw

The Forge showed all 25 Eindri as **DOWN** in red, the three live panes as NOMINAL, and the topbar
said `Fleet 3/28` in amber. It looked as though the forge had fallen over.

## The cause

The label was wrong. No probe was broken. `bin/desktop/hlidskjalf-agents.sh` reads herdr's live panes
correctly, and measured this evening it found 7 seated agents of 32. Since plan 275 item 9 it has
marked a roster figure with no pane as `down`, so that it is never called NOMINAL. That was right to
stop, but the board had only three words (NOMINAL, DEGRADED, DOWN). "Not in a pane right now" therefore
wore the word and the red of a fault.

## What changed

- The connector emits `idle` for an unseated figure, and the board shows it as a **READY** chip in the
  info tone. NOMINAL still means a pane holds the agent, and nothing else.
- `AgentStatus` gains `idle`. The Fleet modal shows it in the info tone.
- The topbar Fleet chip keeps its count (seated of roster). It is red only when an agent is `down`,
  amber when one is degraded or none is seated, and green otherwise.

## Proof

- `tsc --noEmit` passes.
- The connector now prints 25 `idle` and 7 `nominal`, where it printed 25 `down` and 7 `nominal`.

The Stream's "no live events yet" is a separate matter. The SPA's proxy logged a socket hang-up on
`/api/stream` at 21:09, two minutes after the gate restarted, and the stream reconnects on its own.

## CHANGE LOG

- 2026-11-24 — review-mend: added missing heading for #934
