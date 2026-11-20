# Rödd's six hands, and the calendar write door that refuses by name

**2026-11-09 · component: voice**

Rödd had a toolbox of 37 tools and not one of them could reach the house: it could not ask who holds
the arm, list or speak to a herdr Eindri, reach a Sessrúmnir seat, or make and move a meeting. Plan 231
measured it — *"the hands exist — they are simply not the four he wants"*, and *"the calendar has no
write door"*.

## The six hands

```
hands[6]{hand,door,what_it_refuses}:
  "ask who is watching","bin/voice/rodd-arm.sh who","says 'nobody is armed' instead of pretending a session listens"
  "hand one line to the arm holder","bin/voice/rodd-arm.sh tell","a no-arm refusal, never a claimed delivery"
  "list the herdr workers","bin/seat/herdr-agents.py (one reader)","says herdr did not answer rather than inventing a list"
  "send one line to a worker","bin/agents/eindri-send.sh, then herdr agent read","reports the pane's words, never 'it said yes'"
  "reach a Sessrúmnir seat","bin/seat/sessrumnir-wire.sh seats|send|read","names the shell's port and raiser instead of faking a seat"
  "make or move a meeting","systems/snotra/services/calendar/calendar-write.sh","refuses naming calendar.events when the grant cannot write"
```

## The calendar write door

`calendar-ask.sh` reads and refuses to write; there was no create or move at all. `calendar-write.sh`
adds them:

- **the grant is measured, not assumed.** Every write refreshes the vault's calendar grant and asks the
  token itself (`tokeninfo`) what it may do. If `calendar.events` (or the full `calendar` scope) is absent
  it **REFUSES**, prints the scope it wanted and the scopes it found, and names the one command that
  re-mints the grant (`bin/mail/connect.sh google`). Exit 3; nothing created, nothing moved.
- **create goes through the one write door** — `calendar-invite.sh` — so the approval gate that binds the
  operator's word to the exact event body before any attendee is mailed stays the single gate.
- **move is its own PATCH**, because no door had one. It reads the event first and prints the OLD time
  beside the new one, so he can check the move; it mails nobody (`sendUpdates=none`) unless `--notify`
  is given, and `--notify` passes the same approval gate.

Measured on this seat today: the live grant carries gmail.readwrite-ish read/compose, drive.file,
documents and userinfo — and **no `calendar.events`**. So every live `create`/`move` refuses, by name:

```
calendar-write[3]{state,missing_scope,measured,grant}:
  "REFUSED","https://www.googleapis.com/auth/calendar.events","email … gmail.readonly userinfo.email openid","SNOTRA_GOOGLE_REFRESH_TOKEN"
```

## The seat wire

`bin/seat/sessrumnir-wire.sh` speaks three channels on Sessrúmnir's own bridge —
`seat:list`, `seat:prompt`, `seat:last-answer` — added to `apps/sessrumnir/src/web-server.ts`. The wire
enumerates the shell's seats with their state and pid, hands one a line, and reads the last assistant
answer out of that seat's own transcript. When the shell is not running it refuses (exit 3) with the
address it tried and the command that raises it — a seat only answers while the app is alive.

## Proved

- `bash .agents/tests/rodd-hands.test.sh` — all six declared **and** wired; no-arm refusals in words;
  the seat wire refusing a silent shell; the calendar refusing a grant without `calendar.events` and
  never reaching the write door.
- `bash systems/snotra/services/calendar/calendar-write.sh --self-test` — both branches against a
  fixture Google: refusal without the scope, delegation to the invite door with it, a move that reports
  the old time and mails nobody.
- `bash bin/seat/sessrumnir-wire.sh --self-test` — all three verbs against a fixture bridge, then a
  closed port refused with exit 3.

## What this does not claim

The seat wire reaches the **headless web shell** (`:3890`); the Electron desktop app does not serve that
port, so the wire names the shell and the raiser rather than pretending a desktop seat is reachable. The
calendar half cannot be proved live until a re-consent adds `calendar.events` — which is exactly the
refusal the door was built to make instead of a false green.

## CHANGE LOG

- **2026-11-09** — Opened with the six hands, the calendar write door and its scope refusal, the seat
  wire with its three channels, and the proofs above.
