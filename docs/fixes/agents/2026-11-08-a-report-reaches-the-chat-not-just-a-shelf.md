# A report reaches the chat, not just a shelf

**2026-11-08 · component: agents · plan 219 §20**

## What was wrong

`bin/agents/report.sh` wrote `state/eindri-reports/<id>.md`, and the wake library queued a line saying
*"report filed … (handoff failsafe)"*. Nothing ever turned a report into a **turn in the session that
holds the lock**. The Allfather named it exactly: *"why arent they injecting in to your session chat? we
have build that and its not getting used. they are writing handoff in files now instead."* Measured the
same hour: the wake queue held **twelve** such lines, several hours old, every one of them a file that
no session had been told about.

`bin/agents/eindri-send.sh` — the door that speaks a turn into a pane — existed and was never called
for a report. That is the house's oldest wound: a door with no caller.

## What was forged

`bin/agents/eindri-notify.sh` — the arm holder's inbox. It resolves three links and refuses loudly when
any of them is broken:

```
links[3]{link,how}:
  "lock → owner","the seat’s lock record holds the pid of the session that owns the seat"
  "owner → pane","herdr pane process-info over herdr agent list: which pane hosts that pid"
  "pane → turn","bin/agents/eindri-send.sh → herdr agent prompt, i.e. a new turn in that session"
```

`--status` prints `arm-holder[1]{lock_owner,alive,pane}` so a broken link is one command away from being
named. `report.sh write` now ends by injecting its one line, and when nobody holds a pane it says
**"written but NOT injected"** — a silent success would be the same fault it exists to fix.

## Verified

```
bin/agents/eindri-notify.sh --status
  → arm-holder[1]{lock_owner,alive,pane}: "2624809","yes","w3:p1Z"
bin/agents/eindri-notify.sh --from tenancy-keeper -- "tenancy measured in Example3: …"
  → injected[1]{from,pane,owner}: "tenancy-keeper","w3:p1Z","2624809"
  → and the line arrived as a turn in that session, which is the whole point
```

## What it does not do

It does not choose what to say, and it does not retry into a dead pane: no owner, no pane, no
injection, and the report stays on the shelf where the digest reads it. The chat is the delivery, the
shelf is the record, and neither replaces the other.

## CHANGE LOG

- **2026-11-08** — Opened with the door, the wiring in `report.sh`, and one live injection proved.
