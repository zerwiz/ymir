Read when: naming a subsystem, a component or a process, or meeting a Norse name you do not know.

# The lore and the naming law

Part of the Ymir contract. The prior text is kept verbatim in `docs/contract-history/AGENTS-2026-11-24.md`.

Ymir carries Norse names not as decoration but as **load-bearing allegory**: every name explains the machine's job.
Apply **Norse methodology**: name every subsystem for the figure whose role matches its work. The house voice is
Norse-natural; flavour may season a line, but it must never name a subsystem. The lore is not optional reading; it is the
naming law. The full lore is at [`docs/lore.md`](../../../../docs/lore.md), the full component map is
`.agents/assets/agents/naming.md`, and the deep doctrine (law, aetts, reject list) is
`.agents/skills/galdr-ymirsystem/assets/norse-naming.md`.

**No agent is named Brokk** (RULES/44). Brokk is the counsellor's role, never an agent's name: a fleet of Brokks cannot
be told apart, and the operator cannot tell which house spoke. Every machine names its own agents (the seat primary
inside Ymir; the machine agent that keeps the computer), and every agent declares **house · fleet · machine · Allfather**
when it introduces itself. An unsealed name is rendered as *unnamed*, never invented. The renderer is
`bin/seat/seat-surface.sh`, run by install and by every update; the names come from the operator's own config
(`hodd/identity/seats.yaml`, `operator.yaml`), never from a shipped default.

The eight Labs are **domains**, not houses; **WayOf** is the house (RULES/01, RULES/03).

## Quick reference

| Name | What it is |
|------|------------|
| **Ymir** | The substrate — one repo, one machine, all realms carved from it |
| **Brokk** | You — the Allfather's counsellor: the bellows that plans, steers, reviews, and sends the Eindri out to forge |
| **Eindri** | Sub-agent workers — isolated smiths in Utgard sandboxes |
| **Völundr** | The master of the smiths — leads the Smithy (Smíðja) and dispatches its smiths; the eye that remembers, recalls from Mimirsbrunn |
| **Yggdrasil** | Git worktree isolation — parallel branches, zero collision |
| **Utgard** | Ephemeral sandbox — untrusted code runs there, never in the halls |
| **Mimirsbrunn** | Engram memory engine — long-term memory, embeddings |
| **Ratatoskr** | A2A 1.0 collaboration backbone — agent-to-agent messaging |
| **Hlidskjalf** | Control plane / dashboard — the Allfather's high seat |
| **Bifrost** | Ingress gateway — every crossing passes over it |
| **Heimdall** | OAuth/security guard — signs every agent's rune of introduction |
| **Gjallarhorn** | Cloudflare tunnel — outbound encrypted signal |
| **Runes** | Append-only audit ledger — every action inscribed, never un-carved |
| **Mjollnir** | Issue→PR pipeline — strikes, returns with a PR |
| **Gungnir** | Skill synthesis engine — forged, validated, hits its mark |
| **Smíðja** | The smithy — agent factory, Völundr orchestrator |
| **Völundr** | Wayland the Smith — Smíðja's master craftsman |
| **Sága** | The seeress — session start digest, seat taken before first word |
| **Nornir** | Fates/schedule — cron jobs, daily briefing, quota dispatch |
| **Muninn** | Memory — session-knowledge curation, routing, persistence |
| **Huginn** | Observation — the raven that flies daily for the Allfather |
| **Þjazi** | Terminal backend — sub-agent panes, protocol 14+ |
| **Gróa** | Updater shaman — the völva who renews: fast-forwards Brokk and its homes, then mends forward |
| **Eir** | The healer — diagnoses every surface, then mends what is broken |
| **Sól** | The clock — one door for time (`bin/time/sol.sh`); arithmetIc on instants, so daylight-saving cannot lie about elapsed time |
| **Mánagandr** | The calendar — what is on the day, and when a meeting fits |
| **Hnitbjörg** | The encrypted vault — LUKS2, sealed by default, opened only by the operator |
| **Gunnlöð** | Skill refinement — distils a run's trajectory into a sharper skill |
| **Níðhöggr** | The loop-breaker — names the endless loop and stops it |
| **Vingólf** | The assembly hall — coordination, identity and sync across substrates; never executes code |
| **Reginn** | The records keeper — the plan ledger, the docs, the well; reads the elders before writing |
| **Herdr** | The seat backend — panes, tabs and sessions a worker is seated in (protocol 14+) |
| **Sessrúmnir** | The desktop seat — the GUI over the Pi and OMP agents (`apps/sessrumnir`) |
| **Vörðr** | The warden — composes the wards and watches the house (planned, plan 81) |
| **Himinbjörg** | The watchtower — where the warden looks from: ports, changes, attempts (planned, plan 81) |
| **Kádlín** | The broad slice — many files in one pass, when the work is wide rather than deep |
| **Brimir** | The hall of Allfathers — a federated room across operators (planned, plan 74) |
| **Gladsheim** | The fleet room — one durable room where the whole fleet talks (planned, plan 73) |
