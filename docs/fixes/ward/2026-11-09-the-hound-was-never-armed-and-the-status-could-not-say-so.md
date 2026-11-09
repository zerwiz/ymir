# The hound was never armed, and the status could not say so

**2026-11-09 · component: ward**

## What was found

`eir` reported the ward surface broken with no detail, and `garmr.sh status` printed
`audit rules armed 0 — 0 (or no sudo)`, `judged 0`, `heartbeat never`. Both were half true.

- The **hound had never been armed** on this seat: no audit rules for the sensitive shelves, so nothing was
  ever noticed, judged or recorded.
- The **status could not ask the kernel.** It queries with `sudo -n`, and a seat without passwordless sudo
  will never answer — so it printed "0 (or no sudo)" even after 24 rules were in fact loaded.

## What was done

Arming, once, as root: `bin/ward/garmr.sh install` writes the rules for the meetings, the evidence, the
secrets and the operator's own autostart/user units to `/etc/audit/rules.d/ymir.rules`, loads them with
`augenrules --load`, and seats `garmr-arm.service` and `garmr-hound.service`. Measured afterwards with
`auditctl -l`: **24 ymir rules in the kernel**, both units `active`.

One attempt to make the status read a *recorded* count at arming time was written, seen to write its record
to `/garmr-armed` at the filesystem root (no state dir was named in that context), and **reverted** — a guard
that writes to `/` is worse than one that under-reports.

## What is still owed, and how it must be built for the fleet

1. **The status must distinguish "not armed" from "cannot ask".** It does neither today. The correct shape is
   a third answer — `unknown (this seat cannot read the kernel without sudo)` — and `eir` must treat that as a
   **clean skip with its reason**, never as a pass and never as a fault (RULES/25). A seat with no auditd at
   all must print the same kind of skip, by name.
2. **A waiver shelf, because the audit has none.** `bin/ward/security-audit.sh` reports fifteen findings
   unconditionally — a wide bind, a LocalSend port open to the network, sshd's compiled default password
   policy — and its own remedy text says *"write down why it listens on every interface"*. There is nowhere
   to write it. The shape is the one this house already uses in three places (`\.module-test\.allow`,
   `allow-house-word:`, `YMIR_SKIP_*_GUARD`): a data file of deliberate findings with a reason and an end
   date, read by the audit, printed as `waived (reason)` and counted apart from the faults. Every user on
   every role records their own machine's deliberate choices there; nothing is hardcoded to this box.
3. **`eir`'s counter says two when it prints one.** The summary line and the row list disagree; the count is
   the thing an operator trusts, so it must be derived from the same rows it prints.

## Why this is written here and not patched blind

Each of the three is a change to a guard that judges a machine, and a guard changed in a hurry is how a red
goes green without being fixed. They are recorded with their shape so the next hand — on any role, for any
user — implements them once, testably, rather than three times by ear.

## CHANGE LOG

- **2026-11-09** — Opened with the arming, the measured 24 rules, the reverted record attempt, and the three
  owed pieces written in the fleet-safe shape.
