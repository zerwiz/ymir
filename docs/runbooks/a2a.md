# Runbook — A2A (Ratatoskr), talking between agents

Ratatoskr is Ymir's A2A/MCP mesh: agents discover each other and exchange tasks
over the open **A2A 1.0** protocol (JSON-RPC + SSE, Agent Cards), locally and
across machines over Tailscale. **Way of Teams** rides the same mesh as the
control plane.

## The pieces

```
a2a[4]{piece,what,path}:
  "engine","a2abridge — directory (discovery) · bridge (announce) · service · cert · doctor","~/.a2abridge/bin/a2abridge"
  "MCP (mesh)","a2abridge — a2a_* tools for the agents","~/.pi/agent/mcp.json, opencode.json"
  "MCP (control plane)","wayofteams-* — tickets, plans, memory, knowledge (NEEDS AUTH)","WOTEAMS_URL / WOTEAMS_TOKEN"
  "Ymir front door","bin/ratatoskr.sh, bin/a2a-mcp.sh","bin/"
```

## Setup

```bash
bin/a2a-mcp.sh install     # wires the MCP servers into pi + opencode
bin/ratatoskr.sh status    # engine + directory + served agents
bin/ratatoskr.sh doctor    # health-check
```
`bin/ymir-install.sh` and `bin/brokk-update.sh` run the migration that does this.

**The control plane needs auth.** In an MCP host you may see:
```
wayofteams-agents  Needs auth
wayofteams-core    Needs auth
```
Set `WOTEAMS_URL` and `WOTEAMS_TOKEN` (from `.env.local` / your Hoard) to
connect them. `a2abridge` should read **Connected**.

## Talking

**From an agent** (pi — tools come from the `a2abridge` MCP + `Way-Of/pi-a2a-adaptor`;
the `ratatoskr-a2a` skill teaches their use):

```bash
a2a-agents                              # list peers {name,url,skills}
a2a_call agent_url="http://host:7777/" text="…"   # task a peer; reply returns
a2a_inbox                               # your incoming queue
a2a_complete_task task_id="…" text="…"  # answer a task
```

**From Brokk / scripts:** `bin/a2a-talk.sh agents` and
`bin/a2a-talk.sh send <peer> "<text>"`.

## Rules that bite

- **Names are NOT URLs.** `a2a_call` wants a **URL**; a peer name fails
  `Invalid URL`. Resolve first with `a2a-agents`, then use its `url`.
- **Delivery = injection.** An A2A task that only reaches the bridge is never
  read; the inbound text must be **injected into the agent's chat**
  (`herdr agent prompt <agent> "<text>"`), and the reply read back
  (`herdr agent read`). Without injection an Eindri will not read the a2a.
- **All four, or it fails:** transport + a live peer + delivery (injection) +
  return. Missing any one shows as a timeout.

## Reachability (registering an Eindri)

An agent must **announce to the directory** to appear in `a2a-agents`:

```bash
a2abridge bridge -name <agent> -model <model> -skills <s1,s2> \
  -directory http://127.0.0.1:7777 -advertise-host <tailnet-ip> -id <stable>
```
`-advertise-host` must be the machine's **Tailscale IP** (never 127.0.0.1) for
cross-machine reach. If a peer is missing from `a2a-agents`, the bridge announced
to the wrong directory — fix the **config/skill**, not new code.

## Troubleshooting

- **`Invalid URL`** — you passed a name; resolve with `a2a-agents`, then `a2a_call`.
- **`Task … exceeded max attempts (N)`** — addressed right, never completed: no
  live receiving agent / injection / return. Check the peer is in `a2a-agents`
  and a receiving agent is running its bridge.
- **No reply at all** — transport carried it; the **return path** is missing.
- **`wayofteams-* Needs auth`** — set `WOTEAMS_TOKEN`; the mesh still works
  standalone without it.

## Status

```
a2a-today[3]{piece,state}:
  "transport","works (messaged hermes -> reply)"
  "delivery (injection)","works (an agent reads an injected task and answers)"
  "directory registration + return","OPEN — a served Eindri is not yet listed in the directory"
```
See the private plan `$YMIR_HOME/docs/ratatoskr.md` for the registration spec.
