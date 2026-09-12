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

## Joining the mesh and talking (skill-driven, no code)

A seated Eindri joins and talks **by loading this skill** — the pi adaptor
(`a2a-send` / `a2a-discover`) and the `a2abridge` MCP provide the tools; this
skill says how to use them.

**Every pi agent already carries the tools** (pi loads `Way-Of/pi-a2a-adaptor` +
the `a2abridge` MCP). So inside a session:

- `a2a-agents` / `a2a-discover` — list peers registered with the directory.
- `a2a-send <peer> "<text>"` — task a peer; the reply comes back as a task.
- `a2a-broadcast "<text>"` — FYI to the mesh.

**To be reachable**, the agent's bridge must announce to the directory
(`~/.pi/agent/mcp.json` → `a2abridge`, `A2A_DIRECTORY`). If a peer does not
appear in `a2a-agents`, the bridge announced to the wrong directory — the fix is
in the **skill/config**, not new code: point the bridge at
`http://127.0.0.1:7777` with `-advertise-host <tailnet-ip>` and `-name <agent>`.

**Outside a session** (Brokk, scripts): `bin/a2a-talk.sh agents` and
`bin/a2a-talk.sh send <peer> "<text>"`.

Rule: the mesh is used through the **skill's tools**, not bespoke code — if a
capability is missing, extend this skill.

## Delivering a message = injection into the chat

An A2A task that only reaches the bridge is **never read**. The missing function
is **injection**: the inbound text must be placed into the seated agent's chat.

- **Talk to (deliver to) an Eindri:** `herdr agent prompt <agent-or-pane> "<text>"`
  — the agent reads it as a new turn and answers in its pane.
- **Capture the reply:** `herdr agent read <agent-or-pane>` (or pane read) and
  attach it to the A2A task result.
- **The rule:** A2A carries the task; **herdr injection makes the target agent
  read it.** Without injection, an Eindri will not read the a2a.

So the two halves are inseparable:
```
a2a-deliver[2]{half,mechanism}:
  "transport","A2A message/send -> the bridge (JSON-RPC, SSE)"
  "delivery","inject into the agent's chat via `herdr agent prompt`; read the reply back"
```

Any agent that can *send* over A2A must also *deliver* by injection on receipt.
Extend this skill (not code) when the delivery path changes.

## Peer addressing — names are NOT URLs

The A2A tools take an **agent URL** (`a2a_call(agent_url, ...)`). A peer *name*
like `hermes-zerwiz` is **not** a URL and fails with `Invalid URL`.

**Always resolve first:** call `a2a-agents` (or `a2a-discover`) → find the peer →
use its **`url`** field. Then `a2a_call(agent_url="<url>", text="…")`.

```
resolve[1]: a2a-agents -> [{"name":"hermes-zerwiz","url":"http://127.0.0.1:7777/"}, …]
send[1]:    a2a_call agent_url="http://127.0.0.1:7777/" text="…"
```

## Tool reference (as shipped in pi)

- **`a2a_call`** — args: `agent_url` (a URL string), `text`. Sends a task and
  returns the reply. **`agent_url` must be a URL** — a name fails `Invalid URL`.
- **`a2a-agents` / `a2a-discover`** — list peers as `{name, url, skills}`; use
  the `url` to address one.
- **`a2a-send-async`**, **`a2a-pending`**, **`a2a-conversations`** — long tasks.
- **`a2a-broadcast`**, **`a2a-chain`** — fan-out to the mesh.
- **Delivery on receipt** is injection (`herdr agent prompt <agent> "<text>"`);
  the reply is read back with `herdr agent read <agent>` and attached to the task.

Directory: `http://127.0.0.1:7777`. Config: `~/.pi/agent/mcp.json` → `a2abridge`.
