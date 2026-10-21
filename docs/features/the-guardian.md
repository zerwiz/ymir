# The guardian — Garmr, the hound at the gate

**What it is.** A watcher that lives on your machine and writes down what happens on it:
what ran, who opened a protected file, what started listening, what connected out, and what
signal was sent to what. It turns those into plain sentences, wakes you when one matters,
and keeps the record. It is **read-only against the machine** — it never closes a door,
never kills a process, never changes a setting.

**What you need.** Linux with `auditd` (present on most distributions, not always running),
`ss`, and `python3`. One `sudo` to seat it. No account, no cloud, no key for the base
feature: the senses are the kernel's own audit log.

**The commands**

```sh
bin/ward/garmr.sh status      # what is armed, what is running, what has been judged
sudo bin/ward/garmr.sh install   # arm the senses and seat the two services (once)
bin/ward/garmr.sh pause       # stop watching for now (e.g. while you work on something noisy)
bin/ward/garmr.sh resume      # start again
bin/ward/garmr.sh judge       # apply the rules to the newest findings, now
bin/ward/garmr.sh tail 20     # the newest judgements, HIGH and CRITICAL first
bin/ward/garmr.sh verify      # prove it is not silently dead
bin/ward/garmr-smoke.sh       # the reusable 9-check smoke test (running ≠ armed ≠ working)
bin/ward/garmr.sh refresh     # re-render the units after an update (Gróa runs this)
```

**On and off.** `sudo bin/ward/garmr.sh pause` stops the senses and skips the judgement; it
leaves a **root-owned** marker so the status says plainly **paused**, never "all clear", and
writes the pause to `/var/log/ymir/garmr/pause.log`. `resume` starts it again. **Both need root
on purpose** — a guardian an ordinary process can silence is a guardian the intruder silences
first; the smoke test asserts that a non-root pause is refused. `install` is idempotent.

**Where you see it.** The Hlidskjalf topbar carries a **ᛉ hound** chip: green when it is
watching and quiet, amber at HIGH, red at CRITICAL, and a loud **silent** state if the
heartbeat stops. Clicking it opens *Himinbjörg*, the watchtower: the heartbeat, the counts,
and the newest serious findings with the reasoner that answered, if one did.

**What it watches**

| Sense | What it records |
|---|---|
| exec | a program running (path, command line **redacted**, uid) |
| file_change · identity | `/etc/passwd`, `/etc/shadow`, `/etc/group`, `/etc/sudoers`, `/etc/sudoers.d`, `~/.ssh/authorized_keys` changed — **CRITICAL** |
| file_change · persistence | a unit, a cron row, or an autostart entry changed — `/etc/systemd/{system,user}`, `/etc/cron.d`, `/etc/crontab`, `/var/spool/cron`, `~/.config/systemd/user`, `~/.config/autostart` — **HIGH** |
| sensitive | a read or write on a protected shelf (meeting data, evidence, the vault, secrets) — the path is stored as a **hash**, never as text |
| listener | a socket that starts listening |
| egress | a connection to a host that is not on your list |
| kill | a signal sent to a process, with the sender and the target |

**What it deliberately does not do**

- It never records file **contents**, a transcript, a recording, or a secret **value**. A
  password on a command line is replaced before it is written; a sensitive path is hashed.
  An observer that copies what it guards is a leak with a badge.
- It never decides with a model. The severity is a rule; the sentence is a template. A
  reasoner is asked for a paragraph **only** above the configured threshold, and the answer
  is recorded with its rung and model.
- It never closes anything. A finding is a report; the mend is yours.

**Settings.** `$YMIR_HOME/config/guardian.yaml` (copy `config/guardian.yaml.example`).
Allow-lists for readers and ports, the poll interval, whether the desktop speaks, the
escalation ladder (local model → fleet rail → online), and a daily budget for the online
rung — `0` means never. Every value has a documented default; omit what you do not care about.

**Limits, said honestly.** Audit rules armed with `auditctl` are **runtime only** — a reboot
clears them; `garmr.sh install` re-arms them, and making them survive a reboot is the next
phase (plan 98, G10). The hound needs root to read the kernel's audit log, so it runs as a
system service; the judgement runs as you, so your model keys are never root's. A machine
without passwordless `sudo` gets a clean skip at install, not a pretend success.

**If it does not work**

```sh
systemctl status garmr-hound.service          # the senses (root)
systemctl --user status garmr-brain.timer     # the judgement (you)
sudo auditctl -l | grep ymir-                 # are the rules still armed?
sudo tail -5 /var/log/ymir/garmr/findings.jsonl
bin/ward/garmr.sh verify
```

A hound that is **silent** is reported as a finding, not as calm. If `verify` says the
heartbeat is stale, restart it (`sudo systemctl restart garmr-hound.service`) and read
`journalctl -u garmr-hound.service`.
