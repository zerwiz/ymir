# The desk survives a death — the five failsafes

## What it is

On 2026-11-17 at 07:20:59 the kernel's out-of-memory killer took **one** process inside the desk's cgroup
and systemd restarted the desk. Every pane came back as a bare shell and `herdr agent list` still said
*idle*. Twenty-seven agents died with one death, and nothing told the operator.

These five failsafes make the next death small, noticed, and spoken.

| # | Failsafe | The door | What it does |
|---|---|---|---|
| F1 | the desk keeps a ceiling | `bin/seat/desk-ceiling.sh` | bounds the desk's memory and stops systemd killing the whole desk for one child |
| F1 | each hand in its own cgroup | `bin/seat/agent-scope.sh` | a kill stays local to one agent |
| F2 | a restart is noticed | `bin/seat/desk-inventory.sh` · `bin/seat/desk-watch.sh` | records who stands where, then raises or **names** what a restart emptied |
| F3 | the arm cannot be held by a watcher | `bin/voice/rodd-arm.sh hold` | refuses a holder with no agent in its process tree |
| F4 | a stale mouth is freed at once | `bin/notify/telegram-transport.sh` | releases a dead Telegram transport instead of waiting ~40 s |
| F5 | the death is spoken | `bin/seat/desk-notify.sh` | one Telegram line naming what died and what still stands |

## What you need

- Linux with a **systemd user manager** for F1's ceiling and the per-agent scopes. Without one, the scope
  door says `clean skip` and names the failsafe as absent — it never pretends.
- `herdr` for F2 (panes are herdr's), and `journalctl` for F5.
- Nothing else. The doors read the machine; they do not need a session to be open.

## Do it

**Give the desk a ceiling** (sized from this machine's own numbers, applied live, no restart):

```bash
bin/seat/desk-ceiling.sh choose     # the measurement and the arithmetic
bin/seat/desk-ceiling.sh apply      # drop-in + set-property; nothing is restarted
bin/seat/desk-ceiling.sh --check    # exit 0 only when a ceiling is in force
```

**Record who stands where, and read the truth about it:**

```bash
bin/seat/desk-inventory.sh save       # snapshot the panes holding a LIVE agent
bin/seat/desk-inventory.sh check      # per pane: live, or a shell in an empty room
bin/seat/desk-inventory.sh lost       # what the snapshot had and the machine no longer has
bin/seat/desk-watch.sh check          # ONE line naming every lost pane
```

**Bring a hand back** (bounded on purpose — 27 at once would swap the machine to death):

```bash
bin/seat/desk-watch.sh raise --limit 1
```

**Arm the clock** (a pass a minute: snapshot, name, speak, free a stale mouth):

```bash
bin/seat/desk-watch.sh install-units
systemctl --user daemon-reload && systemctl --user enable --now desk-failsafe.timer
```

**Speak a death, or replay one:**

```bash
bin/seat/desk-notify.sh check
bin/seat/desk-notify.sh replay --since "2026-11-17 07:19" --until "2026-11-17 07:23" --dry-run
```

**Free a stale Telegram transport:**

```bash
bin/notify/telegram-transport.sh status       # who holds the mouth, and is that pid alive
bin/notify/telegram-transport.sh release      # refused outright if the holder is alive
```

## Limits

- **`hdr agent start` is not scoped.** herdr starts those harnesses itself, so that road is bounded by the
  desk's ceiling but not by a per-agent scope. The `run` road and every re-raised pane are scoped.
- **The timer does not raise.** Whether a pane comes back as an agent after a restart is the operator's
  decision (plan 001 §6); the tick names the lost panes and stops there.
- **A pane with no session path cannot be re-raised.** It is named, not resurrected.
- **One message per event.** The notifier hashes the composed line; the same death replayed is
  `suppressed`. A different death is a different line.
- **The ceiling does not restart the desk**, so `OOMPolicy=continue` lands at the unit's next start; the
  memory limits land immediately.

## If it does not work

A door that cannot answer says why instead of failing silently. Read its line:

```bash
systemctl --user show herdr-server.service -p MemoryMax -p OOMPolicy    # F1: infinity = no ceiling
bin/seat/desk-inventory.sh check                                        # F2: 27 claimed, 27 shells = the dead desk
bin/seat/desk-ceiling.sh choose                                         # the numbers it would use, and the peak it read
bin/voice/rodd-arm.sh hold                                              # F3: refused? it says which fact is missing
bin/notify/telegram-transport.sh status                                 # F4: STALE means the recorded pid is gone
journalctl -k --since -2h | grep -E "Out of memory|oom-kill"            # F5: what the notifier reads
```

## CHANGE LOG

- **2026-11-17** — the page was written for the change that made it true (plans 001–005, 312).
