# The house's own key sync was raising a CRITICAL every fifteen minutes

**Date:** 2026-11-20 · **Component:** host (`bin/host/heimdall-ssh-keys.sh`) · **Errand:** `ward-honest`

## What was wrong

The operator's phone carried this, again and again, all night:

```
[garmr/CRITICAL] CRITICAL: chmod (pid 3971323, uid 1000) changed  at 2026-11-19T23:54:44+0100 — passwd, shadow, sudoers or an authorised key
```

Traced from the heart to the machine that produced it — a dev seat with `+0100`, a hound running from
`~/ymir-runtime/bin/ward/garmr/hound.py`, and `/var/log/ymir/garmr/findings.jsonl` holding fifteen of them:

```json
{"class": "identity", "comm": "chmod", "exe": "/usr/bin/chmod", "kind": "file_change",
 "pid": "3971323", "sense": "audit", "ts": "2026-11-19T23:54:44+0100", "target": "", "uid": "1000"}
```

Not an intruder, and not even a wrong alarm in substance: the machine's audit rules watch the authorised
keys (`-w /home/<user>/.ssh/authorized_keys -p wa -k ymir-identity`), and `heimdall-ssh-keys.timer` runs
`heimdall-ssh-keys.sh add --quiet` **every fifteen minutes**, which did:

```bash
chmod 700 "$(dirname "$KEYS_FILE")"
chmod 600 "$KEYS_FILE"
```

unconditionally. So a chmod landed on a watched file four times an hour, whether or not a single key had
changed — and the hound reported it as a possible change to `passwd`, `shadow`, `sudoers` or a key.

## What was built

`bin/host/heimdall-ssh-keys.sh` gains `ensure_mode <path> <mode>`: it reads the current mode and changes it
**only when it is wrong**. It is called on both paths — when the keys change (after the file is installed)
and when they do not (the early "already current" return), so a drifted mode is still repaired.

The watcher is untouched. A real change to the authorised keys still reaches the audit rule and still
raises the alert; the difference is that an unchanged file now says nothing.

## The proof

```bash
$ bash bin/host/tests/test_ssh_keys_no_needless_chmod.sh
  ok   a file with the wrong mode is set to 600
  ok   a second run that changes nothing does not chmod or write
  ok   the mode is still 600 afterwards
  ok   a mode that drifts is repaired on the next run
heimdall-ssh-keys: 4 passed, 0 failed
```

The third assertion is the one that matters: the file's **ctime** is identical after a second run, so no
`chmod` and no write happened. Gate: `ssh-keys-chmod`.

## What this does not decide

- **The message was also broken, and that fix is separate.** Even a true chmod on a watched file arrived
  with an empty `target` — `changed  at`, with nothing between — and was announced as `CRITICAL` naming
  three files it had not seen. `bin/ward/garmr/rules.py` now reports an unnamed identity target as `HIGH`
  and says plainly that no file is named (gate `garmr-identity`). Which of the two faults produced the
  empty path — the audit record or the parser — is still open, and needs the raw `ausearch -k ymir-identity`
  output from that machine as root.
- **The other machine runs its own copy.** It picks this up when it updates (Gróa) or when the branch
  lands and it next updates; its timer will keep chmod-ing until then.

## CHANGE LOG

- 2026-11-20 — written the night the alarm kept ringing.
