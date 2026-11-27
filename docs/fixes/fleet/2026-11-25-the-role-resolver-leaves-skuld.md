# The role resolver moves to bin/fleet/; Skuld keeps what shall be (plan 374 D3)

Which machine plays which role (`role.sh`, `role-lib.sh`) is a fleet fact, not Skuld's. Both files moved with
`git mv` to `bin/fleet/`, so `git log --follow` keeps their history. Every shipped caller was repointed (the install,
Gróa, Eir, the apps, the units, the runtime's identity, the warden, the desk, the tests). The append-only documents
that name the old path (`AGENTS.md`, `RULES/25`, the fix notes) keep it as the record.

The old paths are **forwarding stubs** for one release cycle: `bin/skuld/role.sh` execs the new door and
`bin/skuld/role-lib.sh` sources the new library, so a home's cron row or script keeps working.
`.agents/paths-ledger.yaml` records the move, and `bin/gates/guards/path-ledger-guard.sh` reads it.

## Proof

- `bash .agents/tests/role.test.sh` → `ALL PASS`; `bash .agents/tests/role-lib.test.sh` → `ALL PASS`.
- `bash bin/skuld/role.sh --version` → `1.0.0` (through the stub); `bash bin/fleet/role.sh resolve --why` answers.
- `bash bin/gates/guards/path-ledger-guard.sh check` → clean.

## CHANGE LOG

- 2026-11-25 — review-mend: added missing heading for #944
