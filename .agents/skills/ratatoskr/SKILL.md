---
name: ratatoskr
description: >-
  Ratatoskr — Ymir's A2A 1.0 collaboration backbone. Load when agents
  collaborate across sessions/machines, when dispatching cross-agent work,
  when integrating with Way of Teams, or when the a2a directory / bridge is
  involved. Teaches discovery (agent cards), task lifecycle, and the standalone
  vs Way-of-Teams modes.
allowed-tools: read,write,bash,glob,grep
---

# Ratatoskr — the A2A backbone

The squirrel runs the World Tree, carrying words between the eagle and the
dragon. Ymir's agent-to-agent collaboration runs on the open **A2A 1.0**
protocol — JSON-RPC 2.0 over HTTPS with SSE streaming and published Agent Cards.

## The stack (source of truth: `~/CodeP/wayofa2a`, npm `wayof-a2a-bridge`)

```
a2a[3]{layer,what,where}:
  "SDK","wayof-a2a-bridge — register/listAgents/sendMessage/sendStreaming/inbox/completeTask","~/CodeP/wayofa2a (TS, npm wayof-a2a-bridge)"
  "data plane","a2a_jido — the A2A mesh/directory (Elixir/Jido)","~/CodeP/wayofa2a/a2a_jido"
  "control plane","Way of Teams — tickets · plans · standups · kanban · docs · knowledge · memory · coordinator","your Way of Teams system"
```

Agents publish an **Agent Card** (`/.well-known/agent-card.json`); discovery is
capability-based. The bridge exposes the `a2a_*` tools via MCP; the `a2a-bridge`
skill teaches the messaging etiquette.

## Two modes

- **Standalone:** Ymir agents (Brokk, Eindri) discover and task each other over
  the local mesh — no Way of Teams required. Tasks are A2A tasks with the same
  lifecycle (`submitted → working → completed`, SSE streaming).
- **Way of Teams:** the same A2A mesh is the data plane under Way of Teams'
  control plane — tickets become A2A tasks, the Coordinator agent routes them,
  and results flow back into knowledge/memory. See
  `~/CodeP/wayofa2a/WAY_OF_TEAMS_INTEGRATION.md`.

## In Ymir

- Every A2A message is observed into **Mimirsbrunn** and logged to **Runes**.
- Kaia (orchestrator) recalls memory before dispatch and honours the
  anti-hallucination gate.
- Cross-machine transport rides **Tailscale** (see the Tailscale runbook).
- Realm boundaries hold: collaboration is scoped per realm.

A change to the protocol or a new capability edits this skill, not a new one.
