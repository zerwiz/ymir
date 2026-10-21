## ward · 2026-10-21 — Garmr earns teeth in code, and a model may advise but never act

### Why
The Allfather said the thing the plan had only promised: *"we need to have teeth — detection had no
teeth"*, and then drew the line himself: *"we use the model to stop or close doors — it's a counter."*
That is the lawful counter (containment inside our own house), and it needed code, not a paragraph.

### What was built
- **`bin/ward/garmr-bite.sh`** — the containment door. Six bites and nothing else: `egress-block`,
  `listener-close`, `stop-unit`, `kill-process`, `quarantine-file`, `revoke-token`. Each plannable
  bite carries **its own undo command** in the same line, so a guard can never become a vandal.
- **The switch** — `GARMR_BITE=off|report|contain|hard`, read from the guardian config, **shipping at
  `report`**: the hound says what it *would* do before it does anything.
- **The advice layer** — `garmr-bite.sh advise`: the model may choose **one** bite from that closed
  allowlist, or `none`. It never executes; it sees **metadata only** (class · severity · pid · port ·
  path · dst), never the payload, because an attacker's text in front of a model is a way to make the
  defender close the door the attacker wants closed. An answer outside the allowlist is **discarded**
  and said so. `GARMR_ADVISOR_CMD` makes the advisor injectable; empty means rule-alone, the default.
- **`config/garmr-rules.example.yaml`** — the policy is a file you can read: which classes are armed,
  the peers that are never blocked (by name, never by a LAN address), the ports that are doors.
- **`bin/ward/garmr-bite-test.sh`** — 13 assertions, all passing, none of which takes a real bite:
  no rule → no bite · a rule → a plan with its undo · an unarmed class → a bark · `report` acts on
  nothing · `off` barks only · a plan writes nothing · exactly six bites exist · a token is never
  un-revoked · an advisor inside the allowlist proposes · a proposal still needs a written rule · an
  answer outside the allowlist is discarded · no advisor is the safe default.

### The bug this found, and it mattered
`hound: {bite: off}` read as **`report`**, because YAML 1.1 turns bare `off`/`no`/`false` into the
boolean `False` and the resolver treated it as "absent". A safety switch that silently fails *open*
is the worst kind. Both the boolean and the string are now mapped to `off`, and the example config
quotes the value with a comment saying why.

### Verified
`bash bin/ward/garmr-bite-test.sh` → `garmr_bite[2]{passed,failed}: "13","0"`.
`bash -n` clean on both scripts. No real bite has been taken on this machine — the switch is `report`.

### Files
- `bin/ward/garmr-bite.sh` (new)
- `bin/ward/garmr-bite-test.sh` (new)
- `config/garmr-rules.example.yaml` (new)
