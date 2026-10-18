# The ward — is this machine secure, and did anything try to get in?

> **Status: built and tested (2026-10-18).** `bin/ward/security-audit.sh` (the eyes),
> `bin/ward/verdr.sh` (**Vörðr**, the warden), `bin/ward/harden.sh` (the mends), and the
> `ward` surface of Eir. Law: `RULES/24-the-ward.md`. Tests: `.agents/tests/ward.test.sh`
> (16 checks, fixture-driven).

## What it is

A warden, because the house had 16 laws for its agents and none for its doors. On the day it was
built, an agent measured this machine and found a **public tunnel answering 200 with no login**,
ssh on every interface with password authentication at its default, a control plane allowed from
**any** address, the vault's key world-readable, and **nothing watching the host**.

**Vörðr does not open or close doors.** He looks, he records, and he says what the mends would be.
Closing a door that could close behind you is the operator's decision.

## What you need

Nothing beyond the repo (`bash`, `python3`, and `curl` for the tunnel probes). `harden.sh --sshd`
and `--ufw` need root; the audit reads an effective `sshd -T` only when run as root, and says so
when it cannot.

## The commands

```sh
bin/ward/security-audit.sh check          # the eyes: ports · ufw · sshd · tunnels · secrets · watchers
bin/ward/security-audit.sh check --quiet  # only speak when something is wrong
bin/ward/verdr.sh report                  # the warden walks, prints, and writes the report
bin/ward/verdr.sh last                    # the newest written report
bin/ward/harden.sh plan                   # every mend, with its risk and its revert line
bin/ward/harden.sh apply --ssh-keys-perm  # secrets at rest -> 0600          (safe, no root)
bin/ward/harden.sh apply --sshd           # keys-only login (backup, validate, rollback on failure)
bin/ward/harden.sh apply --ufw --i-will-not-travel-blind   # REFUSED without that flag, on purpose
```

**Exit codes:** the audit is `0` when nothing is above the floor and **`1` on a HIGH or
CRITICAL** — which is how it becomes Eir's `ward` surface: a house with an open door is never
reported green.

**Where the report goes:** `$YMIR_HOME/hodd/memory/ward/YYYY-MM-DD.md` — a new file each time,
never an edit. A HIGH also speaks on the desktop (`ymir-say`).

## What it looks for

| class | what it means |
|---|---|
| **a public door without a login** | a tunnel whose hostname answers 2xx/3xx with no auth challenge — **CRITICAL** |
| **a port allowed from anywhere** | a `ufw` rule with no source and no `tailscale0` — **HIGH** |
| **ssh that would let somebody in** | `PasswordAuthentication yes`, `PermitRootLogin yes`, or **no key authorized at all** (CRITICAL: turning passwords off would lock you out) |
| **an unnamed wide bind** | a socket on `0.0.0.0` nobody wrote a reason for — MEDIUM (loopback and the known-benign are skipped) |
| **secrets at rest** | a plaintext secret or the vault key that is not `0600` |
| **nothing watching** | no fail2ban/CrowdSec/lynis/AIDE/osquery/Falco installed — **HIGH**: nobody would notice |

## Limits, stated plainly

- **It measures, and reports; it does not defend.** CrowdSec or fail2ban, a file-integrity baseline
  and a vulnerability scan are plan 81's S2–S5, not this page.
- **Not every source is available unprivileged**: the effective `sshd -T`, Docker's own `iptables`
  chain and `/etc/ufw` in full want root. The audit says which ones it could not read instead of
  guessing.
- **The varlist is deliberate**: mDNS, tailscaled's port, browser sockets and Docker's internal
  bridge are skipped, because a report full of noise is a report nobody reads.
- `harden.sh apply --ufw` is **refused** without the explicit flag: this box travels, and the
  tailnet road must be proven before the world's door is deleted.

## If it does not work

| symptom | cause | do |
|---|---|---|
| `ward` is red but the report looks fine | a HIGH remains | `bin/ward/verdr.sh last`, then `bin/ward/harden.sh plan` |
| `unknown (timedatectl absent)` | no systemd-timesyncd | `bin/time/sol.sh check` names it; the clock matters to every record |
| the audit cannot read `sshd -T` | not root | `sudo bin/ward/security-audit.sh check` |
| a tunnel probe says "could not probe" | offline, or no `curl` | run it from a machine that can reach the internet |
