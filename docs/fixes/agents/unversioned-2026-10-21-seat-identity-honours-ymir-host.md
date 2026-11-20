## agents · unversioned · 2026-10-21 — seat identity honours YMIR_HOST

### Why
`seat-identity.sh` defaulted its host to `hostname -s`, which is `localhost` on the
phone, so Gróa reported "localhost has no seat identity" even with
`YMIR_HOST=host-a` set. It now resolves `${YMIR_HOST:-$(hostname -s)}` like
`topology.sh`, `role.sh`, and the room resolver already do, and `--install` compares
against that same identity.

### Files
- `bin/agents/seat-identity.sh`
- `bin/agents/groa-update.sh`
- `bin/seat/valknut-load.sh`

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: a machine of the fleet. The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).

## CHANGE LOG

- 2026-11-14 — review-mend: added missing heading for #758

- **2026-11-20** — redacted: a machine, a user or a person named above now reads as a role or an invented example (RULES/04 · plan 287 §3). No fact of the fix changed; the original text stands in the repository's history.
