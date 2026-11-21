# Tool Inventory — Where Every Tool Lives

**Date:** 2026-11-21
**Plan:** 348 — Move harness extensions into Ymir MCP

## Three homes for tools

1. **Harness-native** — built into pi (and most other harnesses: Claude Code, Codex, OpenCode, Hermes, Cursor). Available to every harness without MCP.
2. **Ymir MCP** (`bin/mcp/ymir-mcp.py`) — house-specific tools that wrap `bin/` scripts. Available to every harness via MCP.
3. **Harness extension** — pi-only TypeScript modules. Available to pi only.

---

## Harness-native tools (come with every harness)

These are built into pi and equivalent harnesses. They do NOT need MCP wrappers.

| Tool | What it does |
|---|---|
| `read` | Read file contents |
| `edit` | Edit files with exact text replacement |
| `write` | Write/create files |
| `bash` | Execute shell commands |
| `ask_user_question` | Ask the user structured questions (pi-only UI) |
| `todo` | Manage task list |
| `subagent` | Dispatch Eindri figures |
| `context_left` | Check remaining context window |
| `web_search` | Search the web |
| `source_check` | Gather cited web passages |
| `fetch_content` | Fetch web pages, PDFs, repos |
| `memory_add` / `memory_replace` / `memory_remove` | Persistent memory |
| `memory_search` | Search extended memory |
| `session_search` | Search past conversations |
| `skill_manage` | Manage reusable skills |
| `mcp` | MCP gateway |
| `constellation_list` | List Ymir mesh peers |
| `constellation_card` | Read one peer's agent card |
| `constellation_ask` | Check a peer's declared skill |
| `gna_watch_arm` | Start Pi watcher cycle |
| `brokk_branch_outcomes` | Read supervision branch outcomes |
| `excalidraw_diagram` | Write .excalidraw scene from spec |
| `excalidraw_app` | Excalidraw desktop app status/start/stop |
| `logretta_stack` | Council roster status |
| `well_recall` | Recall from Kaia's memory |
| `well_observe` | Write lesson to Kaia's memory |
| `skuld_plan` | Read plan ledger |
| `skuld_ticket` | Read work queue |

---

## Ymir MCP tools (house-specific, available to all harnesses via MCP)

These wrap `bin/` scripts. No harness-native equivalent exists.

| Tool | What it does |
|---|---|
| `ymir_where` | Where Ymir is: repo, home, seat |
| `ymir_rule` | Read house law from RULES/ |
| `ymir_structure` | Shape of private home |
| `ymir_find` | Find files in home by name/content |
| `ymir_daily` | Today's log line in home |
| `ymir_calendar` | Calendar through Mánagandr |
| `ymir_heal` | Eir the healer: diagnose/mend |
| `ymir_gates` | Which gate covers which surface |
| `ymir_update` | Gróa the updater: check/renew |
| `ymir_secret_keys` | Which secret key names exist |
| `ymir_hermes_list` | List Hermes sessions |
| `ymir_hermes_send` | Send turn to Hermes session |
| `ymir_hermes_recover` | Recover paused Hermes session |
| `ymir_core_four` | Four dials for agent outcome |
| `ymir_pending` | Everything blocked on operator |
| `ymir_studio` | OpenDesign studio status |
| `ymir_errand` | Start/read/steer/close errand |
| `ymir_plan` | Plan ledger: create/list/read |
| `ymir_note` | Append dated section to home doc |
| `ymir_header` | Document header check/apply |
| `ymir_push` | Commit and push named paths |
| `ymir_seats` | Where work is: panes/errands |
| `ymir_hall` | Whole house in one read |
| `ymir_arm` | Gná arm status |
| `ymir_place` | Place a document in home |
| `ymir_find_home` | Where should this file go? |
| `ymir_layout` | Layout law: shelf ownership |
| `ymir_import` | Import docs into home |
| `ymir_index` | Uncalled/stale/orphaned files |
| `ymir_dellingr` | Grade document freshness |
| `ymir_close_dead` | Close dead shell |
| `ymir_telegram` | Telegram across fleet |
| `skuld_branch_report` | Record branch outcome |

---

## Harness extensions (pi-only, cannot move to MCP)

These are TypeScript modules loaded by pi directly. They have no `bin/` script equivalents.

| Extension | What it does | Why it stays |
|---|---|---|
| `ask_user_question` | Ask user structured questions | Pi-only UI, no `bin/` equivalent |
| `ro` | Read-only gate | Infrastructure, not a tool |
| `syn-turnend-guard.ts` | Turn-end guard | Infrastructure |
| `whiteboard_tickets` | Ticket board operations | TypeScript modules, no `bin/` scripts |
| `whiteboard_servers` | Board/bridge/collab services | TypeScript modules, no `bin/` scripts |
| `logretta_sit` | Council debate rounds | Orchestrated in extension, no CLI yet |

---

## Summary

| Home | Count | Available to |
|---|---|---|
| Harness-native | ~29 | All harnesses (built in) |
| Ymir MCP | 33 | All harnesses (via MCP) |
| Harness extension | 6 | Pi only |
EOF
cat > /home/heimdall/ymir/docs/tool-inventory.md << 'EOF'
# Tool Inventory — Where Every Tool Lives

**Date:** 2026-11-21
**Plan:** 348 — Move harness extensions into Ymir MCP

## Three homes for tools

1. **Harness-native** — built into pi (and most other harnesses: Claude Code, Codex, OpenCode, Hermes, Cursor). Available to every harness without MCP.
2. **Ymir MCP** (`bin/mcp/ymir-mcp.py`) — house-specific tools that wrap `bin/` scripts. Available to every harness via MCP.
3. **Harness extension** — pi-only TypeScript modules. Available to pi only.

---

## Harness-native tools (come with every harness)

These are built into pi and equivalent harnesses. They do NOT need MCP wrappers.

| Tool | What it does |
|---|---|
| `read` | Read file contents |
| `edit` | Edit files with exact text replacement |
| `write` | Write/create files |
| `bash` | Execute shell commands |
| `ask_user_question` | Ask the user structured questions (pi-only UI) |
| `todo` | Manage task list |
| `subagent` | Dispatch Eindri figures |
| `context_left` | Check remaining context window |
| `web_search` | Search the web |
| `source_check` | Gather cited web passages |
| `fetch_content` | Fetch web pages, PDFs, repos |
| `memory_add` / `memory_replace` / `memory_remove` | Persistent memory |
| `memory_search` | Search extended memory |
| `session_search` | Search past conversations |
| `skill_manage` | Manage reusable skills |
| `mcp` | MCP gateway |
| `constellation_list` | List Ymir mesh peers |
| `constellation_card` | Read one peer's agent card |
| `constellation_ask` | Check a peer's declared skill |
| `gna_watch_arm` | Start Pi watcher cycle |
| `brokk_branch_outcomes` | Read supervision branch outcomes |
| `excalidraw_diagram` | Write .excalidraw scene from spec |
| `excalidraw_app` | Excalidraw desktop app status/start/stop |
| `logretta_stack` | Council roster status |
| `well_recall` | Recall from Kaia's memory |
| `well_observe` | Write lesson to Kaia's memory |
| `skuld_plan` | Read plan ledger |
| `skuld_ticket` | Read work queue |

---

## Ymir MCP tools (house-specific, available to all harnesses via MCP)

These wrap `bin/` scripts. No harness-native equivalent exists.

| Tool | What it does |
|---|---|
| `ymir_where` | Where Ymir is: repo, home, seat |
| `ymir_rule` | Read house law from RULES/ |
| `ymir_structure` | Shape of private home |
| `ymir_find` | Find files in home by name/content |
| `ymir_daily` | Today's log line in home |
| `ymir_calendar` | Calendar through Mánagandr |
| `ymir_heal` | Eir the healer: diagnose/mend |
| `ymir_gates` | Which gate covers which surface |
| `ymir_update` | Gróa the updater: check/renew |
| `ymir_secret_keys` | Which secret key names exist |
| `ymir_hermes_list` | List Hermes sessions |
| `ymir_hermes_send` | Send turn to Hermes session |
| `ymir_hermes_recover` | Recover paused Hermes session |
| `ymir_core_four` | Four dials for agent outcome |
| `ymir_pending` | Everything blocked on operator |
| `ymir_studio` | OpenDesign studio status |
| `ymir_errand` | Start/read/steer/close errand |
| `ymir_plan` | Plan ledger: create/list/read |
| `ymir_note` | Append dated section to home doc |
| `ymir_header` | Document header check/apply |
| `ymir_push` | Commit and push named paths |
| `ymir_seats` | Where work is: panes/errands |
| `ymir_hall` | Whole house in one read |
| `ymir_arm` | Gná arm status |
| `ymir_place` | Place a document in home |
| `ymir_find_home` | Where should this file go? |
| `ymir_layout` | Layout law: shelf ownership |
| `ymir_import` | Import docs into home |
| `ymir_index` | Uncalled/stale/orphaned files |
| `ymir_dellingr` | Grade document freshness |
| `ymir_close_dead` | Close dead shell |
| `ymir_telegram` | Telegram across fleet |
| `skuld_branch_report` | Record branch outcome |

---

## Harness extensions (pi-only, cannot move to MCP)

These are TypeScript modules loaded by pi directly. They have no `bin/` script equivalents.

| Extension | What it does | Why it stays |
|---|---|---|
| `ask_user_question` | Ask user structured questions | Pi-only UI, no `bin/` equivalent |
| `ro` | Read-only gate | Infrastructure, not a tool |
| `syn-turnend-guard.ts` | Turn-end guard | Infrastructure |
| `whiteboard_tickets` | Ticket board operations | TypeScript modules, no `bin/` scripts |
| `whiteboard_servers` | Board/bridge/collab services | TypeScript modules, no `bin/` scripts |
| `logretta_sit` | Council debate rounds | Orchestrated in extension, no CLI yet |

---

## Summary

| Home | Count | Available to |
|---|---|---|
| Harness-native | ~29 | All harnesses (built in) |
| Ymir MCP | 33 | All harnesses (via MCP) |
| Harness extension | 6 | Pi only |
EOF
echo "written"