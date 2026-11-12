# Rule 56 — No message is delivered until the receiver speaks

**Added 2026-11-09** at the Allfather's word: *"make a rule in ymir to never assume another agent will read
the other agents message. we are failing with a2a and other tools the only proven are direct contact in
herder panes and a functional gna arm."*

## The law

```
law[4]{rule,why}:
  "A WRITE IS NOT A DELIVERY. A message is delivered when the receiver ANSWERS — a pane that echoes a turn, an arm that drains a wake. Anything else is a letter in a drawer.","tonight's proof: thirty-eight review reports sat unread in a queue for days, and every one of them had 'been sent'"
  "TWO CHANNELS ARE PROVEN, AND ONLY TWO: the herdr pane (a turn spoken into the session that holds the arm) and the Gna arm (a wake the arm drains). A channel not in this list is UNPROVEN, whatever its documentation says.","measured 2026-11-09: a pane injection answered in the same minute; the A2A mesh refused every call for want of a grant (phase 61.2 never landed), and a2abridge is a seat-side adapter with no counterpart on the server"
  "A NEW CHANNEL IS GUILTY UNTIL IT ANSWERS. It ships with the command that proves an answer, and until that command has been run the channel may not be used to carry anything that matters.","a protocol that parses is not a protocol that carries — this house has shipped three 'working' wires that carried nothing"
  "AN AGENT NEVER ASSUMES ANOTHER AGENT READ IT. No handoff 'because they will see the file', no 'the report is on the shelf', no 'the queue is durable so they will drain it'. If there is no answer, the message is NOT delivered and the sender says so plainly.","an assumption is a message with no receiver, and it fails silently — the worst failure a fleet can have"
```

## What counts as an answer

```
proof[3]{channel,what proves it}:
  "the herdr pane","`bin/agents/eindri-notify.sh --from <sender> -- \"<line>\"` prints `injected{pane,owner}` AND the line appears as a turn in that session. A refusal (`pane":"NOT FOUND`) is a NON-delivery and must be reported as one."
  "the Gna arm","`bin/time/saga-wake-drain.sh` prints the wake, then `ack` drops it. A wake that is never drained is not delivered — it is queued, which is a different word."
  "everything else","unproven until its own proof command has answered, and the answer is written down beside it (an audit row, not a claim)"
```

## The duty

Whoever sends carries the proof:

1. send through a proven channel;
2. **say what answered** (`pane":"w2:p3"`, `wake drained at …`), or say plainly that it did not;
3. never close an errand, a handoff or a report on a write alone — the terminal act is not finished until
   the pane has it (see `bin/agents/eindri-acclaim.sh`, which now injects or reports `pane":"failed`);
4. when a channel breaks, that is an incident and a fix note — not a workaround by assumption.

## Why this rule and not a preference

On 2026-11-09 the house counted its channels: the pane door had been built on 2026-11-08 and **was never
called** — every worker wrote a file and a wake instead, and the arm holder read panes. The fix was not a
new protocol; it was making the existing one mandatory and proving it answered. A fleet's worst fault is
not a message lost in transit; it is a sender who believes it arrived.

## Enforcement

- `bin/agents/eindri-acclaim.sh` injects, and prints `pane":"failed — <why>` when it cannot (this rule's
  first teeth).
- `bin/agents/erindi-brief.sh` teaches every errand that a file-only report has reached nobody.
- The audit lives in plan 234 (`plans/234-the-fleets-voice.md`): one row per channel, the command that
  proves it, and whether it answered today.

## CHANGE LOG

- **2026-11-12** — the rule was written on 2026-11-09 as 49, refused with its branch, and delivered here as 56 (49 and 50 were taken while it waited).
