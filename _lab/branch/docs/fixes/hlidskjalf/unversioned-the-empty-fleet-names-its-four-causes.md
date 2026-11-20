## hlidskjalf · unversioned · 2026-09-27 — the empty fleet names its four causes

### Why
The Fleet showed a silent 0/0 whether the gate refused (401), the connector errored, the gate was unreachable, or the roster was truly empty, and a relative ROSTER_DIR resolved against the server cwd so the roster read the wrong path. The roster path is now absolute from the repo root; /api/agents treats an empty connector array as no-data and falls through; api.ts throws GateError carrying its status; store.ts derives agentsStatus; Fleet.tsx names the cause and the empty case. A Nornir backstop (bin/time/nornir-job-asken-handoff.sh, 04:00) rolls every repo that carries a .asken state.

### Files
- `apps/hlidskjalf/src/services/api.ts`
- `apps/hlidskjalf/src/state/store.ts`
- `apps/hlidskjalf/src/gates/Fleet.tsx`
- `apps/hlidskjalf/server/index.ts`
- `bin/desktop/hlidskjalf-agents.sh`
- `apps/hlidskjalf/server/hlidskjalf-agents.sh`
- `bin/time/nornir-job-asken-handoff.sh`
- `.agents/config/cron.yaml.example`