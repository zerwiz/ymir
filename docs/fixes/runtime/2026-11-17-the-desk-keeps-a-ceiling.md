# The desk keeps a ceiling, so one heavy hand stops taking every hand

**2026-11-17 · component: runtime · plan 001 §4 F1 (the dead desk)**

## What happened

At 07:20:59 the kernel's out-of-memory killer fired on the heart with swap down to 216 kB of 4 GB. It
chose one process — `opencode`, pid 69583 — but that process lived inside the cgroup of
`herdr-server.service`. systemd answered by stopping the unit with `result 'oom-kill'` and restarting
it, and 27 panes came back as bare shells. One death took every hand.

Two facts made that possible, and neither was a mystery after the fact:

- `systemctl --user show herdr-server.service -p MemoryMax` printed `infinity`. The desk had reached a
  4.8 GB peak with 965 MB of swap and nothing bounded it.
- `-p OOMPolicy` printed `stop` — systemd's default for a service. A *single child* killed by the OOM
  killer was therefore treated as the unit's death.

## What was forged

`bin/seat/desk-ceiling.sh` — the ceiling, sized from what the machine measures at the moment it runs,
never from a number in a document: `MemoryHigh` = 30 % of `MemTotal`, `MemoryMax` = 40 %, `MemorySwapMax`
= 25 % of swap. It prints the measurement and the arithmetic beside the properties, so a ceiling nobody
can explain cannot be set.

It writes the durable half as a **drop-in** (`~/.config/systemd/user/herdr-server.service.d/20-desk-ceiling.conf`)
because the seat-keeper rewrites the unit file itself; a ceiling written inside that file would be lost
the next time the keeper ran. The drop-in also carries `OOMPolicy=continue`, which is the second half of
the fault: one child's death must not stop — and so restart — the desk.

It applies the limits **live** with `systemctl --user set-property`, and never restarts anything. A
failsafe that needs the death it prevents to take effect is not a failsafe.

`bin/seat/agent-scope.sh` — each errand's hand in its own cgroup: `systemd-run --user --scope` with
`MemoryHigh` 10 % of `MemTotal`, `MemoryMax` 15 %, `MemorySwapMax` 12.5 % of swap. `bin/seat/herdr-run.sh`
now wraps the command it seats in a pane with this door, so a kill is local. Where there is no systemd
user manager the door says so and runs the command unwrapped — a clean skip names the failsafe as
**absent**, rather than pretending.

## What it proved, on the heart

```
apply:   set-property: MemoryHigh=3560M MemoryMax=4747M MemorySwapMax=1023M on herdr-server.service (no restart)
show:    MemoryMax=4977590272 OOMPolicy=continue MemoryHigh=3732930560 MemorySwapMax=1072693248
stress:  ./bin/seat/agent-scope.sh --high 3000 --max 128 --swap 0 -- python3 eat.py
         bash: line 1: 935733 Killed  ...   scope_rc=137
after:   MainPID=1155541 (unchanged)  MemoryPeak=1517469696 (unchanged)  unit: active
         herdr status: client version 0.7.4, protocol 16   panes_still_claimed=27
```

The hand that ate past its own limit died inside its own scope. The desk did not move: same main pid,
same peak, still active, still answering.

## What is not closed

`hdr agent start` (the `agent|eindri` road) starts the harness itself, and herdr owns that process, so
that road is bounded by the desk's ceiling but not by a per-agent scope. The residue is named here rather
than hidden: the `run` road and every re-raised pane are scoped; the `agent start` road is not, until
herdr offers a place to put the scope.

## Where the proof lives

`bin/seat/tests/test_desk_failsafes.sh` asserts the arithmetic and the drop-in on every run.
