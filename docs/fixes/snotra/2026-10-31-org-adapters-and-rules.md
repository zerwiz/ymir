# Fix note — Organization adapters, rules engine, action router, channel adapters

**Component:** snotra
**Date:** 2026-10-31
**Plan:** 144

## What changed

Added the organization tool adapter interface and 6 new adapters (Monday, Asana,
Jira, ClickUp, Notion, Linear), the rules engine with inheritance, the action
router for transcription-to-action across channels, and email/todo channel adapters.

## Why

Plan 144 requires multi-tool support beyond Trello. The adapter interface lets
the projection and automation scripts work with any organization tool without
knowing which one is behind it. The rules engine provides per-board, per-project,
per-company behavioral control. The action router routes meeting outcomes to
multiple channels (email, todo, calendar, chat, knowledge base).

## Verification

All 14 new files pass python3 -m py_compile. Shell scripts pass bash -n.
