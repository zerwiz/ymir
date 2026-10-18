# 24 — The ward: a door is named, or it is closed

**Appended 2026-10-18** at the Allfather's word — *"we need to add some security systems to see
if we are having insecure open ports or other things and if someone trying to come in to us …
make a security plan for ymir"*, and then *"build the warden"*.

**Why it exists.** On 2026-10-18 an agent measured this house by hand and found: a **public tunnel
answering HTTP 200 with no login**, ssh on every interface with password authentication at its
compiled default, a control plane allowed from **any** address, the vault's own key world-readable,
and **nothing at all watching the host** — no ban for brute force, no audit rules, no file-integrity
baseline, no vulnerability scan. The house had 16 laws for its agents and none for its doors.

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

**Also part of the ward, because a record with a wrong clock is a record nobody can trust:** the
clock is synchronised, or the warden's report says it is not (Sól's `check`, Rule 20's neighbour).

**What it forbids:** an unnamed wide bind; a public door without a credential; `PasswordAuthentication
yes`; a `0600`-less secret; a security task that exists only as prose; a change to the firewall or
sshd made *for* the operator instead of *reported to* him.

**Enforced by:** `bin/ward/security-audit.sh` (the eyes — measures and reports, changes nothing;
exit 1 on HIGH or CRITICAL) · `bin/ward/verdr.sh` (**Vörðr**, the warden — walks the house, writes
`hodd/memory/ward/<date>.md`, speaks on HIGH) · `bin/ward/harden.sh` (the mends, written out;
`--sshd` and `--ssh-keys-perm` are safe and validated, `--ufw` refuses without the Allfather's
explicit word) · and the **`ward` surface of Eir**, so a house with an open door is never reported
green. Plan **81** carries the phases (S0–S8) and the stack to adopt (CrowdSec or fail2ban, Lynis,
AIDE, auditd, trivy/grype, gitleaks, and the agent-sandbox work).
