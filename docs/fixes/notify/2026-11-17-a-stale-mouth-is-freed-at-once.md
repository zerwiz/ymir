# A stale mouth is freed at once, not waited out

**2026-11-17 · component: notify · plan 001 §4 F4 (the dead desk)**

## What happened

pi-telegram records the session that holds the Telegram transport by pid, in its own
`~/.pi/agent/tmp/pi-telegram/state.json`. After the 07:21 death that file still named pid `3599906`:

```
"transport": { "pid": 3599906, "cwd": "/home/zerwizserver", "instanceId": "3599906:1794713853068", … }
```

`ps` said the process was gone. The next session to want the mouth waited out its full timeout (~40 s,
measured that morning) before attaching to a transport nobody held — and the operator's conversation was
simply silent in the meantime.

## What was forged

`bin/notify/telegram-transport.sh` — `status` / `release` / `--check` on exactly one key of that document:
`profiles.<profile>.transport`.

- The recorded pid is **not alive** → the record is removed **at once**, atomically, and everything else in
  the document is copied byte for byte (a half-written `state.json` would be a worse fault than the one it
  fixes).
- The recorded pid **is alive** → the door **refuses** and names it (exit 3). A live holder is never
  released by another session.

`bin/seat/pi-launcher.sh` runs the release before `exec pi` in every script it writes, so the stale
record is gone before the extension reads it. That is the whole fix: the mouth is never contended, so the
40-second wait never starts.

## What it proved, on the heart

```
BEFORE:  transport_pid= 3599906      ps says: gone
RELEASE: "default","yes","0.00","the recorded pid 3599906 was not alive — released at once, no wait"
         real 0m0.038s
AFTER:   "default","","no","none — the mouth is free"
         transport key present: False     workspace key still present: True
```

Thirty-eight milliseconds for the whole call, and the next session claims the mouth immediately because
nothing claims to hold it.

## What is not closed

The pi-telegram extension is not Ymir's code, so the door cannot change how the extension itself treats a
stale transport — it removes the stale record before the extension looks. A future extension that clears
its own dead transports would make this door redundant, and that would be a good day.

## Where the proof lives

`bin/seat/tests/test_desk_failsafes.sh`: a dead pid is released and the rest of the document survives; a
live pid is refused with exit 3 and stays recorded.
