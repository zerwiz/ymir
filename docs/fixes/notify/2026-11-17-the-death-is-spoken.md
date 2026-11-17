# The death is spoken — one line, not a discovery hours later

**2026-11-17 · component: notify · plan 001 §4 F5 (the dead desk)**

## What happened

The desk died at 07:20:59 and **nothing said a word**. The kernel had recorded it, systemd had recorded it,
and the panes were still claiming to be agents. The operator found out hours later by asking why his
Telegram conversation had vanished. A machine that dies in silence lies by omission.

## What was forged

`bin/seat/desk-notify.sh` composes **one** line from the machine's own record:

- the kernel's sentence — `journalctl -k`, "Out of memory: Killed process …" (process, pid, cgroup, time);
- systemd's verdict — "Failed with result 'oom-kill'" and which unit;
- the panes a restart emptied — read from `bin/seat/desk-watch.sh check`, which asks `/proc`, not the desk.

It speaks through `bin/notify/send.sh` — the one door that owns Runes, the arm, the desktop, the pocket and
Telegram — at `CRITICAL`, and it says each death **exactly once**: the composed line is hashed into
`<state>/desk-notify.seen`, so a replay of the same event is `suppressed` and says so.

`replay --since … --until …` exists for exactly this kind of proof: the 07:21 event can be re-fed to the
door without waiting for another death. `YMIR_DESK_NOTIFY_SINK` writes the message to a file instead of the
door, so a test or a replay can never alarm the operator.

## What it proved — the 07:21 event, replayed

```
$ ./bin/seat/desk-notify.sh replay --since "2026-11-17 07:19" --until "2026-11-17 07:23"
"said — one message (sink)"
"the kernel OOM killer took opencode (pid 69583) at 2026-11-17 07:20:59; systemd failed with result
 oom-kill: herdr-server.service; the desk lost 25 hand(s) to a restart — panes wV:p1 w18:p1 … w22:p1
 hold shells, not agents; 0 agent(s) still stand"

$ same replay again
"suppressed — already said"

$ wc -l < sink    →  1
```

One message, naming what died, which unit failed and how, and what still stands. The second run of the
same event is silent.

## What is not closed

The `desk-failsafe` timer that would run this every minute is registered in `config/units.yaml` but **not
enabled** on the heart: its first tick would speak yesterday's death again, and re-announcing a death the
operator already knows about is noise. Enabling it is one command
(`bin/seat/desk-watch.sh install-units`, then `systemctl --user enable --now desk-failsafe.timer`) and it
is named as owed rather than done quietly.

## Where the proof lives

`bin/seat/tests/test_desk_failsafes.sh`: the same death is said once and suppressed the second time.

## CHANGE LOG

- 2026-11-17 — review-mend: added missing heading for #814
