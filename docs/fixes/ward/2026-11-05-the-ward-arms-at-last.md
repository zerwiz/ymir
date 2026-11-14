# The ward arms at last

**Date:** 2026-11-05 · **Component:** ward · **Door:** `bin/ward/garmr.sh`

Arming it — the one proof a dry read cannot give — found two faults that a correct-looking ruleset
still carried. The detail lives in `2026-11-04-the-rule-that-armed-nothing.md`; this note is the
delivery record for the fixes themselves.

**`-D` first, or the unit can never be restarted.** `garmr.sh install` primes the rules with
`auditctl` line by line; `augenrules` then refuses every one of them with `Error sending add rule data
request (Rule exists)`. A right file still left `audit-rules.service` red, so a green state was
unreachable by design. The ruleset now begins with `-D`.

**`$HOME` under sudo is root's.** The house's own advice is `sudo bash bin/ward/garmr.sh install`, and
`sudo` resets `HOME=/root` — so the one watch meant to witness a key being added pointed at
`/root/.ssh/authorized_keys`, did not exist, and was silently guarded away. The operator is named by
`SUDO_USER`, and that is whose `~/.ssh` is watched. Proven by installing with `HOME=/heimdall-nohome`:
the rule still came out as `/home/heimdall/.ssh/authorized_keys`.

**Armed and verified:** `Result=success`, `ExecMainStatus=0`, 24 rules in the kernel —
`execve` and the eleven signal paths, the identity watches, the unit directories, and the hoard's
`evidence`, `life/meetings` and `secrets` shelves. No watch names a path that is not there, so no
single missing file can disarm the set again.

**Owed:** the green has not yet been seen across a reboot. That is the next hand's check, and it is a
`reboot` and one `auditctl -l` away.

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: a dev machine (this seat). The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).
