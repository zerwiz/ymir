## ward · unversioned · 2026-10-20 — the ward asks

### What

`bin/ward/ward-ask.sh` turns the audit's HIGH/CRITICAL findings into numbered
decisions with options (close · keep with a reason · plan), writes
`hodd/memory/ward/<date>-ask.md`, and exits 3 while anything is unanswered. It
changes nothing. Install runs `step_ward`, which reports the count.

The safe mends still run through `harden.sh`; on this seat `apply --ssh-keys-perm`
fixed `age.key` 644 → 600 and one backup.

### Why

The Allfather: *"The security system must report to the user and ask what he wants
to do."* Reporting without asking is a report; a finding is not a decision.

### Verified

- Audit: 24 findings, 0 critical, 5 high; `ward-ask` wrote 5 deduplicated decisions
  and exited 3.
- `harden.sh apply --ssh-keys-perm`: 2 mends, both now 0600.
- No firewall or sshd change was made — those remain the operator's act (RULES/24).

### Not verified

- No answer door yet (`ward-answer.sh`); decisions stay open until it exists.
- No escalation into the daily briefing or digest.
