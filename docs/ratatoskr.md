# Ratatoskr — the Ymir agent daemon (PLAN)

**Status: planning.** This is the working plan for Ymir's own A2A system. It is
not built yet; nothing here is final until it lands as code + a Galdr skill.

The squirrel runs the World Tree, carrying words between the eagle and the
dragon. Ratatoskr is the **daemon that runs on each user's machine**, makes that
machine's agents discoverable and taskable, and links them to other machines and
to **Way of Teams** — the product we sell.

## The idea in one line

One daemon per user machine: it syncs the local agents, lets them orchestrate
with each other locally, extends that over the user's other machines, and — when
the user has Teams — bridges up to the cloud control plane. On its own it works
standalone.

## What the daemon does

```
ratatoskr-daemon[5]{job,detail}:
  "registry","publish an Agent Card for every local agent (Brokk, Eindri, opencode/pi/claude sessions); discovery is capability-based"
  "local mesh","agents on the same machine discover and task each other over loopback — the A2A task lifecycle (submitted→working→completed) with SSE streaming"
  "cross-machine","reach the user's other machines peer-to-peer over Tailscale; tasks route to whichever machine holds the right agent"
  "cloud bridge","optionally sync up to Way of Teams — tickets become A2A tasks, results flow back; disabled = fully standalone"
  "metrics","emit agent/run/task metrics to Smiðja, Hlidskjalf, and (if enrolled) Way of Teams"
```

## Architecture

```
┌─ USER MACHINE ────────────────────────────────────────────────┐
│  agents (Brokk · Eindri · harness sessions)                   │
│        │  register / task via A2A (JSON-RPC 2.0 + SSE)        │
│        ▼                                                      │
│  RATATOSKR DAEMON  ── local registry (Agent Cards)            │
│        ├── local mesh (loopback)                              │
│        ├── peer transport (Tailscale)  ⇄ other machines       │
│        ├── metrics exporter → Smiðja · Hlidskjalf             │
│        └── cloud bridge (optional)                            │
└───────────────┬───────────────────────────────────────────────┘
                │  A2A over TLS (enrolled users)
                ▼
     WAY OF TEAMS  (control plane · the product)
     tickets · plans · standups · kanban · docs · knowledge ·
     memory · coordinator agent · multi-agent orchestration
                ▲
     Ymir Hlidskjalf + Smiðja  (observability for the operator)
```

## Standalone vs Teams

- **Standalone** is the default: the daemon needs no account. Local agents
  orchestrate; the user's own machines collaborate over their tailnet.
- **Teams** is an *opt-in enrollment*: the same mesh gains a cloud control plane
  for cross-user / cross-org multi-agent orchestration, shared knowledge, and
  the sold product features. Turning it off must leave everything local working.

## Protocol & boundaries (already law)

- **A2A 1.0** — JSON-RPC 2.0, SSE, Agent Cards at `/.well-known/agent-card.json`.
- **Realm boundaries are sacred** — no message leaks across realms/tenants.
- **Audit everything** — every A2A message observed into Mimirsbrunn, logged to
  Runes.
- **Open-source-first** — reuse a validated A2A engine; Ymir owns the daemon,
  integration, and UI, not the wire protocol.

## Milestones

```
ratatoskr-milestones[5]{n,goal,done_when}:
  "M1","daemon + local mesh","one daemon starts, registers local agents, routes a task between two of them locally"
  "M2","cross-machine","a task from machine A runs an agent on machine B over Tailscale"
  "M3","metrics","Smiðja + Hlidskjalf show live agent/task metrics from the daemon"
  "M4","cloud bridge","an enrolled user's tasks/updates sync to Way of Teams and back"
  "M5","orchestration UI","Hlidskjalf + Teams show and steer multi-agent, multi-machine work"
```

## Open decisions (pick before M1)

1. **Language/runtime** for the daemon (Go · Rust · TypeScript/Node).
2. **Reuse or write:** which A2A engine (if any) — no Jido/Elixir assumed.
3. **Transport:** Tailscale-only P2P first, cloud relay later?
4. **Queue:** in-process first, Redis only if needed.
5. **Agent Cards:** per agent / per machine / per realm; how identity is signed.
6. **Enrollment/auth:** how a machine joins Teams (token · Heimdall · device key).
7. **Metrics schema:** what Smiðja/Hlidskjalf/Teams each ingest.
8. **Packaging:** how the daemon ships (`bin/ymir-install.sh`, systemd --user).

## Repos

- **Ymir** (this repo) — the daemon, the framework, the operator UI (Hlidskjalf).
- **Way of Teams** — `~/CodeP/wayofteams` — the sold product / control plane.
- **wayofa2a** — `~/CodeP/wayofa2a` — earlier A2A experiments; mine for parts,
  not a dependency.
