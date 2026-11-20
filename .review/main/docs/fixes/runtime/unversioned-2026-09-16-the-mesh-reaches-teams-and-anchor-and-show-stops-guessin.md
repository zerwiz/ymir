## runtime · unversioned · 2026-09-16 — the mesh reaches Teams and Anchor, and `show` stops guessing

### Why
`bin/a2a-mcp.sh` wired only the well (`engram`) and the mesh (`a2abridge`). The
**Teams** plane and **Anchor** memory existed only in the operator's personal
harness config, so no agent *inside* Ymir could see tickets or anchored memory —
and `a2a-mcp.sh show` insisted on a **fixed** server list, reporting
`wayofteams-mcp not on PATH` even when the plane was wired and working.

- **Remote MCP servers, URL-driven.** `bin/a2a-mcp.sh` now wires `wayofteams`
  (from `WAYOFTEAMS_MCP_URL`) and `way-of-anchor-sse` (from `ANCHOR_MCP_URL`).
  OpenCode gets them natively (`type: remote`); Pi, which has no remote
  transport, gets them through the `mcp-remote` stdio bridge. A URL wins over a
  local `wayofteams-mcp` binary when both exist. The URLs are credential-ish and
  live in the private platform env — never the tracked tree.
- **`show` reports what is actually wired.** It enumerates every key present in
  Pi's `mcpServers` and OpenCode's `mcp` (union with what this run would add), so
  a hand-added or previously-installed server is visible, and the hint only fires
  when Teams/Anchor is genuinely absent.
- `galdr-reread`: `assets/harness-integration/README.md` — the MCP scope is now
  well · mesh · Teams · Anchor, with the two env keys named.

### Files
- *(carried from the frozen CHANGELOG.md)*
