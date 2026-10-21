## agents · unversioned · 2026-10-21 — seat identity honours YMIR_HOST

### Why
`seat-identity.sh` defaulted its host to `hostname -s`, which is `localhost` on the
phone, so Gróa reported "localhost has no seat identity" even with
`YMIR_HOST=sleipnir` set. It now resolves `${YMIR_HOST:-$(hostname -s)}` like
`topology.sh`, `role.sh`, and the room resolver already do, and `--install` compares
against that same identity.

### Files
- `bin/agents/seat-identity.sh`
- `bin/agents/groa-update.sh`
- `bin/seat/valknut-load.sh`
