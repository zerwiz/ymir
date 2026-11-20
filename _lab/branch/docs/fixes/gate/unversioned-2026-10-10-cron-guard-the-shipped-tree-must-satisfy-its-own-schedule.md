## gate · unversioned · 2026-10-10 — cron-guard: the shipped tree must satisfy its own schedule

### What

A new tree ward, **`bin/gates/guards/cron-guard.sh`**, seated in `guards.sh`'s
`WARDS` list (so the pre-push hook and CI run it):

> Every `bin/…​.sh` a Nornir cron line runs must **resolve to a script that ships
> in this repo**. A job runs from the repo root, so `bin/x.sh` means
> `<repo>/bin/x.sh`. A line naming a script that lives only in the operator's home
> — or nowhere — is a job no other seat, and no fresh user, can run.

The ward reads the effective cron (`$YMIR_CRON_FILE` → the operator's home cron →
the shipped `config/cron.yaml.example`), extracts every `bin/*.sh` on a non-comment
line, and refuses any that does not exist under the repo root.

### What it caught on this seat

The operator's private home cron referenced **pre-`bin/`-move paths**, so every job
was unfindable:

- `bin/nornir-job-*.sh` → really `bin/time/nornir-job-*.sh`
- `bin/eindri-handoff.sh` → really `bin/agents/eindri-handoff.sh`
- `bin/well-vault-sync.sh` → **not in the repo at all**

The last was the real gap the Allfather asked about: a needed script living only in
the personal home. It is generic (uses `$YMIR_HOME` only), so it is **shipped** as
`bin/time/well-vault-sync.sh` — the well now syncs for every user, not just us —
and the private cron was corrected to the moved paths.

### Verified

- Before: `cron-guard check` → 11 findings. After the fixes: `cron-guard check`
  → `"none"`, exit 0.
- `bash -n` clean on the ward and the shipped script; `guards.sh --list` names it.

### Files

- `bin/gates/guards/cron-guard.sh` (new)
- `bin/gates/guards.sh`
- `bin/time/well-vault-sync.sh` (new — moved from `$YMIR_HOME/bin/`)
