# Naming — platform map (loaded from AGENTS.md)

The full Norse component map. AGENTS.md loads this when a task names a subsystem.
Deep doctrine (law, aetts, reject list): `.agents/skills/galdr-ymirsystem/assets/norse-naming.md`.

This map, `docs/lore.md` and the homepage must name every figure the same way. `bin/records/lore-audit.sh` measures
the claims in `docs/lore-claims.tsv`, and `bin/agents/name-registry.sh` reads the rows below (keep them in this
`"subsystem","norse","role"` shape: a script parses them). Aligned on 2026-11-25 by plan 374, *one name everywhere*.

```
platform[89]{subsystem,norse,role}:
  "Master platform root","Ymir","base host OS, master daemon"
  "The counsellor (a role)","Brokk","the counsellor's ROLE, never an agent's name (RULES/44): plans, steers, reviews, dispatches; each seat names its own counsellor"
  "Sub-agent worker","Eindri","isolated sandboxed workers; started only by bin/agents/einherjar-spawn.sh (MCP ymir_errand)"
  "Git worktree manager","Yggdrasil","branch isolation, zero-collision parallel edits"
  "Docker execution sandbox","Utgard","ephemeral container execution barrier"
  "Reverse proxy / gateway","Bifrost","HTTP routing, external traffic ingress"
  "Key ward / agent identity","Heimdall","admits an entrant only by the key it carries (bin/host/heimdall-*.sh, the SSH-key ward); signing each agent's rune of introduction is owed. The OAuth login was removed 2026-11-14"
  "Cloudflare tunnel","Gjallarhorn","outbound encrypted tunnel, never to a hall; the publish door (MCP ymir_publish)"
  "Notification door","Hófvarpnir","the horse that carries every rider's word — one door Runes, the arm, the desktop, the pocket and Telegram all send by (plan 100; MCP ymir_telegram)"
  "User dashboard","Hlidskjalf","observability, monitoring, control panel (MCP ymir_hall)"
  "Live hall board","Óðrerir","fleet planning glass (:4322); an app of its own, zerwiz/odrerir"
  "Web file browser","Skrymir","web-based file explorer, inside Hlidskjalf"
  "Multi-tenant domains","Svartalfaheim","scoped tenant workspaces"
  "Global shared workspace","Midgard","cross-tenant shared repos & assets"
  "Inter-agent A2A bus","Ratatoskr","A2A 1.0 backbone: agent cards, task lifecycle, Redis queue"
  "Vector DB & memory","Mimirsbrunn","long-term memory, embeddings, vector store (the well)"
  "The voice of the well","Mímir","the well's keeper: recall before work, remember after (MCP ymir_recall, ymir_remember, ymir_find; the gateway door well); his card plans from the well"
  "The deeper well (derived memory)","Sökkvabekkr","the sunken bench where Sága tells Odin all that has been: conclusions about each person and agent, derived from the well and rebuildable from it (Honcho engine; on trial, plan 260)"
  "Audit trail","Runes","append-only system audit ledger"
  "Issue-to-PR pipeline","Mjölnir","autonomous bug-fix and PR creation (bin/forge/mjollnir.sh; issue-watch, ship-watch)"
  "Process health monitor","Valhalla","PM2/Docker process supervisor"
  "Skill synthesis engine","Gungnir","dynamic skill creation & validation (planned: no door yet, plan 374 D9)"
  "Skill optimization/refinement","Gunnlöð","keeper of the mead of poetry; distils a finished run into a sharper skill (planned: no door yet, plan 374 D9)"
  "The skills door","Bölþorn","whose son taught Odin nine mighty songs: the skills shelf served to every harness (the gateway door bolthorn, tools/skills-mcp)"
  "Agent ergonomics standards","Galdr","TOON output, 10 design principles, master builder; keeps the house's rules (MCP ymir_rule)"
  "The tool judge","Týr","validates tools, skills and docs against the ten Galdr principles (.agents/agents/tyr-check.md)"
  "MCP/A2A composition (the gateway)","Hermóðr","the body's one MCP door: fronts well, skills, tickets and the ear; attached it proxies the heart, dark it serves the cache and queues the journal (bin/bridge/mcp-gateway.sh, mcp-gateway.service)"
  "Session-start digest","Sága","the seeress who sees all; boots the session (MCP ymir_where)"
  "Watch / supervision","Sýn","watchful sight: the turn-boundary guard and the standing watch service (ymir-syn-watch.service), one watcher per hall"
  "Hallucination loop breaker","Níðhöggr","the serpent that gnaws the root forever; names the endless loop and breaks it"
  "Session lock","Gleipnir","the chain that binds one session"
  "Config load at boot","Valknut","the knot that binds: config assembled once at boot (bin/seat/valknut-load.sh)"
  "Scheduled jobs","Nornir","the fates who govern time"
  "What shall be","Skuld","the youngest Norn: the tickets, the plans owed, the to-do board and each branch's outcome (the gateway door skuld; MCP ymir_todo_board, skuld_branch_report). The role resolver left her for bin/fleet/role.sh (plan 374 D3)"
  "The decision held","Urðr","what has been: holds what is unresolved for the Allfather and reconciles it (MCP ymir_pending)"
  "Software smidja","Smíðja","repeatable agent+code pipeline: rosters, bounded phases, typed envelopes, retries/acceptance, trace"
  "Smíðja orchestrator","Völundr","the master of the smiths who leads Smíðja and dispatches its smiths; gives a figure its kit (MCP ymir_figure); the dispatch queue"
  "Control-plane hub / federation & sync","Vingólf","the assembly hall: coordination, identity, and sync across substrates, plans onto boards (MCP ymir_board_sync); never executes code"
  "Records keeper (plans · docs · memory)","Reginn (the Elder)","the keeper who remembers — the plan ledger, the documentation shelves, the home's layout (MCP ymir_plan, ymir_note, ymir_header, ymir_push, ymir_place, ymir_find_home, ymir_layout, ymir_import, ymir_index, ymir_structure, ymir_daily); skill elder-home"
  "Document freshness","Dellingr","the dawn: grades a document nýr · eldri · forn · safn from measurable signals only (bin/records/grade.sh, MCP ymir_dellingr), under Reginn"
  "Encrypted document vault","Hnitbjörg","the mountain stronghold where the mead was hidden; a LUKS2 container, sealed by default, opened only by the operator (bin/vault/hnitbjorg.sh); never the hoard's secrets"
  "Dedicated PR reviewer / judge","Forseti","fierce read-only audit of every harvest; verdict (APPROVE / NEEDS-REWORK) holds the seal; the review wardens (pr-watch, review-watch, review-seat, review-loop)"
  "Durable wake messenger","Gná","the wake road — self-wake at the source, failsafe sweep, re-arm catch-up, an ack that eats only what it saw (MCP ymir_arm, gna_fleet_tell)"
  "The warden and the wards","Vörðr","composes the wards and watches the house: the gate guardians, the mends (bin/ward/harden.sh), vordr-doctor (MCP ymir_gates)"
  "The watchtower","Himinbjörg","where the warden looks from: what listens, what changed, what tried to come in (the Ward panel in Hlidskjalf)"
  "The hound at the gate","Garmr","writes what ran, listened and reached out (bin/ward/garmr.sh, garmr-* units; browser-census, browserkill-trace)"
  "The defender","Víðarr","closes a door an intruder opened, stops a unit, quarantines a file, and keeps the evidence (bin/ward/vidarr.sh)"
  "The wall of plans and trouble","Valaskjálf","what every project owes and the things that fail silently (trouble-panel, owed, housewatch)"
  "The engine (runtime core)","The Engine","src/ymir_runtime/ — one module, four verbs (seat · status · send · stop); the deep forge behind thin doors"
  "The heart on the always-on box","(topology)","the record's home is the always-on machine; compute rides the forge; the headless heart's schedule persists"
  "The clock","Sól","the sun's wheel: one door for time and date (bin/time/sol.sh) — arithmetic on instants, so daylight-saving cannot lie about elapsed time"
  "The calendar","Mánagandr","the month-pursuer: what is on the day, and when a meeting fits (bin/time/managandr/, MCP ymir_calendar, calendar-watch)"
  "The meeting ear","Snotra","the wise one: hears a meeting, keeps its record, writes the minutes and carries the promises (systems/snotra, the gateway door snotra, .agents/agents/snotra-ear.md)"
  "The renewer","Gróa","fast-forwards the house and its homes, then mends forward (bin/agents/groa-update.sh, groa-agent; MCP ymir_update)"
  "The healer","Eir","diagnoses every surface, then mends what is broken (bin/agents/eir-doctor.sh, eir-night; MCP ymir_heal)"
  "Diagnostics before dispatch","Vör","the aware: reads bootstrap and network state before a worker is sent"
  "The structured brief","Erindi","the errand: every task enters structured (bin/agents/erindi-brief.sh)"
  "The harness adapter","Hamr","the shape-changer: one interface over every harness, Hermes included (MCP ymir_hermes_list, ymir_hermes_send, ymir_hermes_recover)"
  "The consent gate","Frigg","the knowing: no irreversible action without the operator's word"
  "The project registry","Jörð","the earth: the living record of projects and their delivery posture"
  "Away-mode supervision","Hvíld","the rest: supervision while the operator is away"
  "The workspace database","Wyrd","workspace RAG (bin/records/wyrd-db.sh)"
  "Evidence or no done","The Veil","the anti-hallucination gate: a done needs evidence, a report needs a receipt (bin/agents/veil.sh, MCP ymir_veil)"
  "Human review gate","Glitnir","the hall of the just: the PR review surface; the Allfather's approval is the merge"
  "The seat backend","Herdr","panes, tabs and sessions a worker is seated in (protocol 14+; MCP ymir_seats, ymir_close_dead). An adopted engine keeps its own name"
  "The seats and their names","Hœnir","every machine names its own counsellor; a seat holds the arm (bin/seat/seat-surface.sh, bin/agents/seat-identity.sh)"
  "The desktop seat","Sessrúmnir","the GUI over the Pi and OMP coding agents (zerwiz/sessrumnir)"
  "The business hall","Bilskirnir","the business hall and its desk (zerwiz/bilskirnir)"
  "The news well","Hvergelmir","the news service (zerwiz/hvergelmir): many streams, one well (plan 374 D1)"
  "Every app in its own home","Élivágar","the rivers that flow from the one spring: each app installs, updates and rolls back from its own repository (bin/apps/apps.sh, config/app-repos.yaml) (plan 374 D1)"
  "The voice window","Rödd","the voice, as an app: the window, the desk shell, the voice in and out (zerwiz/rodd; bin/voice/; kokoro, whisper, the desk wards)"
  "The one who answers in Rödd","Nanna","the assistant inside Rödd, a she, and never Skírnir"
  "The assistant","Skírnir","answers people while the operator is away, takes a message, and says honestly when it does not know (systems/skirnir)"
  "The design smithy","Hnoss","prototypes, pages, dashboards, decks, images and motion, made on the operator's own machine (the hnoss MCP; MCP ymir_studio)"
  "The council of models","Lögrétta","several models answer one question and an arbiter merges them, keeping the disagreements visible"
  "A real shell in the high seat","Þráðr","the thread: a live terminal inside Hlidskjalf"
  "The workbench for a guest hand","Smíðr","what a hand from another house is taught before its first branch"
  "The collaboration suite","Gimlé","one sign-in opens the board, the documents and the whiteboard; one MCP door (the gimle MCP; the excalidraw units)"
  "The auditor","Móðguðr","the bridge-keeper and the council's chair: asks for the command that shows a claim, and refuses rather than believes"
  "The token economist","Andhrímnir","finds where an agent house spends tokens it did not need to (MCP ymir_context, ymir_core_four)"
  "Session knowledge","Muninn","memory: carries a session's durable knowledge to its shelf"
  "Reconnaissance","Kvasir","scouts the ground before anyone builds; changes nothing"
  "The specialists of the fleet","(the eight)","Sindri, Bragi, Huginn, Mímir, Kvasir, Forseti, Snotra and Galdr stand beside the counsellor (plan 374 D2)"
  "The broad slice","Kádlín","many files in one pass, when the work is wide rather than deep (planned: no door yet, plan 374 D9)"
  "The hall of Allfathers","Brimir","a federated room across operators, joined by A2A (planned, plan 74)"
  "The fleet room","Gladsheim","one durable room where the whole fleet talks (built: bin/room/gladsheim.sh; its engine was down when measured 2026-11-25)"
  "The decision layer","(unnamed — the Allfather's to name)","Julia routes, Kev judges: a typed question answered with a choice and a confidence in milliseconds (tools/jev, the jev-* units)"
  "The hoard's secrets","(unnamed — plan 374 D10)","the hoard (hodd) and its secrets keep their function names (bin/vault/hodd.sh, MCP ymir_secret_keys)"
  "The model rail","(unnamed — plan 374 D10)","the GPU rail keeps its function names (gpu-door, gpu-models-reap)"
```

```
eindri[3]{role,norse,descriptor,domain}:
  "developer","Sindri","smith","code synthesis, refactoring, development"
  "marketer","Bragi","skald","the words, for people: documentation, content, SEO, social, marketing campaigns (the documenter's craft since 2026-11-25)"
  "researcher","Huginn","sage","RAG, web search, analysis, knowledge discovery; the web tools (Firecrawl, SearXNG, the Playwright browser; plan 373); MCP ymir_research, ymir_research_find"
```

## Who answers for the tools that carry no figure's name

RULES/23 lets a tool keep a function name (`bin/records/plan.sh`, `pr-watch.service`). That is not a naming fault. What
must be true is that **one figure answers for it**. Every Ymir MCP tool's description now begins with its owner
(`Reginn — …`), and this table is the same list for the units and containers.

| Figure | MCP tools | Units and containers |
|---|---|---|
| Mímir | `ymir_recall`, `ymir_remember`, `ymir_find` | `mimir`, `well-mcp`, `embed` |
| Huginn | `ymir_research`, `ymir_research_find` | the Firecrawl stack, `ymir-searxng` (plan 373) |
| Reginn | `ymir_plan`, `ymir_note`, `ymir_header`, `ymir_push`, `ymir_place`, `ymir_find_home`, `ymir_layout`, `ymir_import`, `ymir_index`, `ymir_structure`, `ymir_daily` | - |
| Dellingr | `ymir_dellingr` | - |
| Skuld | `ymir_todo_board`, `skuld_branch_report` | `skuld`, `cards`, `tickets` |
| Urðr | `ymir_pending` | - |
| Vörðr | `ymir_gates` | `vordr-doctor` |
| Hófvarpnir | `ymir_telegram` | `ntfy` |
| Hnoss | `ymir_studio` | the OpenDesign container |
| Hamr | `ymir_hermes_list`, `ymir_hermes_send`, `ymir_hermes_recover` | - |
| Herdr | `ymir_seats`, `ymir_close_dead` | - |
| Hlidskjalf | `ymir_hall` | `hlidskjalf-gate`, `hlidskjalf-spa` |
| Andhrímnir | `ymir_context`, `ymir_core_four` | - |
| Sága | `ymir_where` | - |
| Galdr | `ymir_rule` | - |
| Vingólf | `ymir_board_sync` | `foreman-board-sync` |
| Völundr | `ymir_figure` | `queue-warden`, `dispatch`, `mill-worker`, `smidja` |
| Gná | `ymir_arm`, `gna_fleet_tell` | `gna-desk` |
| Eindri | `ymir_errand` | - |
| Eir | `ymir_heal` | `eir-night` |
| Gróa | `ymir_update` | `groa-agent` |
| Mánagandr | `ymir_calendar` | `calendar-watch` |
| Gjallarhorn | `ymir_publish` | `ymir-publish-edge`, the `cloudflared-*` tunnels |
| the Veil | `ymir_veil` | - |
| Forseti | - | `pr-watch`, `review-watch`, `review-seat`, `review-loop` |
| Mjölnir | - | `issue-watch`, `ship-watch` |
| Valaskjálf | - | `trouble-panel`, `owed`, `housewatch` |
| Rödd | - | `ymir-rodd`, `kokoro-*`, `whisper-ptt`, `voxtype`, `stt-shim`, `window-close-ward`, `desk-failsafe` |
| Garmr | - | `garmr-*`, `browser-census`, `browserkill-trace` |
| Gimlé | the gimle MCP | `excalidraw-*`, `gimle-project` |
| Snotra | the gateway door `snotra` | `snotra-detect`, `snotra-ear`, `snotra` |
| Bölþorn | the gateway door `bolthorn` | `skills-mcp` |
| Hermóðr | the gateway itself | `mcp-gateway` |
| Ratatoskr | - | `ratatoskr`, `ratatoskr-relay`, `a2a-front` |
| Heimdall | - | `heimdall-ssh-keys` |
| Bilskirnir | - | the Bilskirnir desk container |

## Spelling

Prose (the lore, this map, AGENTS.md, the homepage, fix notes) uses the Old Norse display form: Hliðskjálf, Mjölnir,
Mímir, Útgarðr, Bifröst, Heimdallr, Smíðja, Lögrétta. Identifiers (paths, units, tools, flags) stay ASCII as they are:
`hlidskjalf`, `mjollnir.sh`, `logretta`. No identifier is renamed for spelling. The rows above keep the spellings
`name-registry.sh` already knows, so a scan finds no new collision.

## Law

Name every subsystem for the figure whose role matches its work. The operator is
the **Allfather** ; never name a component with an imported term. Flavor may
season a line; it must never name a subsystem or leak into docs.

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
- **2026-11-25** — plan 374, *one name everywhere*, at the Allfather's choices D1–D10. Seven doubled rows made one
  (Vörðr, Hnitbjörg, Gunnlöð, Níðhöggr, Vingólf, Reginn, Sýn; the `elder-home` row is Reginn's). Thirty-eight figures
  added that ran in the code or stood in the lore with no row, and Élivágar named. Brokk's row is the counsellor's
  role (RULES/44); Heimdall's is the key ward (the OAuth login is gone); Hermóðr is the gateway; Snotra is the meeting
  ear and the documenter's craft is Bragi's; Skuld keeps what shall be; Hvergelmir is the news app. Gungnir, Gunnlöð
  and Kádlín are marked planned; Himinbjörg, Vörðr and Gladsheim built. The Hófvarpnir row's missing closing quote is
  fixed. A table names the owner of every MCP tool, unit and container. The rows removed are in this file's git log.
