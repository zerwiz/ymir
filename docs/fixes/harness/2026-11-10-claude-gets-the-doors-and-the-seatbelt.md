## harness · 2026-11-10 — Claude Code gets Ymir's doors and the pre-tool seatbelt (plan 239 P1–P2)

### What
- **`bin/bridge/mcp-config.sh claude [--check]`** — seats `ymir` (the packet, stdio), `engram` (store resolved from the
  hoard) and `well` (gateway `:${YMIR_MCP_GATEWAY_PORT:-8316}`) in Claude Code at user scope through `claude mcp add`; a
  row already present is left alone; never a hand-merge of `~/.claude.json`.
- **`bin/seat/harness-extensions-install.sh`** — the claude row now reports and seats `claude-mcp`, so `/updateymir`
  keeps it current; migration 0018 seats it once on existing homes.
- **`bin/gates/checks/claude-pretool.sh`** + a `PreToolUse` (Bash) block in `.claude/settings.json` — Claude's stdin
  payload adapted onto `syn-arm-pretool-check.sh` and `syn-cd-pretool-check.sh`, the two Pi's `tool_call` seam runs.

### Why
Audit 2026-11-10 (plan 239): Claude had no MCP row at all — `ymir-install.sh` step_memory only counted configs carrying
`"engram"`, it never wrote one — and `harness-integration/claude-code.md` §7 named the missing seatbelt.

### Verified
- On heimdall: `claude mcp list` → `ymir`, `engram`, `well` all `✔ Connected`; `mcp-config.sh claude --check` → three
  `current`, exit 0.
- Adapter: `ls -la` → 0; `nohup bin/pi/syn-watch-arm.sh &` → 2 with "do not background the Brokk watcher arm"; a
  non-Bash tool → 0; malformed payload → 0.

### Not done
Pi's third check (`syn-asset-pretool-check.sh`, governed-path asset reads) takes a path, not a command; not wired yet.
Plan 239 P3–P6 (the 18 Pi-only tools into the packet, the remaining seams, Claude as an Eindri, the parity gate) remain.
