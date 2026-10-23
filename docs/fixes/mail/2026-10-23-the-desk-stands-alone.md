# The desk stands alone: a unit, a clock, and a failure that is not silence

**Date:** 2026-10-23 · **Component:** mail (Gná, plan 116) · **Phase:** P0 → production

## Why

The desk answered when a hand raised it by hand and went stale when no hand did. Three faults, all
naming the same weakness — a service with no supervisor, no clock, and no failure surface:

```
faults[3]{fault,consequence}:
  "the desk was a bare process","a reboot or a kill left the gate answering 503 with no one to raise it"
  "nothing ran the importer","the store froze at its last manual run and the desk showed an old day as if it were today"
  "a failure had nowhere to go","an unreadable mailbox would read as an empty inbox — the exact fault the plan was born from"
```

## What was built

```
pieces[4]{path,what}:
  "bin/mail/ (moved from the home's hodd/bin/gna-agent/)","the tooling now ships in the repo, because a Nornir row may only name a repo-relative command (bin/…), never an absolute home path"
  "bin/mail/install.sh","seats gna-desk.service as a systemd USER unit: Restart=always, RestartSec=5, loopback only, and it proves /health before it claims success"
  "bin/time/nornir-job-gna-mail.sh","import every declared account, then probe the desk; --check probes health alone, --dry-run reads and writes nothing"
  "config/cron.yaml (home)","four rows: 07:20 · 11:20 · 15:20 · 19:20 bin/time/nornir-job-gna-mail.sh"
```

The store, the scope and the retention stay the home's (`hodd/memory/mail/`), and the spine is
git-ignored: schema, scope and retention travel, raw mail does not. The repo code carries no address
and no credential — the vault grant is read at run time.

## The law this makes real

`nornir-job-gna-mail.sh` treats **every** absence as a failure and says so in three places: stdout, a
`FAIL` line in `state/gna-mail.log`, and a Rune. A missing scope file, an unreadable registry, a failed
import, a desk that does not answer — each exits non-zero with a sentence naming what is missing. The
gate's own answer for a dead desk is 503 with the command that raises it, never an empty queue.

## Verified

```
verified[4]{check,result}:
  "bash bin/mail/install.sh","unit enabled, desk answering /health, token in the home"
  "bash bin/time/nornir-job-gna-mail.sh --check","desk {\"ok\":true,…}"
  "python3 bin/mail/tests/test_gna.py","16 passed"
  "bash bin/gates/guards/app-functional-guard.sh","45 UI calls, every one answered"
```

**Not verified here:** a full reboot (the unit's `WantedBy=default.target` is the claim), and a Nornir
cycle actually firing the new rows (the scheduler is restarted in the same change; the first row lands
at its minute).
