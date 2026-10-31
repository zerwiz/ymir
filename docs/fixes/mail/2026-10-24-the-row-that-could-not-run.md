## mail · 2026-10-24 — the four mail rows passed every check and none of them ran

Plan 116 §15 (the doors that had to be measured) — and the fault found while measuring them.
The register said the house could not receive mail; the schedule said the desk was fine. Both
were wrong about a third thing: **the job that keeps the desk current had not executed since
2026-10-23 19:40.**

### Files
- `bin/time/nornir-job-gna-mail.sh` — mode `100644` → `100755`. The four Gná rows
  (`@dev 07:20 · 11:20 · 15:20 · 19:20`) name it as a bare repo-relative path, so the
  scheduler's `bash -lc "$cmd"` execs it directly and a 644 file answers
  `rc=126 Permission denied`.
- `bin/time/nornir-job-doctor.sh` — the same fault, caught by the new ward: the shipped
  `config/cron.yaml.example` names it, so **a fresh install's daily doctor would never run**.
  Mode `100644` → `100755`.
- `bin/gates/guards/cron-guard.sh` — the ward now checks runnability, not only existence.

### The fault, measured
```
runes 2026-10-24T08:20:13Z  [cron/HIGH] job failed (rc=126): bin/time/nornir-job-gna-mail.sh — no output
runes 2026-10-24T12:20:00Z  [cron/HIGH] job failed (rc=126): bin/time/nornir-job-gna-mail.sh — no output
(state/gna-mail-last-run.json) last successful round: 2026-10-23T19:40:35+03:00
```
`cron-guard.sh` passed throughout, because it asked whether the named script **ships** — and it
does. Nobody asked whether it can be **executed**. A cron row that exists, resolves and cannot
run is the same lie as one that names a script from a home only: the schedule says the work is
watched, and the work is not watched.

### The rule this leaves behind
**Shipping is not running.** The two halves are now one ward: a `bin/…` named by a schedule must
exist **and** carry the execute bit, because the runner takes the bare path to `exec`. The check
is offline and total — it reads the operator's cron, the repo's, and the shipped example, so a
seat with a different schedule still gets the same law.

### Proofs run
```
bin/gates/guards/cron-guard.sh check        rc=0   "every referenced script ships in the repo and can be executed"
bin/gates/guards/cron-guard.sh check        rc=1   before the chmod — named both 644 scripts, with the fix in the help
bash -lc "bin/time/nornir-job-gna-mail.sh"  rc=0   first completed round since 2026-10-23: 4 written · 27 unchanged,
                                                   desk healthy, and the undeliverable addresses reported as a WARN
```

### Owed
Nothing in code. The chmod reaches the live schedule when this branch merges; until then the
four rows keep failing with `rc=126`, and the desk keeps serving the store last written on
2026-10-23. The two console steps from `docs/fixes/snotra/2026-10-24-nobody-could-mail-us.md`
(Workspace aliases, or Cloudflare Email Routing) are still the Allfather's, unchanged by this.
