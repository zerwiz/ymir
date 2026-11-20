# The hound sat on a rotated audit log and went quietly blind

**Component:** ward · **Seat:** heimdall · **Date:** 2026-10-21

## What happened

`garmr-hound.service` started, wrote a heartbeat, and then observed nothing for three
minutes. Nothing failed; the service reported `active`.

`ls -l /proc/<pid>/fd` showed it: fd 3 pointed at **`/var/log/audit/audit.log.2`.** It had
opened the file once at start, and auditd's logrotate had renamed it underneath. A process
that holds an inode keeps reading the old file for ever — the new log fills, the hound
reads nothing, and the silence looks exactly like calm.

## The fix

`follow_audit` now compares `os.stat(path).st_ino` with the inode it opened, on every pass,
and reopens when it changes (reading a fresh file from its start). The tail survives
rotation, truncation and the log being moved.

## Two more found the same hour

- **argv was one blob.** audit writes the `PROCTITLE` as one hex blob whose arguments are
  NUL-separated; the parser split the *hex text* before decoding, so every finding carried a
  single un-splittable string. Now: decode, then split.
- **a sensitive path could ride in an argv.** Only `target` was hashed by `redact_path`;
  a command line naming a protected shelf went into the findings verbatim. `redact_argv` now
  hashes any argument that names a sensitive shelf, and the redactor's tests cover it.

## The contaminated log

Findings written before that second fix carried real paths under `hodd/data/snotra`,
`hodd/evidence` and `hodd/secrets`. They were **moved** (never deleted, Rule 11) to
`/var/log/ymir/garmr/findings.pre-redactor-20261021T1428Z.jsonl`, mode 0640 root:heimdall,
and left on this seat only. The new file was empty at the move and every record since has
been checked: `grep -c 'snotra\|Bearer\|ghp_'` returns **0**.

## The lesson carried into the code

A guardian's own log is a surface (Rule 26). The redactor is not a wrapper around the
output — it is the reason the output may exist. Its tests (`.agents/tests/garmr.test.sh`)
assert the leak, not the feature: a bearer token, an `?access_token=`, a `--password` value,
a `sk-…` shape and a sensitive path must each come out replaced.

## Appended the same hour — arming in a capability-stripped unit cannot work

`ExecStartPre=/bin/sh -c 'auditctl -R …'` inside `garmr-hound.service` failed **51 times in a
row** with `You must be root to run this program` (status 4/NOPERMISSION) and the hound never
started at all — the unit reported `activating`, which looks like a slow start rather than a loop.

The cause is the unit's own hardening: it drops `CapabilityBoundingSet` to
`CAP_DAC_READ_SEARCH` (so root can read a 0700 home) and sets `NoNewPrivileges=yes`, which also
removes `CAP_AUDIT_CONTROL` — the thing `auditctl` needs. Hardening the reader and arming the
kernel are two jobs, so they are now two units:

- **`garmr-arm.service`** (`Type=oneshot`, `RemainAfterExit=yes`, `Before=garmr-hound.service`) —
  loads `/etc/audit/rules.d/ymir.rules` line by line (a rule that already exists is healthy), and
  `ExecStartPost` asserts `ymir-exec` is present, so a failed arm fails the unit instead of
  leaving a deaf hound.
- **`garmr-hound.service`** now only *tests* that the rules file exists and refuses to run without
  it — a read-only check, which needs no capabilities.

Verified after the change: both units `active`, smoke **9 pass · 0 fail · 0 skip**, findings
still flowing, and the hound costs **22.9 MB RSS and 0 MiB of VRAM**.
