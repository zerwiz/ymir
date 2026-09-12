# Tailscale-based Sync System for Ymir

## Goals

- Keep the operator's own machines in sync with minimal friction.
- Allow user-installable sync behavior so operators can choose whether to trust Tailscale.
- Preserve isolation between machines by default; only share state when explicitly authorized.
- Ensure the system is durable enough to survive restarts, network changes, and machine churn.

## Architecture

The system runs on a single operator machine and uses Tailscale as the transport layer. It does not require a central server or relay unless the operator chooses to expose one.

The architecture has three layers:

1. **Operator Machine Layer** — Each machine runs a local sync agent (`pi-agent`) that communicates with other machines via Tailscale.
2. **State Layer** — Data is stored in local Pi databases and agent state files. Changes are written to a durable local store before syncing.
3. **Sync Layer** — Changes are broadcast to peers using Tailscale's encrypted mesh. Peers pull updates from the source machine if needed.

The operator controls which machines are trusted peers and whether state should be shared. By default, no machine shares state with another unless explicitly added.

## Components

- `pi-agent` — The local agent that runs on each machine. It manages local state, detects changes, and syncs with trusted peers.
- `state/local.db` — The local Pi database that stores agent state, prompts, and runtime metadata.
- `state/agent.json` — The agent configuration file that defines trusted peers, sync intervals, and behavior policies.
- `state/sync.log` — A durable log of sync events for auditing and recovery.

The agent uses Tailscale's native Go client under the hood, wrapped in a Pi-compatible interface so it can work with any Pi extension.

## Data Synced

Only agent state and Pi database changes are synced. No code files, prompts, or prompts are shared unless explicitly requested.

- `state/local.db`
- `state/agent.json`
- `state/sync.log`

Changes are written to the local store first, then synced to trusted peers. This ensures durability even if the sync fails.

## Security

- Tailscale encrypts all traffic between machines.
- The operator controls which machines are trusted peers.
- By default, no machine shares state with another unless explicitly added.
- The system does not require a central server or relay unless the operator chooses to expose one.

The operator can revoke access from any machine at any time by removing it from the trusted peers list.

## Install Steps

1. Install the `pi-agent` binary on each machine.
2. Run `pi-agent init` to create the local state directories.
3. Edit `state/agent.json` to add trusted peers.
4. Start the agent with `pi-agent start`.
5. Verify connectivity with `pi-agent status`.

The agent will sync changes automatically at regular intervals. Operators can adjust the sync interval in `state/agent.json` if needed.

## Risks

- If a machine is compromised, it can share state with other machines.
- If the operator does not control the trusted peers list, the system may not preserve isolation.
- If the operator does not understand the behavior policies, the system may not meet their needs.

The system is designed to be secure by default, but operators should review the trusted peers list and behavior policies before using it in production.
