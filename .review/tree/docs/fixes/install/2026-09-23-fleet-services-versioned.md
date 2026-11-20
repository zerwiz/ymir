## install · unversioned · 2026-09-23 — the fleet's running services, versioned

### Why
The services forged on whynot (well-mcp · the ratatoskr node · the mill
worker · the hall feed) ran from loose files outside any repo — re-deployable
only by scavenging. The Allfather's question ("is that code pushed?") named
the gap.

### What
`tools/` now carries them: `tools/well-mcp/server.ts` · `tools/ratatoskr-node/server.ts`
· `tools/mill/worker.sh` + the five systemd unit templates · and
`apps/odrerir/src/pages/feed.astro` (the hall's live volt). Deploy: copy to a
seat + `systemctl --user enable --now` the matching unit; the mill's enemy
paths (`vector-index.jsonl`, `reviews/`, `voice/`) belong to the seat, not the
repo.

### Files
- `tools/well-mcp/server.ts` · `tools/ratatoskr-node/server.ts` · `tools/mill/worker.sh`
- `tools/mill/systemd/{well-mcp,ratatoskr,mill-worker,embed,cards}.service`
- `apps/odrerir/src/pages/feed.astro`
