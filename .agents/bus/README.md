# RATATOSKR — Inter-Agent Message Bus

Low-latency event queue carrying messages between agents, realms, and services.

## Planned Files
- `protocol.ts` — `InterAgentMessage` schema (sender/recipient/type/payload/status)
- `messages.json` — active message queue state (exists)

## Message Flow
1. Broker (Redis or file-backed) dispatches messages
2. Inbox consumers (agents) poll for pending tasks
3. All messages audited to `workspace/memory/runes_audit.md`