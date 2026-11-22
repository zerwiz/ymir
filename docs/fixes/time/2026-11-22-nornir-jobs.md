# 2026-11-22 — every Nornir job, one row each (`nornir-jobs.py`)

The operator wants every Nornir job on a page in Bilskirnir. The clock's own door (`nornir-cron-start.sh --status`) prints one line, *jobs=49 invalid=2*; nothing said which job, when it runs next, or how its last run ended.

`bin/time/nornir-jobs.py [--json]` reads `config/cron.yaml`, `state/cron.log` and the clock's status, and answers per job: its role gate, days and time, whether this machine runs it, when it runs next, when it last ran, and whether that run failed (rc and the clock's one-line reason). Read-only. Measured on the heart: 49 jobs, 25 its own, 2 failing (the daily briefing's old drafts; the NSR gate fixed in #890).
