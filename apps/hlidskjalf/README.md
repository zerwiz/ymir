# HLIDSKJALF — Master Control Dashboard

Odin's high seat: the Ymir SPA that renders every realm, the fleet, the A2A task
stream, the well, the Runes ledger, and the reviews.

Stack: **React 19 + Vite + TypeScript**, Zustand for state. Consumes the canonical
design tokens from `midgard/design-system/tokens.css` (single source — no per-app
colour drift). Plan: `docs/plans/28-frontend-backend-build.md` (W0026).

## Run

```bash
cd apps/hlidskjalf
npm install
npm run dev
# → http://127.0.0.1:3888/
```

Gates are deep-linkable: `#/fleet`, `#/tasks`, `#/well`, `#/runes`, `#/reviews`,
`#/processes`, `#/files`, `#/chat`.

## Build

```bash
npm run typecheck   # tsc --noEmit
npm run build       # → dist/
npm run preview
```

## Backend wiring — live vs demo

The SPA has two modes, chosen at sign-in:

- **Live** — sign in with an identity. The app loads the real Brokk runtime from
  the local **gate API** (`apps/hlidskjalf/server`, Bun, default `:3889`), which
  reads `state/`, `.agents/config/`, `workspace/memory/runes_audit.md`,
  `.agents/memory/well/episodes.jsonl`, `.agents/agents/`, `docs/masterplan.md`, and
  the runtime `--status` scripts. Vite proxies `/api` to it.
- **Demo** — press **Enter demo mode** on the login screen. Seeded mock data, no
  runtime required.

### Run

```bash
# from the repo root — raises BOTH the gate API (:3889) and the SPA (:3888)
scripts/start.sh
scripts/stop.sh

# or run them separately
cd apps/hlidskjalf
npm run api     # gate API on :3889 (needs bun)
npm run dev     # SPA on :3888 (proxies /api → :3889)
```

Endpoint surface (live): `/api/me|workspace|agents|tasks|orders|well|runes|processes|reviews|files|runtime|cron|loaders|checks|settings|chat|chat/history` + `GET /api/stream` (SSE, tails Runes). Chat (`POST /api/chat`) speaks to Kaia through the first reachable OpenAI-compatible backend — the local llama-server (`:8080`), then the Bifrost bridge (`:4603`) — recalling from the well and persisting to `state/chat.jsonl`.

## Structure

```
src/
  app/          Shell, rail, topbar, bottom stream
  components/   AgentCard · TaskChip · TraceRow · RecallPanel · MetricTile · RuneTag · PRCard
  gates/        Fleet · Tasks · Well · Runes · Reviews · Processes · Files · OmniChat
  data/         realm/house registry + mock seeds
  services/     gate API client + stream transport
  state/        Zustand store
  styles/       global · shell · components (tokens imported from midgard)
```
