# 2026-11-23 — MCP consolidation: keep the house doors, drop the duplicates

Plan 348: the Ymir MCP server carried the same tools that pi already has built in
(web search, file reads, basic git). This removes the duplicates so the MCP exposes
only the house-specific doors (memory, plans, the well, the board, the fleet) and
keeps the `ymir_`-prefixed tools that are extensions rather than built-ins.

- 212 files: 269 added, 11,600 removed. The tool inventory doc moves to the ymir
  home; the tests it dropped are replaced by the house's own gate checks.
- The `ymir_veil`, `ymir_board_sync` and `ymir_publish` doors are kept (they are
  house doors, not built-ins).

At the operator's word.
