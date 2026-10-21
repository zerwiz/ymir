## ward · 2026-10-21 — the model in the response path, and the three fences around it

### Why
The Allfather's own idea, said twice until it was heard: *"we need to have so the agent can stop and
counter attack… so we need to start an AI model then."* Detection without a response leaves the door
open; a response that is only a rules table covers only what someone thought of in advance. So the
model enters the response path — and the whole question becomes fences.

### The shape
A HIGH/CRITICAL finding with **no written rule** is put to the advisor once. It may answer one of the
six allowlisted bites or `none`, in one short line, from **metadata only**. The proposal is validated
against the allowlist and then against the classes **armed** in `garmr-rules.yaml`; the deterministic
layer records the intent with its undo and performs the act. A finding that a rule already covers
never reaches the model at all.

### The three fences
1. **Metadata only** — class · severity · pid · port · path · destination. Never a payload: an
   attacker who can put text in front of a model can steer the defence, and the cheapest attack on a
   machine that bites is to make it bite its own door.
2. **The allowlist is the whole vocabulary** — six bites or `none`; anything else is discarded and
   said so, because an answer we cannot place is not advice.
3. **The rules remain the policy** — an unarmed class is refused even when the model is certain, and
   the refusal names the one edit that would change the answer.

### Switched, named, and off by default
`hound.model: on|off` in the guardian config (default **off**), and `hound.model_name` names the
model — the small local summariser by default, because the rail holds one model and an advisor must
not evict the Allfather's work for longer than a triage.

### Verified
`bin/ward/garmr-bite-test.sh` → **15/15**, including the two that matter here: an unarmed class
refuses with the advice in hand, and an armed class bites with **no model in the loop at all**.

### Files
- `bin/ward/garmr-bite.sh`
- `bin/ward/garmr-bite-test.sh`
- `README.md` (the Garmr section now says the same thing in the front door's voice)
