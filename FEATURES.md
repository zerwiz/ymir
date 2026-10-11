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
| Install | `install.sh` / `bin/engine/ymir-install.sh` | One command installs Ymir into a prefix you own, writes PATH, runs first setup, then proves it | — |
| Runtime | The engine (`src/ymir_runtime/`) | The runtime core behind every door: `seat · status · send · stop` | — |
| Agent | Brokk (the primary) | The counsellor: plans, steers, reviews, dispatches — one agent, any harness (Pi · OpenCode · Claude Code · Codex · Cursor) | — |
| Workers | Eindri (isolated sub-agents) | Complex work forged in isolation, never in the main tree | — |
| Isolation | Yggdrasil (worktrees) + Utgard (sandbox) | Parallel branches, zero collision; untrusted code runs sandboxed | — |
| Session | Sága (session-start digest) | Boots a session: what stands, what is owed, what the seat is | [docs/features/saga-the-session-start.md](docs/features/saga-the-session-start.md) |
| Record | The plan ledger + Runes (audit) | Every plan and every significant action, written down, never lost | — |
| Updates | Gróa (updater) | Fast-forwards Brokk and its homes, then mends forward | [docs/features/groa-and-eir-update-and-heal.md](docs/features/groa-and-eir-update-and-heal.md) |
| Health | Eir (the healer) | Diagnoses every surface, then mends what is broken | [docs/features/groa-and-eir-update-and-heal.md](docs/features/groa-and-eir-update-and-heal.md) |
| Gate | The wards (`bin/gates/guards/*`) | secret · private · public · defaults · cron · branch · fixes — the delivery gate | [docs/features/the-wards-the-delivery-gate.md](docs/features/the-wards-the-delivery-gate.md) |

## Memory & secrets

| Area | Feature | What it gives you | how-to |
|---|---|---|---|
| Memory | The well (Mimirsbrunn / engram) | One long-term memory: embeddings, recall, per-session knowledge | — |
| Secrets | The secrets vault (`$YMIR_HOME/hodd/secrets`, age) | Credentials encrypted at rest, referenced by path, never inlined | [docs/guides/SECRETS.md](docs/guides/SECRETS.md) |
| Vault | **Hnitbjörg — the encrypted document vault** | A LUKS2 container for private documents, sealed by default | — |
| Vault | **Unlock the vault with your phone** | The vault carries a key on your phone; unlock it (biometrics) and plug it in | [docs/features/unlock-the-vault-with-your-phone.md](docs/features/unlock-the-vault-with-your-phone.md) |
| Vault | FIDO2 unlock | Open the vault with a hardware security key (a physical touch) | — |
| Vault | **Confidential session** | Work on vault content with **no route off the vault** — confined workdir, doors off, model tier (local/none/remote), `--airlock` for no network | [docs/features/confidential-session.md](docs/features/confidential-session.md) |

## Agents, work & collaboration

| Area | Feature | What it gives you | how-to |
|---|---|---|---|
| Work | Mjollnir (issue → PR) | GitHub issue → isolated worker → tests → PR; a human always seals | — |
| Factory | Smíðja + Völundr | Repeatable agent+code pipelines: rosters, bounded phases, typed envelopes, trace | — |
| Tickets | Skuld (ticket hall) | The project ledger of tickets and plans, on the heart | — |
| Collaboration | Ratatoskr (A2A 1.0) | Agent-to-agent tasks over an open protocol; agent cards, lifecycle | — |
| Skills | Galdr + Gungnir | The craft: skills, standards, and synthesis of a missing capability | — |
| Workers | Hermes runtime | An adopted worker runtime with its own brain, memory, and subagents | — |
| Meetings | Snotra (the meeting ear) | Captures a call (PipeWire), transcribes (whisper.cpp), mines minutes into the hoard | — |

## Surfaces — what you look at

| Area | Feature | What it gives you | how-to |
|---|---|---|---|
| Portal | Hlidskjalf (control plane) | The dashboard: live data, one tenant, enforced at the proxy | — |
| Board | Óðrerir (live hall) | The fleet's planning glass — a live board of what is happening | — |
| Desktop | Sessrúmnir (desktop shell) | The desktop app for the portal | — |
| Ingress | Bifrost + Heimdall + Gjallarhorn | Routing, OAuth guard, and the outbound tunnel | — |

## Fleet & models

| Area | Feature | What it gives you | how-to |
|---|---|---|---|
| Fleet | Fleet sync (Tailscale) | Keep the operator's data on every own machine; no central server | — |
| Models | The local model rail (llama-router) | Local models, OpenAI-compatible, one resident at a time | — |
| Time | Nornir (the schedule) | Cron jobs per seat/role: briefing, observer, housekeeping, git-sync, well-sync | — |
| Schedules | The well sync (`bin/time/well-vault-sync.sh`) | Checkpoint and ride the memory across the fleet | — |

---

*Append a row when a feature lands. Correct by appending, never by erasing.*
