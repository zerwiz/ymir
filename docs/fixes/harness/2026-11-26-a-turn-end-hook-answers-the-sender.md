# A turn-end hook answers the sender

## What went wrong

No harness sent anything to the sender when a turn ended.

## What changed

A thin hook for Claude Code (`.claude/hooks/reply-back.sh`), pi (`.pi/extensions/reply-back.ts`) and OpenCode (`plugins/reply-back.js`) hands the turn to `reply.sh`.

## Proof

Claude Code and pi hooks answered in real panes. The OpenCode turn reader was checked in node; it has not run in a live OpenCode session.
