# The ward measured what it was told, not what was there

**Date:** 2026-11-10 · **Component:** ward · **Door:** `bin/ward/security-audit.sh`

## What was wrong

The Allfather: *"fix all the problems"* — and three of the fifteen were the ward's own fault.

1. **It reported ssh as open to the world without looking.** The ssh finding's remedy said *"ufw allows 22
   from ANY source"* as a fact, but that text was hardcoded beside the LISTEN check. The real `ufw status`
   carried `22/tcp ALLOW <the LAN subnet>` and `22/tcp on tailscale0` — **narrow**, and no world rule at all.
   A ward that asserts the firewall is a ward that cries wolf twice a run.
2. **It read the base sshd file and never the drop-ins.** `PasswordAuthentication` was `no` in
   `/etc/ssh/sshd_config.d/10-omarchy-hardening.conf` *and* `10-ymir-ward.conf`, which sshd reads after the
   base file. The ward looked only at the commented line in `/etc/ssh/sshd_config` and reported "the password
   policy is at its default" — on a machine with password login off.
3. **It counted sockets that are not doors.** `0.0.0.0:*` is an ephemeral or raw socket with no port to
   knock on; six of the "unnamed wide bind" findings were that.

## What was forged

- **ssh is measured, not assumed**: an unrestricted `dport 22` rule is a finding; a source-restricted one is
  a NOTE saying the bind is wide and the wall holds.
- **the drop-ins are read** (`/etc/ssh/sshd_config.d/*.conf`), and the last word wins, exactly as sshd
  resolves it.
- **a portless socket is skipped** — no port, no door.
- **the operator's word is a source**: `$YMIR_HOME/config/declared-ports.txt`, one line per port with a
  reason. A declared wide bind becomes a **note**, printed on every run so the reason is read as often as the
  findings are. Undeclared wide binds stay findings, as they should.
- notes are **printed**, one line per port (an IPv4 and IPv6 socket are the same door).

## What was mended on the machine, by hand

- one `ufw allow from <subnet> to any port 22 proto tcp` rule — the LAN rule named a **different** subnet
  from the one this laptop is on, so **LAN ssh was blocked** while the rule said otherwise. Both subnets are
  allowed now, and the addresses stay in the home where private addresses belong (RULES/04 · RULES/39).
- `chmod 600 hodd/secrets/platform.env.age` — the vault ciphertext was `-rw-r--r--`, readable by every user
  on the machine. The two preserved conflict copies were set the same.

## Verified

```
$ bin/ward/security-audit.sh check
security-audit[1]{severity,what,detail,remedy}:
  "none","","nothing above the floor","—"
security-audit-notes[4]{port,process,why}:   # 22 · 22000 · 4322 · 53317, each with its reason
```

`bin/agents/eir-doctor.sh check` → `ward ok`.

## CHANGE LOG

- **2026-11-10** — the three false findings, the stale LAN rule, and the world-readable vault.
