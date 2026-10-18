# Security — the ward

**Status:** live, and growing. **Law:** [`RULES/24-the-ward.md`](../RULES/24-the-ward.md).
**Plan:** plan 81, *the ward* (phases S0–S8). **Surface:** the `ward` surface of Eir
(`bin/agents/eir-doctor.sh`).

Ymir has two security halves, and it is honest to name both:

| half | what it protects | state |
|---|---|---|
| **the agent side** | what our own agents may do — secrets, the vault, file deletion, branch pushes | **built** — 16 gate wards, the vault, the airlock |
| **the host side** | the machine's doors, the firewall, intrusion, the network | **built and growing** — Vörðr's audit, the mends, the local-network checks (S0–S8) |

The agent side was law before the host side had eyes. This document is the host side's
doctrine, its checks, and its honest gaps.

---

## 1 · The law — a door is named, or it is closed

From `RULES/24-the-ward.md`:

```
ward_law[7]{rule,what it means}:
  "A DOOR IS NAMED","every socket listening on a non-loopback address has a written reason — where it is documented, for whom, and why it cannot be loopback. An unnamed wide bind is a finding, not a preference."
  "PUBLIC MEANS AUTHENTICATED","anything reachable from the internet — a tunnel, a published port, a tunnel's origin — either asks for a credential or does not exist. The refusal is the feature."
  "THE ROADS ARE THE LAN AND THE TAILNET","ssh answers the LAN subnet and `tailscale0`, never 'any'. The tailnet is the road that works from anywhere; a hotel is not an exception to this."
  "KEYS, NOT PASSWORDS","sshd accepts keys only. A password that crosses a network is a password that can be guessed at leisure."
  "THE AUDIT IS A CRON, NOT A MOOD","the warden reports on a schedule (`bin/ward/verdr.sh`), writes the report where records live, and speaks when something is HIGH. Security that needs a person to start it is not security."
  "SECRETS AT REST ARE 0600","a plaintext secret, or the key that opens the vault, is readable by its owner and nobody else."
  "A MEND THAT CAN LOCK THE OPERATOR OUT IS HIS","the warden writes the command, the risk and the revert line; the Allfather closes a door that could close behind him."
```

Two more obligations ride the ward: **the clock is synchronised** (a record with a
wrong clock is a record nobody can trust), and **the audit is a cron, not a mood** — a
scan a person has to start is not a security system.

---

## 2 · The threat model — the seven surfaces

The ward looks at a house as a person arrives at it: the doors, the wall, the lock, the
posters you publish, what is locked in the drawer, who is watching — **and the road that
leads here.**

```
surfaces[7]{# ,surface,what is asked,measured by}:
  1,"the doors","what listens, on which address, for whom, and why","ss -tulnp · the process behind it"
  2,"the wall","does the firewall actually cover those doors, per source, per protocol family","ufw status verbose · nftables/ip6tables state"
  3,"the lock","how sshd would let someone in — effective policy, not the diff","sshd -T"
  4,"the tunnels","what is published to the world, and whether it asks for a credential","the tunnel configs + an unauthenticated probe"
  5,"the secrets","are plaintext secrets and vault keys 0600, and is the vault encrypted","file modes + the vault's own check"
  6,"the watch","is anything installed to *notice* — ban, integrity, audit, CVE scan","the presence of the watchers (§6)"
  7,"the road","the LAN and the router: who else is here, what the gateway is, and what it hands out","the local-network checks (§5)"
```

Surfaces 1–6 are host-local. Surface 7 is the one most tools never look at — and it is
where a network's real weaknesses usually live.

---

## 3 · What ships today

```
ward_tools[3]{tool,role,changes anything?}:
  "bin/ward/security-audit.sh","THE EYES — measures and reports in TOON; exit 1 on HIGH or CRITICAL. Changes nothing.","never"
  "bin/ward/verdr.sh","VÖRÐR, the warden — walks the house, writes the dated report where records live, speaks one line on HIGH.","never (a report)"
  "bin/ward/harden.sh","THE MENDS, written out as commands with the risk and the revert line. `--sshd` and `--ssh-keys-perm` are safe and validated; `--ufw` refuses without explicit approval.","only on request"
```

They are composed into **the `ward` surface of Eir** (`bin/agents/eir-doctor.sh`), so a
machine with an open door is never reported green.

The ward composes what Ymir already had, rather than replacing it:

| existing part | what it gives the ward |
|---|---|
| the 16 gate wards | refuse a secret, a foreign map, a vault leak, a deleted file, a dead-branch push, an unreferenced door |
| the vault | age-encrypted secrets; the LUKS container (Hnitbjörg) |
| the airlock | a session with every off-vault door shut and `bwrap --unshare-net` for no network at all |
| the ssh ward | key seating from the operator's own GitHub keys, asserted on a timer |
| Runes | the chained, append-only ledger — every significant action already written down |

The pattern is the same one the whole system uses: **a ward that fails loudly, a record
that appends, a mend that is named.**

---

## 4 · How to run it

```bash
bin/ward/security-audit.sh check          # the eyes: TOON report, exit 1 on HIGH/CRITICAL
sudo bin/ward/security-audit.sh           # with root: the EFFECTIVE sshd policy + firewall
bin/ward/verdr.sh report                  # the warden: walk, write the dated report, speak on HIGH
bin/ward/verdr.sh last                    # the newest written report
bin/ward/harden.sh plan                   # the mends, as commands — read before running
bin/agents/eir-doctor.sh check            # the ward as one surface among the house's health
```

Every finding carries a **remedy** in the same row, and every mend carries its **revert**.
Nothing in the ward closes a door by itself: a change to the firewall or sshd is *reported
to* the operator, never made *for* him.

---

## 5 · Surface 7 — the local network and the router

A host can be perfectly hardened and still sit on a road that is not. The ward therefore
extends past the machine to the network it joins. Each check answers a question a
compromised or misconfigured LAN makes urgent:

```
lan_checks[8]{risk,what it looks like,the check}:
  "a lying route","a default route that answers nothing (e.g. an IPv6 route advertised with no service behind it) — silently breaks updates, tunnels and agent traffic","does the default route actually carry traffic? probe per family, fail loudly"
  "plaintext DNS to an unknown resolver","DHCP hands out a resolver that is not ours, and queries travel unencrypted","which resolvers are in use, are they the ones we chose, and is the path encrypted (DoT/DoH)?"
  "a rogue DHCP server","a second box answering DHCP, handing out a hostile gateway or resolver","count distinct DHCP servers and diff the lease's gateway/resolver against the last known-good"
  "ARP / gateway spoofing","the gateway's MAC changes, or one MAC claims several addresses — a man in the middle","pin the gateway's MAC and alert on a change; flag duplicate MACs"
  "a gateway that answers the world","UPnP/IGD enabled (any LAN app can punch a WAN hole), or WPS enabled (PIN brute force)","query the gateway's IGD and read its mappings; read the AP's WPS capability from the beacon"
  "an unmanaged device in the path","an upstream ISP box we do not administer and whose firmware we do not patch","name every hop device and whether it is ours; treat the rest as untrusted"
  "unexpected doors on the LAN","printers, NAS, cameras and IoT with open admin ports","sweep the subnet for listening services and report the unexplained"
  "a weak wireless posture","WPA2 without management-frame protection, or a legacy cipher","read the AP's RSN/WPA capabilities: WPA3, SAE, and PMF where offered"
```

Two honest constraints on all of it:

- **The ward measures the LAN; it does not police it.** Banning a host at the switch is the
  router's job, and on a network you do not administer (a hotel, a café, a client site) the
  only defence is that *this machine's own doors are shut* — which is what surfaces 1–6 are for.
- **The ward never claims a door it cannot see.** A device that answers nothing looks exactly
  like a device that is absent; that is written down as *unverified*, never as *clean*.

---

## 6 · The watchers — what must be installed to *notice*

Detection is the difference between a photograph and a system. Ymir adopts validated
open-source first (Law 8):

```
adopt[8]{tool,what it gives,cost,verdict}:
  "CrowdSec","behaviour IPS: parses logs, bans at the firewall, shares an anonymised blocklist","a service + a bouncer; signals leave the box","ADOPT — or fail2ban where no data may leave"
  "fail2ban","the simplest ssh jail ever written","trivial","the local, silent fallback"
  "Lynis","an audit that names every hardening gap, with a score","read-only","ADOPT — the baseline for 'are we secure'"
  "arch-audit / osv-scanner","which installed packages and lockfiles carry known CVEs","read-only","ADOPT"
  "AIDE or osquery","file integrity: a changed binary, a new SUID, a modified unit","a baseline + a nightly run","ADOPT"
  "auditd with rules","kernel-level: who executed what, who read the vault, who changed a gate","already installed; rules must be written","ADOPT a minimal rule set"
  "trivy / grype","container and dependency vulnerability scanning","CI + a weekly job","ADOPT for images"
  "gitleaks / trufflehog","secrets in git *history*, not just in the diff","one CI/pre-commit step","ADOPT — the secret-guard only sees the present"
```

**The agent side is its own threat model.** Our agents read untrusted text all day, so the
sandbox matters as much as the firewall: `Utgard` (containers) and the airlock's
`bwrap --unshare-net`; dropped capabilities, seccomp, no network by default; a **bash gate
before execution** (prior art: apohara-agentguard, HOL Guard); an **MCP tool allowlist**
with one audit line per call; and the **OWASP AI Agent Security Cheat Sheet** (prompt
injection, tool misuse, exfiltration) encoded into `RULES`.

---

## 7 · The loops — security that runs without you

A one-off audit is a photograph; the attack surface moves weekly. Almost all exploited
CVEs are exploited on or before disclosure, so **detection must be continuous and
unattended**:

```
loops[5]{loop,cadence,what it does}:
  "the watchtower digest","every 15 min","system health + security events from the last 24h, logged"
  "the door scan","daily","what is listening, and has anything new appeared"
  "the patch / CVE scan","daily","what is installed with a known CVE, and what has an update"
  "the integrity check","nightly","file integrity against the baseline; auditd review"
  "the adversary loop","weekly","scan our own public hostnames and images; audit each seat's ssh"
```

Each is a **Nornir** row — Ymir already has the scheduler and the ledger, so a loop is a
cron entry plus a ward, not a new subsystem.

---

## 8 · The roadmap

```
phases[9]{id,name,deliverable}:
  "S0","the audit, as code","security-audit.sh reproduces the findings by script, not by an afternoon"
  "S1","close the doors found","ssh → LAN + tailnet only; PasswordAuthentication no; the control plane → tailnet + tunnel; every public door authenticated or closed. Each change its own PR"
  "S2","the ban","CrowdSec (or fail2ban) with a firewall bouncer and an sshd scenario"
  "S3","the watchers","Lynis + arch-audit weekly; AIDE baseline nightly; a minimal auditd rule set"
  "S4","the tower","verdr.sh writes the report where records live and speaks on any HIGH"
  "S5","scan our own doors","nuclei against every public hostname; ssh-audit per seat; trivy/grype on images; osv-scanner on lockfiles; gitleaks over history"
  "S6","the agent in a jail","each agent sandboxed with dropped caps, seccomp, no network by default, and a bash gate; MCP allowlist + one audit line per call"
  "S7","signed releases","cosign/sigstore provenance; the installer refuses an unsigned artefact"
  "S8","the law","RULES/24 — already written; the rest obeys it"
```

---

## 9 · What the ward will never do

- **Never close a door that could close behind the operator.** A change that can lock him
  out of his own machine is his to make; the ward writes the command, the risk and the
  revert line.
- **Never report green on what it could not see.** An unreachable host, an unreadable
  config and an unverified CVE are named as unverified.
- **Never publish a private measurement.** The ward's findings for a given machine — its
  addresses, its neighbours, its router — are written where records live
  (`$YMIR_HOME/hodd/memory/ward/<date>.md`), never into this public tree (Rule 04).

---

## Relations

- [`RULES/24-the-ward.md`](../RULES/24-the-ward.md) — the law this document serves.
- [`bin/ward/security-audit.sh`](../bin/ward/security-audit.sh) · [`bin/ward/verdr.sh`](../bin/ward/verdr.sh) · [`bin/ward/harden.sh`](../bin/ward/harden.sh) — the eyes, the warden, the mends.
- [`RULES/15-vault-confidential.md`](../RULES/15-vault-confidential.md) · [`RULES/16-confidential-session.md`](../RULES/16-confidential-session.md) — the agent-side half.
- [`docs/Architecture.md`](Architecture.md) — where the ward sits among the realms.
