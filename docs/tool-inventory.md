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



---

## Gimlé MCP tools (hosted, available to all harnesses via MCP)

Gimlé is the suite record: places, tasks owed, meetings, plans, documents, shared whiteboard scenes. Available at `https://mcp.zerwiz.org/mcp`.

### Identity & places
| Tool | What it does |
|---|---|
| `gimle_who_am_i` | Who the caller is and which places they may touch |
| `gimle_list_places` | Places this caller belongs to, with counts |
| `gimle_list_members` | People in a place's workspace |
| `gimle_list_states` | A place's states in board order |
| `gimle_list_labels` | A place's labels |
| `gimle_create_label` | Make a label in a place |

### Work items (cards)
| Tool | What it does |
|---|---|
| `gimle_create_card` | File a work item into one place |
| `gimle_update_card` | Change a work item: title, state, assignees, labels, etc. |
| `gimle_get_card` | One work item in full |
| `gimle_list_cards` | Work items in one place, filtered |
| `gimle_search_cards` | Find work items by title across places |
| `gimle_delete_card` | Delete a work item permanently |
| `gimle_add_comment` | Comment on a work item, optionally tag people |
| `gimle_add_link` | Attach a link to a work item |

### Board & cycles
| Tool | What it does |
|---|---|
| `gimle_place_board` | One place's open work: actions and questions |
| `gimle_my_tasks` | Actions owed by the caller |
| `gimle_who_owes_what` | Register across caller's places |
| `gimle_list_cycles` | A place's cycles (sprints) with dates |
| `gimle_create_cycle` | Start a cycle in a place |
| `gimle_add_to_cycle` | Put work items into a cycle |
| `gimle_list_modules` | A place's modules (features/epics) |
| `gimle_create_module` | Make a module |
| `gimle_add_to_module` | Put work items into a module |

### Meetings & plans
| Tool | What it does |
|---|---|
| `gimle_meeting_record` | Decisions, questions, actions of one meeting |
| `gimle_list_plans` | Plans the hall mirrors for a project |
| `gimle_read_plan` | Read one mirrored plan document |

### Documents
| Tool | What it does |
|---|---|
| `gimle_find_doc` | Search AFFiNE documents by title/content |

### Whiteboard
| Tool | What it does |
|---|---|
| `gimle_read_canvas` | Read a whiteboard room's elements as data |
| `gimle_add_elements` | Place nodes and edges on a granted room |
| `gimle_update_elements` | Move, relabel, recolour elements |
| `gimle_validate_diagram` | Check a diagram before offering it |
| `gimle_focus` | Frame or highlight a region of a room |
| `gimle_save_room` | Save a granted room's scene |
| `gimle_share_room` | Produce a granted room's invite link |
| `gimle_snapshot` | Write a room's scene to disk |
| `gimle_shortcuts` | Look up whiteboard keyboard shortcuts |

### Contract
| Tool | What it does |
|---|---|
| `gimle_board_contract` | The board contract this door implements |

---



---

## Other MCP servers

### Bolthorn (local, :8316)
| Tool | What it does |
|---|---|
| `bolthorn_sync` | Push body's write journal to heart |
| `bolthorn_load_skill` | Return a Ymir skill's SKILL.md |

### Firecrawl (web scraping/search)
31 tools including: `firecrawl_scrape`, `firecrawl_search`, `firecrawl_crawl`, `firecrawl_map`, `firecrawl_agent`, `firecrawl_interact`, `firecrawl_monitor_*`, `firecrawl_research_*`, etc.

### Skuld (tickets & plans)
17 tools: `skuld_tickets_create/list/get/update`, `skuld_plans_create/list/get/update/pending`, `skuld_namespaces_list/create`, `skuld_comments_list/post`, `skuld_blocks_status/clear`, `skuld_sync/snapshot`

### Snotra (meeting minutes)
5 tools: `snotra_list`, `snotra_read`, `snotra_search`, `snotra_summary`, `snotra_read_the_ear`

### Well (Notion memory)
10 tools: `well_sync`, `well_remember_fact`, `well_create_page`, `well_update_page`, `well_log_to_notion`, `well_list_sub_pages`, `well_read_page_content`, `well_send_alert`, `well_search_memory`, `well_get_recent_memories`

### Hnoss (Open Design)
10 tools: `hnoss_od_list_projects`, `hnoss_od_get_project`, `hnoss_od_create_project`, `hnoss_od_update_project`, `hnoss_od_delete_project`, `hnoss_od_save_artifact`, `hnoss_od_lint_artifact`, `hnoss_od_compose_brief`, `hnoss_od_generate_design`, `hnoss_od_save_project_file`

### Smidja (smithy)
18 tools: `smidja_doctor`, `smidja_up`, `smidja_chains`, `smidja_rosters`, `smidja_run`, `smidja_sessions`, `smidja_record`, `smidja_phases`, `smidja_events`, `smidja_gates`, `smidja_envelopes`, `smidja_control`, `smidja_emergency_stop`, `smidja_resume`, `smidja_decide`, `smidja_judge`, `smidja_memory`, `smidja_volundr`

### Atlas Vault (documents)
12 tools: `atlas-vault_ask_librarian`, `atlas-vault_search_vault`, `atlas-vault_find_in_document`, `atlas-vault_check_answer`, `atlas-vault_list_folder`, `atlas-vault_list_my_documents`, `atlas-vault_get_document`, `atlas-vault_get_versions`, `atlas-vault_vault_stats`, `atlas-vault_get_document_card`, `atlas-vault_get_rendition_url`, `atlas-vault_read_kontering`

### Trello (action register)
15 tools: `trello_trelloReadCard`, `trello_trelloReadBoard`, `trello_trelloReadChecklist`, `trello_trelloReadInbox`, `trello_trelloReadList`, `trello_trelloReadMember`, `trello_trelloReadPlanner`, `trello_trelloReadWorkspace`, `trello_trelloWriteBoard`, `trello_trelloWriteCard`, `trello_trelloWriteChecklist`, `trello_trelloWriteInbox`, `trello_trelloWriteList`, `trello_trelloSearch`, `trello_trelloWritePlanner`

### A2A Bridge (mesh)
1 tool: `a2abridge` (bridge binary, not MCP tool)

## Updated summary

| Home | Count | Available to |
|---|---|---|
| Harness-native | ~29 | All harnesses (built in) |
| Ymir MCP | 33 | All harnesses (via MCP) |
| Gimlé MCP | 37 | All harnesses (via MCP) |
| Harness extension | 6 | Pi only |

## Summary

| Home | Count | Available to |
|---|---|---|
| Harness-native | ~29 | All harnesses (built in) |
| Ymir MCP | 33 | All harnesses (via MCP) |
| Gimlé MCP | 37 | All harnesses (via MCP) |
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



---

## Gimlé MCP tools (hosted, available to all harnesses via MCP)

Gimlé is the suite record: places, tasks owed, meetings, plans, documents, shared whiteboard scenes. Available at `https://mcp.zerwiz.org/mcp`.

### Identity & places
| Tool | What it does |
|---|---|
| `gimle_who_am_i` | Who the caller is and which places they may touch |
| `gimle_list_places` | Places this caller belongs to, with counts |
| `gimle_list_members` | People in a place's workspace |
| `gimle_list_states` | A place's states in board order |
| `gimle_list_labels` | A place's labels |
| `gimle_create_label` | Make a label in a place |

### Work items (cards)
| Tool | What it does |
|---|---|
| `gimle_create_card` | File a work item into one place |
| `gimle_update_card` | Change a work item: title, state, assignees, labels, etc. |
| `gimle_get_card` | One work item in full |
| `gimle_list_cards` | Work items in one place, filtered |
| `gimle_search_cards` | Find work items by title across places |
| `gimle_delete_card` | Delete a work item permanently |
| `gimle_add_comment` | Comment on a work item, optionally tag people |
| `gimle_add_link` | Attach a link to a work item |

### Board & cycles
| Tool | What it does |
|---|---|
| `gimle_place_board` | One place's open work: actions and questions |
| `gimle_my_tasks` | Actions owed by the caller |
| `gimle_who_owes_what` | Register across caller's places |
| `gimle_list_cycles` | A place's cycles (sprints) with dates |
| `gimle_create_cycle` | Start a cycle in a place |
| `gimle_add_to_cycle` | Put work items into a cycle |
| `gimle_list_modules` | A place's modules (features/epics) |
| `gimle_create_module` | Make a module |
| `gimle_add_to_module` | Put work items into a module |

### Meetings & plans
| Tool | What it does |
|---|---|
| `gimle_meeting_record` | Decisions, questions, actions of one meeting |
| `gimle_list_plans` | Plans the hall mirrors for a project |
| `gimle_read_plan` | Read one mirrored plan document |

### Documents
| Tool | What it does |
|---|---|
| `gimle_find_doc` | Search AFFiNE documents by title/content |

### Whiteboard
| Tool | What it does |
|---|---|
| `gimle_read_canvas` | Read a whiteboard room's elements as data |
| `gimle_add_elements` | Place nodes and edges on a granted room |
| `gimle_update_elements` | Move, relabel, recolour elements |
| `gimle_validate_diagram` | Check a diagram before offering it |
| `gimle_focus` | Frame or highlight a region of a room |
| `gimle_save_room` | Save a granted room's scene |
| `gimle_share_room` | Produce a granted room's invite link |
| `gimle_snapshot` | Write a room's scene to disk |
| `gimle_shortcuts` | Look up whiteboard keyboard shortcuts |

### Contract
| Tool | What it does |
|---|---|
| `gimle_board_contract` | The board contract this door implements |

---



---

## Other MCP servers

### Bolthorn (local, :8316)
| Tool | What it does |
|---|---|
| `bolthorn_sync` | Push body's write journal to heart |
| `bolthorn_load_skill` | Return a Ymir skill's SKILL.md |

### Firecrawl (web scraping/search)
31 tools including: `firecrawl_scrape`, `firecrawl_search`, `firecrawl_crawl`, `firecrawl_map`, `firecrawl_agent`, `firecrawl_interact`, `firecrawl_monitor_*`, `firecrawl_research_*`, etc.

### Skuld (tickets & plans)
17 tools: `skuld_tickets_create/list/get/update`, `skuld_plans_create/list/get/update/pending`, `skuld_namespaces_list/create`, `skuld_comments_list/post`, `skuld_blocks_status/clear`, `skuld_sync/snapshot`

### Snotra (meeting minutes)
5 tools: `snotra_list`, `snotra_read`, `snotra_search`, `snotra_summary`, `snotra_read_the_ear`

### Well (Notion memory)
10 tools: `well_sync`, `well_remember_fact`, `well_create_page`, `well_update_page`, `well_log_to_notion`, `well_list_sub_pages`, `well_read_page_content`, `well_send_alert`, `well_search_memory`, `well_get_recent_memories`

### Hnoss (Open Design)
10 tools: `hnoss_od_list_projects`, `hnoss_od_get_project`, `hnoss_od_create_project`, `hnoss_od_update_project`, `hnoss_od_delete_project`, `hnoss_od_save_artifact`, `hnoss_od_lint_artifact`, `hnoss_od_compose_brief`, `hnoss_od_generate_design`, `hnoss_od_save_project_file`

### Smidja (smithy)
18 tools: `smidja_doctor`, `smidja_up`, `smidja_chains`, `smidja_rosters`, `smidja_run`, `smidja_sessions`, `smidja_record`, `smidja_phases`, `smidja_events`, `smidja_gates`, `smidja_envelopes`, `smidja_control`, `smidja_emergency_stop`, `smidja_resume`, `smidja_decide`, `smidja_judge`, `smidja_memory`, `smidja_volundr`

### Atlas Vault (documents)
12 tools: `atlas-vault_ask_librarian`, `atlas-vault_search_vault`, `atlas-vault_find_in_document`, `atlas-vault_check_answer`, `atlas-vault_list_folder`, `atlas-vault_list_my_documents`, `atlas-vault_get_document`, `atlas-vault_get_versions`, `atlas-vault_vault_stats`, `atlas-vault_get_document_card`, `atlas-vault_get_rendition_url`, `atlas-vault_read_kontering`

### Trello (action register)
15 tools: `trello_trelloReadCard`, `trello_trelloReadBoard`, `trello_trelloReadChecklist`, `trello_trelloReadInbox`, `trello_trelloReadList`, `trello_trelloReadMember`, `trello_trelloReadPlanner`, `trello_trelloReadWorkspace`, `trello_trelloWriteBoard`, `trello_trelloWriteCard`, `trello_trelloWriteChecklist`, `trello_trelloWriteInbox`, `trello_trelloWriteList`, `trello_trelloSearch`, `trello_trelloWritePlanner`

### A2A Bridge (mesh)
1 tool: `a2abridge` (bridge binary, not MCP tool)

## Updated summary

| Home | Count | Available to |
|---|---|---|
| Harness-native | ~29 | All harnesses (built in) |
| Ymir MCP | 33 | All harnesses (via MCP) |
| Gimlé MCP | 37 | All harnesses (via MCP) |
| Harness extension | 6 | Pi only |

## Summary

| Home | Count | Available to |
|---|---|---|
| Harness-native | ~29 | All harnesses (built in) |
| Ymir MCP | 33 | All harnesses (via MCP) |
| Gimlé MCP | 37 | All harnesses (via MCP) |
| Harness extension | 6 | Pi only |
EOF
echo "written"