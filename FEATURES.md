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
| Meetings | Meeting outcomes (`snotra-meeting-outcomes`) | A transcript becomes minutes, a decision log, actions with one owner and one date, per-person briefs, a follow-up email, and Trello card payloads — every entry carrying its timestamp and quote | [docs/features/meeting-outcomes.md](docs/features/meeting-outcomes.md) |
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
| Meetings | Snotra doors (`snotra-store`, `ping-room`, `snotra-autojoin`, `snotra-bot`) | One record contract for every meeting: lane directories, append-only writes, generated index, on-demand Þing room, calendar auto-join, and a bot named Snotra | [docs/features/snotra-meetings.md](docs/features/snotra-meetings.md) |
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

| Security | **The ward — Vörðr** | `bin/ward/security-audit.sh` reads every door this machine opens (ports, ufw by source, the effective sshd policy, public tunnels and whether they ask for a login, secret file modes, whether anything watches the host) and fails on a HIGH or CRITICAL; `verdr.sh` walks the house, writes the dated report into the home and speaks on a HIGH; `harden.sh` writes every mend with its revert line, applies the safe ones, and **refuses** the firewall change without the operator's word | [docs/features/the-ward.md](docs/features/the-ward.md) |
| Runtime | **The clock and the date** | `bin/time/sol.sh` (**Sól**) answers the time once — local with its offset, UTC, epoch, a sortable stamp, the zone and its source — and does `add`/`diff` correctly across daylight-saving, reporting elapsed and calendar distance separately. Wired into the session digest; `check` refuses to call an unsynchronised clock sane | [docs/features/the-clock.md](docs/features/the-clock.md) |
| Desktop | **Opening a file on the right display** | `ymir-edit.sh --role <role>` opens a document in your editor on the screen its ROLE says — the largest monitor for reading, the focused one for code — reusing the window if the file is already open, and it speaks whichever dispatcher dialect the Hyprland session uses (Lua on 0.56, classic before) | [docs/features/open-on-the-right-display.md](docs/features/open-on-the-right-display.md) |
| Voice | **The voice engines — whisper + piper** | `bin/voice/voice-ensure.sh` adopts the ear (whisper.cpp, owned by Snotra's road) and the voice (piper + a `.onnx` model), installing only what is missing, into the hoard; it is the installer's `voice` step, a row in the plan's engines phase, and Eir's `voice` surface | [docs/features/the-voice-engines.md](docs/features/the-voice-engines.md) |

*Append a row when a feature lands. Correct by appending, never by erasing.*
| Agents | Seat identity (`bin/agents/seat-identity.sh`) | Each machine names its own primary; `set` renames, `ensure` runs at install, `check` fails a drifted seat, `render` writes the contract | [docs/features/the-seat-name.md](docs/features/the-seat-name.md) |
| Agents | **The council of models** | `logretta_sit` seats 2–5 different models on one question, each through a remit (architect · security · cost · skeptic · operator · recon), runs a debate round where each seat reads the others and may change its mind, then an arbiter merges one verdict and names the disagreements. Every seat is a clean-room read-only `pi` child; nothing is written; a budget line stops it loudly | [docs/features/the-council-of-models.md](docs/features/the-council-of-models.md) |
| Meetings | **The Þing — meeting framework** | Four named roles (Chair, Secretary, Notetaker, Adjuster), consent decisions with one Approver, grades A/B/C, Draft→Reviewed→Approved→Signed sign-off, and a daily/weekly/monthly/quarterly cadence | [docs/features/the-meeting-framework.md](docs/features/the-meeting-framework.md) |
| Meetings | **Trello meeting board** (`bin/time/snotra/snotra-trello.sh`) | `export` projects a meeting record onto Trello — one card per decision/action/question, human title + meeting tag, grade/state labels, due dates, checklists, real members, and one workstream copy — idempotently; `sync` moves sign-offs; `doctor` reports the board | [docs/features/trello-meeting-board.md](docs/features/trello-meeting-board.md) |
| Meetings | **Sign-off by email** (`snotra-signoff.sh`) | `init` a sign-off, `ask` one request per participant, `sync` reads `confirm` / `objection:` replies from Gmail, `render` writes the sheet; the record becomes official when the Chair signs | [docs/features/meeting-signoff.md](docs/features/meeting-signoff.md) |
| Meetings | **`snotra-init` — first-run meeting skeleton** | One idempotent command creates the meetings shelf, a blank operator template, the confidential register template, the agnostic framework/templates and the Snotra cron block; the installer and migration `0011` run it | [docs/features/snotra-init.md](docs/features/snotra-init.md) |
| Meetings | **Transcript provenance** (`snotra-provenance.sh`) | `seal` writes a SHA-256 manifest of every meeting artifact and appends a hash-chained entry; `verify` recomputes and fails on any change; mode 0600; local proof only, a qualified eIDAS timestamp is an external trust service | [docs/features/transcript-provenance.md](docs/features/transcript-provenance.md) |
| Security | **Sensitive-data gate** (`bin/gates/guards/sensitive-gate.sh`) | One choke point for a sensitive artifact set: classification/hold, provenance verify, NDA/private guard, and an append-only access log; wired to Trello export and `mail-send --meeting-dir` | [docs/features/sensitive-data-gate.md](docs/features/sensitive-data-gate.md) |
| Meetings | **Evidence bundle** (`snotra-evidence.sh`) | Timestamp the provenance root (RFC 3161/QTSP or explicit local-unqualified), make a local read-only copy, write a certified copy with reviewer and corrections, and set retention that moves rather than deletes | [docs/features/transcript-provenance.md](docs/features/transcript-provenance.md) |
| Security | **Sensitive-data tests** (`tests/test_snotra_sensitive.sh`) | Synthetic fixtures prove held sets are refused on Trello, private is allowed, an unheld sealed set passes, a one-byte tamper fails, and timestamp/certified copy are written | — |
| Desktop | **Þráðr — a real terminal in the high seat** | A real pty inside Hlidskjalf so `herdr` and a login shell run in the gate, with the terminal gate's own shortcuts | [docs/features/the-thread.md](docs/features/the-thread.md) |
| Runtime | **Worktree housekeeping** | An audit of every Yggdrasil worktree and local branch, with one verdict each and a loud list of work that exists only on this machine; read-only by default | [docs/features/worktree-housekeeping.md](docs/features/worktree-housekeeping.md) |
| Security | **Garmr — the guardian (the hound)** | Watches the machine itself: what executes (with a redacted command line), who opens the meeting/evidence/vault shelves (paths hashed, never content), what starts listening, what connects out, and what signal is sent to what — then turns each into a plain sentence, wakes the operator at HIGH, and records it in Runes. `bin/ward/garmr.sh status\|install\|pause\|resume\|judge\|tail\|verify`; a **ᛉ hound** chip in Hlidskjalf opens *Himinbjörg*, the watchtower. Rules decide; a model is asked only above the threshold, and the alert itself is always a template | [docs/features/the-guardian.md](docs/features/the-guardian.md) |
| Security | **Garmr — corrected row (2026-10-21, cites the row above): the file-change senses, the smoke test and the switch** | The row above was written before three things landed, so it was incomplete rather than wrong. **Added senses:** a change to an identity or privilege file — `/etc/passwd`, `/etc/shadow`, `/etc/group`, `/etc/sudoers(.d)`, `~/.ssh/authorized_keys` (CRITICAL) — and to a persistence surface — `/etc/systemd/{system,user}`, `/etc/cron.d`, `/etc/crontab`, `/var/spool/cron`, `~/.config/systemd/user`, `~/.config/autostart` (HIGH). **Added doors:** `bin/ward/garmr.sh refresh` (re-render the units after an update — Gróa calls it) and **`bin/ward/garmr-smoke.sh`**, a reusable 9-check smoke test whose whole point is that *running* is not *armed* is not *working* (it asserts a non-root pause is refused, that the rules are in the kernel, and that no sensitive path or token reached the findings). **The switch, stated plainly:** `pause`/`resume` need root, because a guardian an ordinary process can silence is a guardian the intruder silences first | [docs/features/the-guardian.md](docs/features/the-guardian.md) |
| Security | **The bark reaches the pocket — Gotify or ntfy** | A finding at or above `alert.phone_at` (default HIGH) is sent to the phone through one self-hosted channel: **Gotify** (per-user app tokens = a revocable identity per machine sender, and an API that returns a message id, so delivery is proved) or **ntfy** (topics, for when several devices or people must hear it — with a write token for the hound and read tokens for devices, so a stranger cannot post "all clear"). Severity becomes the priority (CRITICAL 10 / ntfy 5 + a loud tag), the body is severity + finding line + Rune id and **no content**, MEDIUM is suppressed in quiet hours and CRITICAL never is, ten an hour at most with a storm collapsed to one line. `bin/ward/garmr/notify.py --test` proves the road before you need it | [docs/features/the-guardian.md](docs/features/the-guardian.md) |
| Security | **The vault's edit door** (`bin/vault/hodd-set.sh`) | Set or read ONE key inside the age-encrypted vault without ever touching the file by hand: `KEY VALUE` writes, `--get KEY` prints one value, `--list` prints names only. Four guards, each of which was missing on the day a hand-edit replaced 90 secrets with 3: the decrypted plaintext must be non-empty, the re-encryption is decrypted again and compared before it replaces anything, the old file is kept as a timestamped backup, and the write is atomic at 0600 with every plaintext temp shredded | [docs/features/the-vault-edit-door.md](docs/features/the-vault-edit-door.md) |
| Docs | **The claims checker** (`bin/gates/checks/readme-claims.sh`) | Reads the user-facing documents and refuses a claim the tree does not hold: every repo path a page names must exist, `@zerwiz/*` packages are checked against the registry with `--npm`, and `--ports` reports what actually listens. A line is waived in writing (`<!-- stale-ok: reason -->`) or by `docs/README-claims.waived`. Run by the `docs-claims-guard`, so a stale instruction cannot be pushed | [docs/features/the-claims-checker.md](docs/features/the-claims-checker.md) |
| People | **Collaborators and clients** (`bin/people/collaborators.sh`) | One registry of the people you work with — clients, collaborators, advisers, partners — in the vault, with their addresses, the project, consent, and whether an NDA is in place. `list`/`show`/`add`/`set`/`check`/`email`. `check` validates every record and refuses an `nda: true` whose address is not in the NDA register; `email` refuses a former or non-consenting contact, refuses a missing address, and runs the private/NDA guard over the body **before** the mail door is called | [docs/features/collaborators.md](docs/features/collaborators.md) |
