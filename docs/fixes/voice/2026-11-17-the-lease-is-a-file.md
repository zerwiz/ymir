## voice · 2026-11-17 — the lease is a file, not a feeling

### What was wrong

A project's right to spawn hands lived in a conversation. A claim that looked alive held the machine all morning with nothing behind it, and no one could read, renew or reclaim it — because there was nothing to read.

### What the door does now

One row per lease, one file, in the state the arm already uses:

```
<state>/.arm.leases       lease{n,holder,machine,scope,hands,granted,expires,heartbeat}
<state>/.arm.leases.log   the append-only journal of every grant, renew and reclaim
```

`bin/voice/arm-lease.sh` owns the table and its verbs:

- `grant <scope> [--holder H] [--machine M] [--hands N] [--ttl S]` writes one row;
- `renew <n>` moves the heartbeat and the expiry of a **live** lease, and refuses a dead one (a renewal of a dead claim would invent authority);
- `reclaim <n>` is the machine taking a lease back, and it needs **nobody's permission**: a stopped heartbeat is the permission. A **live** lease is refused, because reclaiming a living claim is theft;
- `list`, `alive <n>`, `who` and `--check` read it;
- `authority [<scope>]` names the authority a spawn may use here, and why;
- `ranks [--line]` prints who holds what, and which rank this seat holds.

Rules the table keeps: one writer (a mkdir lock and a temporary file, so two grants in the same second cannot lose each other); nothing is deleted from the record (a reclaim removes the row from the table and appends the event to the journal); a lease number is never reused.

The two numbers the Allfather has not ruled on yet (plan 310 §7.2) are one constant each, overridable from the environment: **two hands** (`YMIR_ARM_LEASE_HANDS`) and **one hour** (`YMIR_ARM_LEASE_TTL`). A lease is reclaimable after **300s of silence** (`YMIR_ARM_LEASE_STALE`).

`bin/voice/rodd-arm.sh lease <verb>` is the alias, so a caller that already talks to the arm need not learn a second path to the same record.

### Files

- `bin/voice/arm-lease-lib.sh` (new — the table, its laws, the authority and the ranks)
- `bin/voice/arm-lease.sh` (new — the door)
- `bin/voice/rodd-arm.sh` (the `lease` verb)
- `bin/voice/tests/test_arm_lease.sh` (new)

## CHANGE LOG

- **2026-11-17** — Opened: the lease is a row in a file the machine can read, renewed by heartbeat and reclaimable without asking anyone.
