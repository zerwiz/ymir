# The host watcher — what is this machine exposing, and did anything look?

**What it is.** `bin/ward/host-watch.sh` takes one look at the machine and writes it down: which
TCP ports are bound (and which are bound to the world), the fingerprints of the files that decide
who may enter, and how many SSH authentications have failed. It then drops a heartbeat.

**Why it exists.** `security-audit.sh` used to report *"nothing watches this host — no fail2ban,
crowdsec, lynis, aide, osquery or falco"*. On a phone none of those can exist: no root, no
systemd, no syslog. The finding was true and useless. This is the watcher a `hand` can have.

**What you need.** Nothing beyond a bash shell. It uses `sha256sum`, `logcat` and an sshd log when
they exist, and says plainly when a source is absent.

## Commands

```bash
bin/ward/host-watch.sh run       # take one look, append it, refresh the heartbeat
bin/ward/host-watch.sh status    # exit 0 while the last look is under 26 hours old
bin/ward/security-audit.sh check # the ward's own report; accepts a fresh heartbeat
```

`run` appends to `$YMIR_HOME/state/ward/host-watch.log`; the heartbeat is
`…/host-watch.last`. A cron row (`06:50 bin/ward/host-watch.sh run`) keeps it fresh without
systemd.

## Limits — said out loud, because a false green is worse than a gap

- **Listeners may be unmeasured.** Android denies `ss` its netlink socket, Termux's `netstat`
  refuses `AF INET`, and `/proc/net/tcp` is unreadable to the app. The watcher then prints
  *"listeners unmeasured"* — an empty table never means "nothing is listening".
- **Attempts may be unmeasured.** Without an sshd log or `logcat`, it says so rather than zero.
- It **records, it does not ban.** Closing a door is a decision: `bin/ward/harden.sh plan`.

## If it does not work

- `status` says *never ran* → run `bin/ward/host-watch.sh run` once, then check the cron row in
  `$YMIR_HOME/config/cron.yaml`.
- `status` says *stale* → the cron job is not firing; `bin/time/nornir-cron-start.sh` raises the
  scheduler.
- The audit still reports `nothing watches this host` → the heartbeat is older than 26h; refresh
  it.
