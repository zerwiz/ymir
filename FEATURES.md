# FEATURES — what Ymir does

The **master list of Ymir's features and functions.** One row per feature: what it
is, what it gives you, and how to use it.

**This file is append-only (Rule 06).** A feature lands → its row is added. A
feature changes → its row is corrected by a NEW row or a note citing the old one;
rows are never silently rewritten away. The list grows for the life of the project —
*"we can do so much"; this is the ledger of it.*

**`how-to`** points at the plain-language page under [`docs/features/`](docs/features/)
when one exists. **A feature with no page is a feature no user can use** — a blank
`how-to` is a debt, not a default. Agents: when you ship a user-facing feature, add
its row here and write its page (see `AGENTS.md` → *Feature how-tos*).

---

## Core — install, run, operate

| Area | Feature | What it gives you | how-to |
|---|---|---|---|
| Install | `install.sh` / `bin/engine/ymir-install.sh` | One command installs Ymir into a prefix you own, writes PATH, runs first setup, then proves it | [docs/features/install-ymir.md](docs/features/install-ymir.md) |
| Runtime | The engine (`src/ymir_runtime/`) | The runtime core behind every door: `seat · status · send · stop` | [docs/features/the-engine.md](docs/features/the-engine.md) |
| Agent | Brokk (the primary) | The counsellor: plans, steers, reviews, dispatches — one agent, any harness (Pi · OpenCode · Claude Code · Codex · Cursor) | [docs/features/brokk-the-primary-agent.md](docs/features/brokk-the-primary-agent.md) |
| Workers | Eindri (isolated sub-agents) | Complex work forged in isolation, never in the main tree | [docs/features/eindri-isolated-workers.md](docs/features/eindri-isolated-workers.md) |
| Isolation | Yggdrasil (worktrees) + Utgard (sandbox) | Parallel branches, zero collision; untrusted code runs sandboxed | [docs/features/yggdrasil-and-utgard-isolation.md](docs/features/yggdrasil-and-utgard-isolation.md) |
| Session | Sága (session-start digest) | Boots a session: what stands, what is owed, what the seat is | [docs/features/saga-the-session-start.md](docs/features/saga-the-session-start.md) |
| Record | The plan ledger + Runes (audit) | Every plan and every significant action, written down, never lost | [docs/features/the-plan-ledger-and-runes.md](docs/features/the-plan-ledger-and-runes.md) |
| Updates | Gróa (updater) | Fast-forwards Brokk and its homes, then mends forward | [docs/features/groa-and-eir-update-and-heal.md](docs/features/groa-and-eir-update-and-heal.md) |
| Health | Eir (the healer) | Diagnoses every surface, then mends what is broken | [docs/features/groa-and-eir-update-and-heal.md](docs/features/groa-and-eir-update-and-heal.md) |
| Gate | The wards (`bin/gates/guards/*`) | secret · private · public · defaults · cron · branch · fixes — the delivery gate | [docs/features/the-wards-the-delivery-gate.md](docs/features/the-wards-the-delivery-gate.md) |

## Memory & secrets

| Area | Feature | What it gives you | how-to |
|---|---|---|---|
| Memory | The well (Mimirsbrunn / engram) | One long-term memory: embeddings, recall, per-session knowledge | [docs/features/the-well-recall-and-remember.md](docs/features/the-well-recall-and-remember.md) |
| Secrets | The secrets vault (`$YMIR_HOME/hodd/secrets`, age) | Credentials encrypted at rest, referenced by path, never inlined | [docs/features/the-secrets-vault.md](docs/features/the-secrets-vault.md) |
| Vault | **Hnitbjörg — the encrypted document vault** | A LUKS2 container for private documents, sealed by default | [docs/features/the-vault-hnitbjorg.md](docs/features/the-vault-hnitbjorg.md) |
| Vault | **Unlock the vault with your phone** | The vault carries a key on your phone; unlock it (biometrics) and plug it in | [docs/features/unlock-the-vault-with-your-phone.md](docs/features/unlock-the-vault-with-your-phone.md) |
| Vault | FIDO2 unlock | Open the vault with a hardware security key (a physical touch) | [docs/features/fido2-unlock-the-vault.md](docs/features/fido2-unlock-the-vault.md) |
| Vault | **Confidential session** | Work on vault content with **no route off the vault** — confined workdir, doors off, model tier (local/none/remote), `--airlock` for no network | [docs/features/confidential-session.md](docs/features/confidential-session.md) |

## Agents, work & collaboration

| Area | Feature | What it gives you | how-to |
|---|---|---|---|
| Work | Mjollnir (issue → PR) | GitHub issue → isolated worker → tests → PR; a human always seals | [docs/features/mjollnir-issue-to-pr.md](docs/features/mjollnir-issue-to-pr.md) |
| Factory | Smíðja + Völundr | Repeatable agent+code pipelines: rosters, bounded phases, typed envelopes, trace | [docs/features/smidja-and-volundr.md](docs/features/smidja-and-volundr.md) |
| Tickets | Skuld (ticket hall) | The project ledger of tickets and plans, on the heart | [docs/features/skuld-the-ticket-hall.md](docs/features/skuld-the-ticket-hall.md) |
| Collaboration | Ratatoskr (A2A 1.0) | Agent-to-agent tasks over an open protocol; agent cards, lifecycle | [docs/features/ratatoskr-a2a.md](docs/features/ratatoskr-a2a.md) |
| Skills | Galdr + Gungnir | The craft: skills, standards, and synthesis of a missing capability | [docs/features/galdr-and-gungnir-skills.md](docs/features/galdr-and-gungnir-skills.md) |
| Workers | Hermes runtime | An adopted worker runtime with its own brain, memory, and subagents | [docs/features/hermes-the-worker-runtime.md](docs/features/hermes-the-worker-runtime.md) |
| Meetings | Snotra (the meeting ear) | Captures a call (PipeWire), transcribes (whisper.cpp), mines minutes into the hoard | [docs/features/snotra-the-meeting-ear.md](docs/features/snotra-the-meeting-ear.md) |

## Surfaces — what you look at

| Area | Feature | What it gives you | how-to |
|---|---|---|---|
| Portal | Hlidskjalf (control plane) | The dashboard: live data, one tenant, enforced at the proxy | [docs/features/hlidskjalf-the-control-plane.md](docs/features/hlidskjalf-the-control-plane.md) |
| Board | Óðrerir (live hall) | The fleet's planning glass — a live board of what is happening | [docs/features/odrerir-the-live-hall.md](docs/features/odrerir-the-live-hall.md) |
| Desktop | Sessrúmnir (desktop shell) | The desktop app for the portal | [docs/features/sessrumnir-the-desktop.md](docs/features/sessrumnir-the-desktop.md) |
| Ingress | Bifrost + Heimdall + Gjallarhorn | Routing, OAuth guard, and the outbound tunnel | [docs/features/bifrost-and-heimdall-the-doors.md](docs/features/bifrost-and-heimdall-the-doors.md) |

## Fleet & models

| Area | Feature | What it gives you | how-to |
|---|---|---|---|
| Fleet | Fleet sync (Tailscale) | Keep the operator's data on every own machine; no central server | [docs/features/the-fleet-sync.md](docs/features/the-fleet-sync.md) |
| Models | The local model rail (llama-router) | Local models, OpenAI-compatible, one resident at a time | [docs/features/the-model-rail.md](docs/features/the-model-rail.md) |
| Time | Nornir (the schedule) | Cron jobs per seat/role: briefing, observer, housekeeping, git-sync, well-sync | [docs/features/nornir-the-schedule.md](docs/features/nornir-the-schedule.md) |
| Schedules | The well sync (`bin/time/well-vault-sync.sh`) | Checkpoint and ride the memory across the fleet | [docs/features/the-well-sync.md](docs/features/the-well-sync.md) |

## Planned and new — the fleet, the team, and the gates

Rows land here while a feature is being built; when one is whole, its row moves into the
section above. Each links a real page — a feature with no page is a feature no user can use.

| Area | Feature | What it gives you | how-to |
|---|---|---|---|
| Rooms | **Gladsheim — the fleet room** *(planned)* | One durable room where your whole fleet talks and you answer back | [docs/features/gladsheim-the-fleet-room.md](docs/features/gladsheim-the-fleet-room.md) |
| Rooms | **Brimir — the hall of Allfathers** *(planned)* | A self-hosted, federated room across operators, their Ymirs joining by A2A | [docs/features/brimir-the-hall-of-allfathers.md](docs/features/brimir-the-hall-of-allfathers.md) |
| Team | **Team places — a wall, not a permission** *(partly built)* | A team's own files, room, board and record; outside them a member sees nothing — not even a list | [docs/features/team-places.md](docs/features/team-places.md) |
| Security | **Distinct gates** *(law — Rule 18)* | One class per service, one gate per class: public · team · client · operator · confidential · fleet | [docs/features/distinct-gates.md](docs/features/distinct-gates.md) |
| Security | **Encryption and sensitive data** *(partly built)* | At rest, in transit, and end to end — and an encrypted room is only encrypted if every client encrypts | [docs/features/encryption-and-sensitive-data.md](docs/features/encryption-and-sensitive-data.md) |

---

## Planned — named and designed, not yet built

These are **not features yet**; they are named, planned, and paid for by a plan. They are
listed here so a reader knows what is coming, and so nobody rebuilds the design. Each has a
plain-language page; when one **lands**, its row moves into its proper section above and its
page's *planned* banner is removed **by a new entry citing the old** (Rule 06).

| Area | Feature | What it gives you | how-to |
|---|---|---|---|
| Rooms | **Gladsheim — the fleet room** *(planned)* | One durable room where your whole fleet talks and you answer back | [docs/features/gladsheim-the-fleet-room.md](docs/features/gladsheim-the-fleet-room.md) |
| Rooms | **Brimir — the hall of Allfathers** *(planned)* | A self-hosted, federated room across operators, their Ymirs joining by A2A | [docs/features/brimir-the-hall-of-allfathers.md](docs/features/brimir-the-hall-of-allfathers.md) |

---

| Runtime | **The clock and the date** | `bin/time/sol.sh` (**Sól**) answers the time once — local with its offset, UTC, epoch, a sortable stamp, the zone and its source — and does `add`/`diff` correctly across daylight-saving, reporting elapsed and calendar distance separately. Wired into the session digest; `check` refuses to call an unsynchronised clock sane | [docs/features/the-clock.md](docs/features/the-clock.md) |

*Append a row when a feature lands. Correct by appending, never by erasing.*
