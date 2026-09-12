---
name: ratatoskr
description: >-
  Ratatoskr — Ymir's A2A/MCP mesh. Load when agents collaborate, when wiring or
  debugging the a2abridge/A2A directory, when using the wayofteams control-plane
  MCP, when registering an Eindri over A2A, or when a task is dispatched between
  machines. Covers the engine, the Ymir front door, and both MCPs together.
allowed-tools: read,write,bash,glob,grep
---

# ratatoskr-a2a — A2A/MCP mesh — a2abridge + wayofteams; registration

The squirrel runs the World Tree. Agents collaborate over **A2A 1.0** (JSON-RPC +
SSE, Agent Cards) via the **`a2abridge`** engine, and coordinate through the
**Way of Teams** control plane — **both MCP servers at once**.

## The pieces

```
parts[4]{thing,path,role}:
  "engine","~/.a2abridge/bin/a2abridge","directory (discovery) · bridge (announce) · service · cert · doctor"
  "front door","bin/ratatoskr.sh","status|doctor|directory|service|cert — Ymir's wrapper"
  "wiring","bin/a2a-mcp.sh","installs both MCP servers into pi + opencode"
  "registration","a2abridge bridge -name -model -skills -directory -advertise-host -id -state-dir","an agent announces by running bridge"
```

## Two MCPs, together

- **`a2abridge`** — the mesh: `a2a_list_agents`, `a2a_send_message`, `a2a_inbox`,
  `a2a_complete_task`. Peer-to-peer; standalone.
- **`wayofteams`** — control plane: tickets, plans, standups, memory, knowledge.

Complementary, not competing. Neither depends on the other. Glue: a Teams
**ticket → `a2a_send_message`** to the peer; on **`a2a_complete_task`** the result
goes back to Teams. Same `A2A_NAME` in both planes.

## Use it

```bash
bin/ratatoskr.sh status          # engine + directory + served agents
bin/ratatoskr.sh doctor          # health-check
bin/a2a-mcp.sh install           # (re)wire the MCP servers into pi + opencode
```

**Production rules:** stable `-id`, `-advertise-host` = the machine's **Tailscale
IP** (never 127.0.0.1), state in `.a2a/<agent>`, the directory as a **service**,
heartbeat + deregister, and `cert` (ed25519) before federation. Cards are
UNSIGNED until then. Realm boundaries hold.

Plan + registration spec: `hodd/docs/ratatoskr.md` and `hodd/docs/a2a-runs.md`.
