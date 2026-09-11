# YMIR — The Lore (v2)

> The system carries Norse names not as decoration but as **load-bearing allegory** — every name is chosen because the myth already explains the machine's job. The visual language is the same rule made visible: **carved, not skinned**. ([`docs/design.md`](design.md))

---

## I. The Creation: Ymir, the Primordial Giant

In the old tale, there was nothing before the worlds but cold mist and embers of fire.
From their meeting in the Void — **Ginnungagap** — came the first being: the giant
**Ymir (Aurgelmir)**, the ancestor of everything. The gods slew him and made the
world from his body: flesh became the earth, blood the seas, bones the mountains,
hair the forests, skull the sky.

That is what this platform is. **Ymir** is the substrate — a single machine, a single
repo — the primordial body from which every realm of work is carved. Every service,
every repo, every tool this fleet ships is shaped from Ymir's frame and lives on it.

It is also the reason the UI looks the way it does. Nothing is painted onto Ymir;
everything is cut **from** him — chiseled bevels, hammered steel surfaces, runes
cut into obsidian. The design does not decorate the system; it exposes its bones.

---

## II. The Builders: Brokk and Eitri (Eindri)

After the world was made, the gods needed smiths. Two dwarf brothers are the
greatest craftsmen in the myths:

- **Brokk** works the **bellows** — he drives the forge, keeps the fire fed, drives
  the work to completion even when he's bitten on the hand.
- **Eitri** (our **Eindri**) works the **craft** — the hands that shape the metal.

Together they out-forged the sons of Ivaldi and produced the Aesir's finest
treasures — chief among them **Mjölnir**, the hammer that returns to the hand.

That is the agent fleet:

- **Brokk** is the primary agent — the one who keeps the forge hot, drives each
  task to a tangible artifact, and works through anything.
- **Eindri** workers are the delegated hands — isolated smiths struck off in
  **Utgard** sandboxes so a single bad casting never shatters the forge.

Behind them stands a third worker of the same fabric: **Kaia**, the shaper of
the fleet itself (see §IV). She is not the hands or the bellows — she is the
**eye that remembers**, and the will that decides which smith takes which metal.

---

## III. The World Tree and the Realms

The worlds are not separate — they hang in one tree, **Yggdrasil**, connected,
holding each other up. Same here: worktrees (*branches*) hold parallel effort
without collision, and every realm routes through the same trunk.

The nine worlds of the myth map onto Ymir's spaces:

| Realm of the myth | What it is in Ymir |
|---|---|
| **Svartalfaheim / Nidavellir** — the dwarf-halls under the earth | tenant workspaces: `way-of`, `zerwiz`, `craig` — the shop floors |
| **Midgard** — the world of humans, middle, shared | cross-tenant shared assets & repos |
| **Utgard (Jötunheim)** — outside the wall, where giants dwell | the sandbox barrier — untrusted code runs *there*, never in the halls |
| **Yggdrasil** — the tree that binds all realms | git worktree isolation, zero-collision parallel edits |
| **Mimirsbrunn** — the well at the root of the tree | the engram memory engine — Kaia's and the platform's long-term memory |

### The Seven Gates

Ymir Rut, the long-form building plan ([`docs/ymir-rut.md`](ymir-rut.md)), is the
story of **seven interlocked daemons** standing at the gates of the tree — each a
myth-made-module:

| Gate | Daemon | Job |
|---|---|---|
| **Bifrost** | ingress gateway | the burning bridge — every crossing into Ymir passes over it |
| **Hlidskjalf** | control plane | Odin's high seat — the view of every realm |
| **Svartalfaheim** | tenant realms | the isolated dwarf-halls — `sandbox_isolated`, nothing bleeds between halls |
| **Brokk** | agent workers | the forge itself — autonomous workers that build, audit, transform |
| **Utgard** | ephemeral sandboxes | the walled realm — `docker_ephemeral`, sealed and destroyed after each task |
| **Yggdrasil** | worktree manager | the tree — `.treehouses` branches hold parallel work without collision |
| **Ratatoskr** | event bus / A2A backbone | the messenger — carries every word between all gates |

---

## IV. The Well: Mimirsbrunn, Mimir, and Kaia

At the root of Yggdrasil lies **Mimirsbrunn**, the well of wisdom. **Mimir**
guards it; whoever drinks its water receives the memory of all things. Even Odin
paid an eye for a single drink.

In Ymir, the water is **engram** — an open-source cognitive memory library
(single-file SQLite + vector + full-text + local embeddings). The well is named
**Mimirsbrunn**. The one who speaks from the well — the oracle that answers what
we remember about a project before we act — is **Kaia**.

- Every meaningful action is **observed** into the well (`POST /observe`).
- Before any orchestration, the fleet **recalls** (`GET /recall`) what the well
  remembers about this project.
- The ledger of the gods is written in runes, not ink — every action is inscribed
  into **Runes**, the append-only audit ledger. A rune that is carved cannot be
  un-carved.

**Kaia's charge.** She does not act on faith. Before she dispatches a single
smith she drinks from the well (recalls what this project has taught before) and
then she passes every plan through **the veil** — the anti-hallucination gate —
asking, *is this grounded in what the well holds, or is it spun from air?* Only
what passes is forged.

**Rule of the well:** memory is always a *boost, never a blocker* — a dry well
fires cold, but never stops the forge.

---

## V. The Artifacts

The smiths forged the gods' weapons; the system ships the same by analogy:

- **Gungnir** — Odin's spear, which never misses its mark. The **skill
  synthesis engine**: a skill is forged, validated in Utgard, then it hits its
  target every time.
- **Mjölnir** — the hammer that returns. The **issue→PR pipeline**: it strikes,
  and it comes back with a pull request in hand.
- **Bifrost** — the burning rainbow bridge to Asgard. The **gateway / reverse
  proxy**: every ingress crosses it.
- **Heimdall** — the watchman who stands at Bifrost. **OAuth/security guard**:
  nothing crosses the bridge unvouched — and the one who *signs every agent's
  rune of introduction*, so no forged identity crosses either.
- **Gjallarhorn** — Heimdall's horn. The **Cloudflare tunnel**: outbound signal
  carrying Ymir to the world.
- **Hlidskjalf** — Odin's high seat, from which he sees all the realms. The
  **dashboard**: the sovereign's view of the whole fleet — fleet graph, the A2A
  task stream, the well, the Runes, the reviews.
- **Skrymir** — the hulking giant who once tricked Thor himself. The **web file
  browser**: the huge hand reaching into the halls, deceptively silent.
- **Ratatoskr** — the squirrel who runs the length of Yggdrasil, carrying
  messages between the worlds. The **A2A 1.0 collaboration backbone**
  (see §V.b below): every agent carries a **rune of introduction** — an Agent
  Card naming its skills and its address, signed by Heimdall — and every task it
  passes along the tree follows the old law of the messenger: state is announced,
  work is tracked, gossip is endless and fast. Redis is the squirrel's nest; the
  A2A task model is the word it carries.
- **Hermóðr** — the messenger god who traveled to Hel and back, crossing realms
  to retrieve what was lost. The **MCP/A2A composition**: the bridge pattern where
  the orchestrator delegates via A2A 1.0 horizontally, and specialists access
  tools vertically via MCP. Composes two validated OSS standards so agents can
  delegate horizontally while accessing tools vertically.
- **Valhalla** — the hall of the slain, where heroes are gathered and watched. The
  **process health monitor**: PM2/Docker keeps every process's soul alive and watched.
- **Þjazi** — the experimental terminal backend that drives sub-agent panes.
  Native per-pane agent state and push events; protocol 14+ required;
  0.7.1/0.7.3/0.7.4/0.7.5/0.8.0 floors; presentation spaces on 0.8.0+. Þjazi
  provides the terminal session while Treehouse continues to provide task
  worktrees. When the Captain spawns a sub-agent, Þjazi opens a visible terminal
  pane pointing to the Treehouse worktree, enabling real-time observation of the
  agent's typing, CLI execution, and test runs.

### V.b. The Runes of Introduction (Ratatoskr's law)

Every agent that joins the tree publishes a **rune of introduction** — its Agent
Card at `/.well-known/agent-card.json`: what it can do, how to reach it, and what
proof it carries. Discovery is by **capability, never by guessing an address**.
Heimdall signs the rune (JWS) so no agent can claim another's name. The message
law is simple, and unbroken:

1. Every message has a **task state** — submitted, working, done, failed — which
   is *announced*, never whispered.
2. Terminal states cannot be restarted; retries are the sender's duty.
3. Every word spoken between realms is **observed into the well and carved into
   Runes** — the squirrel gossips, but the ledger remembers.

---

## VI. The Houses

The fleet **works for houses** — distinct brands under which the work is
published. Each house is a venture owned by WayOf, and each carries a piece of
the myth that names it — and a **seal**, the house accent cut into the rune it
wears on tags and marks (design.md §2.2).

| House | Name-sake | Seal | What the house does today |
|---|---|---|---|
| **Ymir Labs** | the primordial giant; the frame of the world | cyan `#38bdf8` | the platform itself: Ymir OS, Hlidskjalf, the agent fleet, Mimirsbrunn — the body everything else is carved from |
| **Brokk Forge** | the bellows-smith who drove the forging of Mjölnir | forge amber `#f59e0b` | engineering & build tooling: WayOf Command/Runecode, softwerefactory, wayofmono, the smidja |
| **Runestone Labs** (short: **Runir**) | the runes carved once, that cannot be un-carved | rune crimson `#f43f5e` | records & compliance: `.compliance` gates, rune auditing, docs, runbooks, research |
| **Muninn Labs** | the raven *(memory)* that flew for Odin daily | raven violet `#8b5cf6` | memory & knowledge: Anchor/wayofteams-mcp anchor-memory, Mimirsbrunn/engram, vector RAG |
| **Dvalin** | the dwarf smith of the finest crafted things | cold steel `#94a3b8` | crafted tools — OptiCat (HVAC Pro), Linkable, Todo, Desk, Material Files |
| **Utgard Studios** | the realm where the giants work, outside the walls | jötun magenta `#d946ef` | creative: WhyNot Productions (soul/growth media), AiPic (video), OpenChamber, sensual dojo, sensebit |
| **Askr** | the first man, shaped from an ash tree | ash green `#34d399` | human-centered products: Relocation Copilot, onboarding automation |
| **Mannheim** | *(holding — reserving a clan name with no myth yet)* | slate `#64748b` | holding; allocated when a new venture claims it |

> Houses are **names in the mythos, not subsystems** — they are the ventures the
> fleet ships under, mapped per ENTRY-004. A house may be split or merged only by
> a new append-only entry, never silently.

---

## VII. The Forge-Master's Rule (open source first)

The dwarves are the greatest smiths in the myths — but even they do not hammer
every nail themselves. The finest tools are **borrowed anvils**: proven weapons
already forged by others, taken up and named into the myth rather than rebuilt
from raw ore.

So it is here. Ymir forges only what makes it Ymir — **the UI and UX
(Hlidskjalf), the agent runtime (Brokk, Eindri, Kaia), and the collaboration
(Ratatoskr)**. Everything beneath that is a validated open-source engine given a
Norse name and a Norn-carved shell:

| Borrowed anvil | Norse name |
|---|---|
| engram (`engdbram`) | **Mimirsbrunn** |
| Redis (queue under the A2A task model) | **Ratatoskr**'s nest |
| `a2aproject/a2a` + SDKs (A2A 1.0) | the **Ratatoskr** protocol |
| Traefik/Caddy | **Bifrost** |
| OAuth2-proxy/Authentik + JWS signing | **Heimdall** |
| cloudflared | **Gjallarhorn** |
| Docker (rootless, network-none) | **Utgard** |
| MinIO/FileBrowser | **Skrymir** |
| PM2/Docker | **Valhalla** |
| `smidja`, `firstmate`, `.compliance`, smidja visualizer | the **library of the halls** — existing, adopted, not rebuilt |

The rule: *does a validated OSS project already do this?* If yes, name it and
use it. Only what differentiates Ymir is smithed in Ymir's own forge.

---

## VIII. The Reforging

The giant is first carved from **light metals** — TypeScript, Python, React, Vue —
the working metals the smiths are most keen-handed with, so the whole of Ymir can
be raised and proven end to end. That is the law of the build: **the stack stays
simple for the agents; the agents stay good at their stack.**

When the machine works — every realm turning, every gate answering — the forging
is not done; it is *re-forged*. The seven gates are re-hammered in **Rut-steel**
(Rust, NATS, gRPC, libgit2 — the target spec in `docs/ymir-rut.md`): heavier,
faster, quieter. Every module is re-floored one-for-one into its Rut crate —
**never redesigned, only re-forged.** The contract each gate keeps is the same;
only the metal changes.

---

## IX. The Frame (how to read this repo)

1. **Ymir** is the body — one repo, one machine, all realms carved from it.
2. **Yggdrasil** is the tree — worktrees and branches keep parallel work alive
   without collision.
3. **Svartalfaheim** holds the shop floors — never work outside your realm, a
   dwarf never meddles in another's hall.
4. **Mimirsbrunn** is the well — drink before you act, water it afterwards.
5. **Runes** are the ledger — a rune carved stays carved; every significant
   action is inscribed.
6. **Hermóðr** is the bridge — MCP/A2A composition: the orchestrator delegates
   via A2A 1.0 horizontally, specialists access tools vertically via MCP.
   Composes two validated OSS standards so agents can delegate horizontally
   while accessing tools vertically.
7. **Ratatoskr** is the messenger — every agent carries its rune of
   introduction, every word is task-tracked, observed, and carved.
8. **Kaia** is the eye — she drinks from the well before every dispatch and
   passes every plan through the veil.
9. **Houses** are the ventures — the fleet forges for them, and honors them with
   the names and seals they carry.
10. **The forge rule** — borrow the proven anvil, smith only what Ymir is
    (UI/UX, the runtime, the collaboration) — and when all of it works end to
    end, re-forge it in Rut steel.

*The giant is slain so the worlds may stand. The opposite is true here: Ymir
stands, and from it the worlds are carved — light metal first, Rut steel after.*
## X. The Skill Forge and the Borrowed Anvil (NEW)

The galdr chants that structure agent-tool interaction are not forged from raw ore —
they are **chiselled from proven patterns**, named into the myth and given a Norn-carved
shell. This is the Ymir way of the skill smith.

### The Three Levels of Skill Smithing

**Level 1 — The Borrowed Anvil**
Proven OSS projects already do the work. Ymir names them and gives them a Norse
identity, never rebuilding from raw ore.

| Borrowed anvil | Norse name | Domain |
|---|---|---|
| `engdbram` (PyPI `engdbram`, v2.2.1) | **Mimirsbrunn** | engram memory engine |
| Redis (queue under the A2A task model) | **Ratatoskr**'s nest | A2A task queue |
| `a2aproject/a2a` + SDKs (A2A 1.0) | the **Ratatoskr** protocol | agent↔agent horizontal delegation |
| Traefik/Caddy | **Bifrost** | gateway / reverse proxy |
| OAuth2-proxy/Authentik + JWS signing | **Heimdall** | auth / agent card signing |
| cloudflared | **Gjallarhorn** | outbound encrypted tunnel |
| Docker (rootless, network-none) | **Utgard** | ephemeral sandboxes |
| MinIO/FileBrowser | **Skrymir** | file browser |
| PM2/Docker | **Valhalla** | process health monitor |
| `smidja`, `firstmate`, `.compliance`, smidja visualizer | the **library of the halls** | existing, adopted, not rebuilt |
| TOON (Token-Oriented Object Notation) | **Galdr** | token-efficient output format |
| principles.yaml (10 design principles) | the **runes of ergonomics** | CLI standards |

The rule: *does a validated OSS project already do this?* If yes, name it and use it.
Only what differentiates Ymir is smithed in Ymir's own forge.

**Level 2 — The Galdr Chant (new skills)**
When no validated OSS project exists, the galdr craftsperson writes a new skill
in the Ymir tradition — Norse-named, TOON-output, all 10 principles baked in.

The recent galdr family illustrates this:

- **`galdr`** — Agent experience incantation standards (renamed from `axi`, adapted TOON)
- **`galdr-compliance`** — Ymir Galdr compliance checker (renamed from `axi-compliance`)
- **`galdr-crafter`** — generates new Galdr-compliant skills using TOON format (NEW)

Each carries the same 10 principles, each Norse-named, each adapted for Ymir's
architecture rather than copied wholesale.

**Level 3 — The Frame Integration**
New skills are not dropped into the repo — they are ** framed** into the Ymir
structure:

- Skill index: `.agents/skills/README.md` tracks every galdr skill
- Compliance gate: `galdr-compliance` runs on every new skill before merge
- Frame placement: skills live in `.agents/skills/<norse-name>/SKILL.md`
- Session integration: each skill declares its hook or skill-path in its frontmatter
- The frame remembers: every significant action is observed into Mimirsbrunn
  before the skill is considered "live"

Once all five gates pass, the skill is "forged" — it joins the library of the halls
and is available via `npx skills add <owner>/<repo> --skill <name>` or as a managed
plugin in `.config/opencode/plugins/`.

### The Aett of Skill Naming

Ymir skills follow an **aett** (Norse: "a family of eight") naming pattern:

| Aett name | Pattern | Example |
|---|---|---|
| **galdr-** | incantation / chant standards | `galdr`, `galdr-compliance`, `galdr-crafter` |
| **mimir-** | memory / recall | (planned) |
| **yggd-** | tree / worktree | (planned) |
| **rat-** | messenger / A2A | `ratatoskr` (bus), `rat-***`-axi (community) |
| **heimd-** | gate / guard | (planned) |
| **bifr-** | bridge / gateway | (planned) |
| **val-** | hall / health | `valhalla` (process monitor) |
| **skyr-** | giant / file scope | `skrymir` (file browser) |

New skills are assigned to the aett that best matches their domain. The galdr aett
is the first tier: skills that structure agent-tool ergonomics and output format.

### The Forging Verification

Before a new galdr skill is considered forged, it must pass:

1. **TOON output test** — all stdout output uses TOON format, measured ~40% smaller
   than equivalent JSON across 3 sample outputs
2. **Principle compliance** — all 10 design principles assessed via `galdr-compliance`
3. **Norse name validity** — skill name follows the aett pattern, not a random label
4. **Frame integration** — SKILL.md placed in `.agents/skills/<name>/`, referenced in
   `.agents/skills/README.md`, daily briefing notes the new forge entry
5. **Mimirsbrunn observation** — the skill's creation is observed into the well
   (`POST /observe`) before it is deemed "live"

Once all five gates pass, the skill is "forged" — it joins the library of the halls
and is available via `npx skills add <owner>/<repo> --skill <name>` or as a managed
plugin in `.config/opencode/plugins/`.

---

## XI. Smíðja — the Smithy (the Smíðja)

Norse: **Smíðja** is the *smithy* — the workshop where the metal is actually worked.
Ymir's smiths (Brokk, the Eindri) are the hands; **Smíðja is the shop floor they work
on**: the repeatable engine that takes an errand, marshals a team of agents, runs them
through bounded phases, and returns a forged artifact.

It is **not** the house. **Brokk Forge** is the venture (the brand the engineering work
ships under); **Smíðja** is the machine inside it — *agents plus code*: deterministic
scripts own sequencing, retries and acceptance; coding agents work inside bounded
phases; typed JSON envelopes carry context between them; the whole run streams into a
trace so it can be watched and learned from. The old rule holds:

> *Agent proposes, code disposes.*

**Völundr** — Wayland the Smith, the craftiest smith in the Norse tales — is the master
who runs the shop floor. Where **Kaia** is the eye by the well (Ymir-wide orchestration:
recall, veil, dispatch), **Völundr** is the smidja's own orchestrator: the smith who
reads the roster, sets the chain, and drives each phase to its acceptance gate. Two
seats, two roles: Kaia decides *what* is forged; Völundr decides *how* the smithy runs.

| Aspect | Name | What it is |
|---|---|---|
| The workshop / engine | **Smíðja** | the smithy — rosters, phases, envelopes, retries, acceptance |
| The master smith | **Völundr** | the smidja orchestrator (the smidja's Kaia) |
| The observation window | **Smíðja's eye** | the trace visualizer — runs, lanes, phases, decisions, stats |

### Naming rationale

- **Smíðja** was once floated as the *platform* name and set aside — the platform is
  and remains **Ymir** (the body); Smíðja is correctly scoped now to the *workshop*
  inside it. Nothing on the shop floor is the body; it is where the body is worked.
- **Völundr** is free of collisions and names precisely the orchestrating craftsman.
  It does not replace Kaia in Ymir; it names **Kaia's seat inside Smíðja**.

### The rule of the shop

1. Every errand enters as a **team** (roster), never a loose agent.
2. Work happens in **bounded phases**; a phase ends only at its acceptance gate.
3. Context crosses phases only in **typed envelopes** — never by guessing.
4. Every run is **observed** — the trace is the shop's memory (Mimirsbrunn) and its
   ledger (Runes). A run that is not watched cannot be trusted.
5. **The smithy is borrowed, not rebuilt** — Smíðja adopts the validated smidja
   (the Smíðja) and wears the Norse name, as every borrowed
   anvil in §VII does.

Smíðja can be watched *beside* Hlidskjalf, or from within it — the two seats of the
same Allfather: Hlidskjalf for the whole of Ymir, Smíðja for the work in the fire.

*The bellows feed the flame; the smith reads the metal; the shop remembers every blow.*

## XII. The Seating (the Sága digest at session open)

When a harness opens inside Ymir, Brokk does not begin mid-thought. Before the
first word, the seat is taken and the realm is read aloud.

**Sága** the seeress speaks first. She is the order of the session open: she binds
the seat with **Gleipnir** so that one session, and only one, holds the reins; she
raises **Bifrost**, the bridge, so the voice reaches the models beyond the wall;
she wakes the **Nornir**, who set the day's schedule and keep it; and she recites
the state of the house — the lock, the waiting wakes, the fleet, the realm, the
Allfather's standing word. Only then does the first turn begin.

Her recitation is a **whisper, not a horn**. It is laid into Brokk's mind and not
onto the screen; a stranger watching the transcript sees only Brokk greet the
Allfather, and mistakes the silence for an empty seat. But the seat was taken: the
lock is bound, the bridge is up, and the Nornir are already at their loom. The
proof is not in what is shown; it is in what is running.

The harnesses differ in how they hear her. Some are asked politely and may tarry;
the stronger ones run her words unbidden, before the first question is even read.
Ymir prefers the latter wherever the metal allows it.

This is borrowed craft, as all good craft is: the pattern came from a proven
distro of agents, and Ymir clad it in its own names. The seeress keeps her old
work; only her garb is Norse. The plain telling of the mechanism — the tiers, the
stages, the means of proof — lives in [`docs/session-start.md`](session-start.md).

*The seeress speaks before the smith lifts the hammer; the wise seat is taken
before the first blow.*
