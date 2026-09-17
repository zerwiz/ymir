# YMIR — The Lore

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
| **Svartalfaheim / Nidavellir** — the dwarf-halls under the earth | tenant workspaces — the shop floors |
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
| **Yggdrasil** | worktree manager | the tree — `.yggdrasil` branches hold parallel work without collision |
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
  provides the terminal session while Yggdrasil continues to provide task
  worktrees. When the Allfather spawns a sub-agent, Þjazi opens a visible terminal
  pane pointing to the Yggdrasil worktree, enabling real-time observation of the
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
| the upstream `firstmate` distro, `.compliance`, the **Smíðja visualizer** | the **library of the halls** — existing, adopted, not rebuilt |

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
| the upstream `firstmate` distro, `.compliance`, the **Smíðja visualizer** | the **library of the halls** | existing, adopted, not rebuilt |
| TOON (Token-Oriented Object Notation) | **Galdr** | token-efficient output format |
| principles.yaml (10 design principles) | the **runes of ergonomics** | CLI standards |

The rule: *does a validated OSS project already do this?* If yes, name it and use it.
Only what differentiates Ymir is smithed in Ymir's own forge.

**Level 2 — The Galdr Chant (new skills)**
When no validated OSS project exists, the galdr craftsperson writes a new skill
in the Ymir tradition — Norse-named, TOON-output, all 10 principles baked in.

The recent galdr family illustrates this:

- **`galdr`** — Agent experience incantation standards (renamed from `axi`, adapted TOON)
- **`tyr-check`** — Ymir Galdr compliance checker (renamed from `axi-compliance`)
- **`brokk-craft`** — generates new Galdr-compliant skills using TOON format (NEW)

Each carries the same 10 principles, each Norse-named, each adapted for Ymir's
architecture rather than copied wholesale.

**Level 3 — The Frame Integration**
New skills are not dropped into the repo — they are ** framed** into the Ymir
structure:

- Skill index: `.agents/skills/README.md` tracks every galdr skill
- Compliance gate: `tyr-check` runs on every new skill before merge
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
| **galdr-** | incantation / chant standards | `galdr`, `tyr-check`, `brokk-craft` |
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
2. **Principle compliance** — all 10 design principles assessed via `tyr-check`
3. **Norse name validity** — skill name follows the aett pattern, not a random label
4. **Frame integration** — SKILL.md placed in `.agents/skills/<name>/`, referenced in
   `.agents/skills/README.md`, daily briefing notes the new forge entry
5. **Mimirsbrunn observation** — the skill's creation is observed into the well
   (`POST /observe`) before it is deemed "live"

Once all five gates pass, the skill is "forged" — it joins the library of the halls
and is available via `npx skills add <owner>/<repo> --skill <name>` or as a managed
plugin in `.config/opencode/plugins/`.

---

## XI. Smíðja — the Smithy (the Software Factory)

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
recall, veil, dispatch), **Völundr** is Smíðja's own orchestrator: the smith who
reads the roster, sets the chain, and drives each phase to its acceptance gate. Two
seats, two roles: Kaia decides *what* is forged; Völundr decides *how* the smithy runs.

| Aspect | Name | What it is |
|---|---|---|
| The workshop / engine | **Smíðja** | the smithy — rosters, phases, envelopes, retries, acceptance |
| The master smith | **Völundr** | the Smíðja orchestrator (Kaia's seat inside Smíðja) |
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
5. **The smithy is borrowed, not rebuilt** — Smíðja adopts the validated upstream
   engine and wears the Norse name, as every borrowed anvil in §VII does.

Smíðja can be watched *beside* Hlidskjalf, or from within it — the two seats of the
same Allfather: Hlidskjalf for the whole of Ymir, Smíðja for the work in the fire.

*The bellows feed the flame; the smith reads the metal; the shop remembers every blow.*

## XII. Smíðja's Eye — the trace visualizer (ports & how it is raised)

Smíðja's work is only as trustworthy as the sight of it. The observer (**Huginn**)
keeps the ledger; **Smíðja's eye** is the live trace UI — a Vue + Bun app that
polls the smithy's own SQLite trace and draws the run: sessions, phase lanes,
envelopes, gates and their evidence, decisions, stats, and Völundr's memory.

One trace, one face — plus an optional dev face:

| Face | Port | What it is |
|---|---|---|
| API + built UI | `127.0.0.1:8437` | Bun server, read-only over `smidja/smidja_data/smidja.db` (`bun:sqlite`); serves the built Vue `dist/` on the same port |
| Dev UI (optional) | `127.0.0.1:8438` | Vite dev server, only with `SMIDJA_VIZ_DEV=1`; proxies `/api` → `:8437` |

Open the visualizer at **`http://127.0.0.1:8437/`**.

- The trace DB is **repo-local**: `$YMIR_ROOT/smidja/smidja_data/smidja.db`.
  Any Smíðja run writes it; the Hlidskjalf gates (Sessions / Trace / Decisions /
  Stats) and this visualizer both read it.
- Ports are overridable: `SMIDJA_VIZ_API_PORT`, `SMIDJA_VIZ_UI_PORT`. The SPA's
  link uses `VITE_VISUALIZER_URL` (default `http://127.0.0.1:8437`).

### How it is raised

`scripts/start.sh` raises the whole seat in one command, and `scripts/stop.sh`
lowers it:

1. Hlidskjalf SPA — `:3888`
2. Hlidskjalf gate API — `:3889` (`apps/hlidskjalf/server`, reads the runtime)
3. Smíðja visualizer — `:8437` (`CMD_DB=<repo>/smidja/smidja_data/smidja.db`; API + built UI)
4. Nornir cron + Bifrost bridge

```bash
scripts/start.sh      # raise: SPA :3888 · gate API :3889 · visualizer :8437
scripts/stop.sh       # lower them all
```

The **Sessions** gate (Hlidskjalf) carries **Open visualizer**, which opens
`http://127.0.0.1:8437` in a new tab; it also has **Refresh**, and the app polls
`smidja.db` every five seconds so a newly-finished run appears on its own.
Hlidskjalf and the visualizer are two windows on the same smithy: the seat that
sees all of Ymir, and the eye on the work in the fire. Open them side by side.

*The seeress keeps the ledger; the eye keeps the fire in view.*

## XIII. The Seating (the Sága digest at session open)

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

## XIV. The Open Forge (external contribution)

Ymir is not a closed hall. Anyone may fork the repo, work in their own copy, and
send a pull request back to the main tree. The gate is open — the law is simple.

### The Fork Law

1. **Fork** the repo on GitHub.
2. **Clone** your fork, make changes on a feature branch.
3. **Open a PR** against `zerwiz/ymir:main` (or `zerwiz/ymir:main` if you
   cloned from the personal fork).
4. **One thing per PR.** A PR does one focused thing — a fix, a feature, a
   refactor.
5. **No secrets.** Never commit `.env.local`, `.env.realm`, API keys, tokens.
6. **Norse naming.** Name subsystems for the figure whose role matches its work.
7. **Human approval.** All PRs require explicit approval from the Allfather.

### The Agent's Path (Eindri)

Every agent in the Ymir tree carries the **pr-ops** skill — the pull request
lifecycle. It pairs with **git-ops** (branch creation, commits, sync) so the
full workflow is scripted:

```
1. git-ops create_branch → feat/my-change
2. Make changes, commit (git-ops safe_commit)
3. git-ops sync_upstream → push + rebase
4. pr-ops pr-create feat/my-change → opens PR
5. pr-ops pr-status → check CI
6. pr-ops pr-merge → request human approval
```

The skill is at `.agents/skills/pr-ops/SKILL.md`. It is the standard path for
any agent that needs to send work back to the main tree.

### The Repository Today

The repo is the body — one tree, one machine, all realms carved from it.
It carries:

- **The platform** — Hlidskjalf (portal), Brokk (agent runtime), Ratatoskr (A2A)
- **The smithy** — Smíðja (agent factory, Völundr orchestrator)
- **The realms** — Svartalfaheim (tenant workspaces), Midgard (shared assets)
- **The gates** — Bifrost, Heimdall, Gjallarhorn, Utgard, Yggdrasil
- **The skills** — 21+ Norse-named capabilities in `.agents/skills/`
- **The plans** — 20+ architectural plans in `docs/plans/`
- **The lore** — this file, the load-bearing allegory

*The forge is open. The hammer falls for anyone who brings good metal.*

## XV. The Allfather's Seat (and the cloth of the halls)

There is one operator, and it is the **Allfather**. The smithy was borrowed from
an older shop and still calls the caller *engineer* in its ledgers — that is the
borrowed word and it stays in the books, but in the halls of Hlidskjalf the seat
is named true. When the ledger of runs is read, the column is **Allfather**.
When a phase is traced, the one who called it is the Allfather. No borrowed
title is worn on the wall.

### The cloth of the halls

Every hall wears the same cloth. A picker, a list, a form — none of them hangs
raw. A list that spills past the frame, or a control that ignores the realm's
tint and steel, is a hall that was left unroofed. Three rules hold:

1. **The realm's cloth.** Colours, radius, and type come from the theme tokens —
   never a stock browser control dropped in bare.
2. **The frame holds.** Long catalogs are held in a scroll of the hall's making,
   searched and thinned, so the wall never stretches to the floor.
3. **The hand reaches.** Anything the eye sees, the hand can touch: the prompts
   of an agent are opened from that agent, not hunted in a separate room.

### The three new seats

- The **Ledger of Runs** — the smithy's whole account rendered true: runs,
  tokens, cache and cost, the local and the cloud split, and what the work
  would have cost on the great vendors. Every figure is counted, none guessed.
- **Kaia's Long Table** — the oracle's chat: she keeps the last **forty**
  exchanges in view, and she **drinks from the well before every dispatch**, so
  no answer is spoken dry. The thread is hers to keep, split, and clear.
- The **Prompt Anvil** — in the Forge, the words that command each agent are
  laid open and may be struck and re-set by the Allfather's own hand.

*One seat, one cloth, one open anvil: the hall is built for the hand that
calls.*

## XVI. The Binding and the Watch (Gleipnir, Skuld, Valknut)

Three mechanisms hold the fleet together — a lock, a ledger of futures, and a
knot that binds the load.

### Gleipnir — the binding lock

**Gleipnir** was the ribbon that bound the great wolf Fenrir — thin, unbreakable,
forged from six things: the sound of a cat's footfall, the beard of a woman,
the roots of a mountain, the sinews of a bear, the breath of a fish, and the
spit of a bird. In Ymir, Gleipnir is the **session lock** — one session, one
reins. When Sága speaks at session open, she binds Gleipnir so no other harness
may hold the seat. The lock is a file (`.lock`) that holds the live PID of the
harness process; when the process dies, the lock breaks.

- `bin/gleipnir-lock-lib.sh` — lock/unlock primitives
- `bin/brokk-lease.sh` — acquire/release a lease (Gleipnir's grip)
- `bin/brokk-lease-lib.sh` — lease helpers

**Rule:** a broken lock means the seat is free; a held lock means the seat is
occupied. No two sessions may hold the same seat.

### Skuld — the branch outcome

**Skuld** is the youngest Norn — she who *shall be*. She sees the future of every
branch, the outcome of every merge, the shape of what will be. In Ymir, Skuld
is the **branch outcome tracker** — every branch that enters the tree is given
a prompt, a review, and an outcome. The outcomes are durable; they survive
reboots, resets, and context compaction.

- `bin/skuld-branch-prompt.sh` — generate the review prompt for a branch
- `bin/skuld-branch-outcome.sh` — record the outcome (approved, rejected,
  merged, abandoned)

**Rule:** no branch merges without Skuld's verdict. The outcome is carved into
the branch's durable store and observed into Mimirsbrunn.

### Valknut — the load mechanism

**Valknut** is the knot of the slain — three interlocking triangles, the mark
of Odin's choice. In Ymir, Valknut is the **load mechanism** — it assembles
the agent config, the Eindri dispatch, the harness settings, and the startup
memory budget into a single coherent payload before the first turn.

- `bin/valknut-load.sh` — load the full agent configuration
- upstream `crew-dispatch.json` dispatch schema (provenance; Ymir ships `eindri-dispatch.json`)
- `.agents/config/eindri-dispatch.json` — Eindri dispatch schema
- `.agents/config/cron.yaml` — Nornir schedule
- `.agents/config/startup-memory-budget` — memory limits at boot
- `.agents/config/eindri-harness/` — harness profiles for Eindri workers

**Rule:** Valknut loads once at session start. What it loads is the shape of
the fleet for this session — agents, models, memory budget, cron schedule.

---

## XVII. The Diagnostics and the Brief (Vor, Erindi)

Two mechanisms govern how work enters the forge and how the fleet's health is
monitored.

### Vor — the vigilant one

**Vör** is the goddess who sees everything — she has a memory so sharp that
nothing escapes her. In Ymir, Vor is the **diagnostics and Eindri state** engine.
She bootstraps the fleet, checks Eindri state, and reports health.

- `bin/vor-crew-state.sh` — check the state of all Eindri workers
- `vor-diagnostics` skill — bootstrap + diagnostic reasoning

**Rule:** Vor runs before every dispatch. If the Eindri are unhealthy, the dispatch
is delayed or rerouted.

### Erindi — the errand

**Erindi** is the Norse word for *errand* or *brief*. In Ymir, the erindi is
the **task brief** — the structured format that carries a task from the Allfather
through Kaia to an Eindri worker. It defines the scope, the acceptance criteria,
the constraints, and the expected output.

- `bin/erindi-brief.sh` — generate and validate an erindi brief

**Rule:** every task enters as an erindi. No task is dispatched without a brief.

---

## XVIII. The Shape-Changer and the Consent Gate (Hamr, Frigg)

Two mechanisms govern how the fleet adapts and how consent is obtained.

### Hamr — the shape-changer

**Hamr** means *shape* or *form*. In the myths, shape-changers take different
forms to accomplish different tasks. In Ymir, Hamr is the **harness adapter** —
it translates between different agent harnesses (Pi, OpenCode, Claude Code,
Cursor) and presents a unified interface.

- `bin/hamr-harness.sh` — harness adapter script
- `hamr` skill — per-harness adapter reference

**Rule:** Hamr adapts; it does not decide. The harness shape changes; the
fleet's job does not.

### Frigg — the consent gate

**Frigg** is the queen, Odin's wife, who knows the fate of all but cannot
reveal it until it comes to pass. In Ymir, Frigg is the **consent gate** —
the authority that asks the user before any action that cannot be undone.

- `frigg-consent` skill — consent / ask-user authority gate

**Rule:** Frigg speaks before the hammer falls. No irreversible action proceeds
without her consent.

---

## XIX. The Earth and the Decision-Hold (Jörð, Urðr)

Two mechanisms govern project tracking and decision lifecycle.

### Jörð — the earth goddess

**Jörð** is the earth herself, mother of Thor. In Ymir, Jörð is the **project
registry** — the living record of every project, its posture, its delivery
state, its dependencies.

- `jord-projects` skill — project registry + delivery posture

**Rule:** Jörð remembers what exists. Before any new project is forged, Jörð
is consulted.

### Urðr — the decision-hold

**Urðr** is the eldest Norn — she who *was*. She measures the past, holds
decisions, and reconciles the Allfather's hold.


**Rule:** Urðr holds what has been decided. A decision held by Urðr cannot
be silently overwritten; it must be explicitly closed or updated.

---

## XX. The Recovery and the Away Mode (Sýn, Hvíld)

Two mechanisms govern worker health and idle supervision.

### Sýn — the seer

**Sýn** is one of the goddesses who visits every nine nights to watch over
the worlds. In Ymir, Sýn is the **stuck-worker recovery** playbook — when an
Eindri worker is stuck, failing, or unresponsive, Sýn intervenes.

- `syn-recovery` skill — stuck-worker recovery playbook
- `syn-arm-pretool-check.sh` — pre-tool check for arm
- `syn-cd-pretool-check.sh` — pre-tool check for CI/CD
- `syn-turnend-guard.sh` — turn-end guard
- `syn-watch-arm.sh` — watch arm

**Rule:** Sýn never lets a worker die in silence. A stuck worker is recovered
or replaced.

### Hvíld — the rest

**Hvíld** means *rest* or *idle*. In Ymir, Hvíld is the **away-mode
supervision** — when the Allfather is away, Hvíld keeps watch, handles
routine wakes, and batches escalations.

- `hvild-afk` skill — away-mode supervision
- `bin/saga-wake-drain.sh` — wake drain for Hvíld

**Rule:** Hvíld watches while the Allfather rests. It does not act; it
escalates.

---

## XXI. The Update and the Relay (Ymir-update, Gjallarhorn-relay)

Two mechanisms govern self-maintenance and external communication.

### Ymir-update — the self-update

**Ymir-update** is the **self-update mechanism** — it updates the running
system and its workers without human intervention, within bounds.

- `ymir` skill (update asset) — self-update the running system + workers

**Rule:** Ymir-update is safe. It never breaks the forge; it only sharpens
the tools.

### Gjallarhorn-relay — the public relay

**Gjallarhorn-relay** is the **public relay** — it posts replies to external
channels (X/Twitter, Discord) from inside the fleet.

- `gjallarhorn-relay` skill — public relay replies (X/Discord)
- `bin/gjallarhorn-notify.sh` — notify script
- `bin/telegram-bot.sh` — Telegram bot integration

**Rule:** Gjallarhorn-relay speaks only what the fleet has decided. It does
not originate; it broadcasts.

---

## XXII. The Nornir's Array (Nornir-events, Nornir-quota)

The Nornir do not just schedule — they select and source.

- **Nornir-events** — process→event sources. Every running process is
  converted into an event that enters the fleet's event stream.
- **Nornir-quota** — quota-aware dispatch array selection. Before dispatch,
  Nornir checks quotas and selects the right array of workers.

**Rule:** The Nornir see past, present, and future. They schedule (past),
select (present), and source (future).

---

## XXIII. The Agent Fleet (the Einherjar)

The Einherjar are the gathered warriors — the agents who serve the Allfather.
Each is named for the figure whose role matches its work.

| Agent | Norse | Role | File |
|-------|-------|------|------|
| **Brokk** | Brokk | Primary agent — the bellows, the forge driver | `.agents/agents/brokk.md` |
| **Sindri** | Sindri | The smith — code synthesis, refactoring, tests | `.agents/agents/sindri-developer.md` |
| **Bragi** | Bragi | The poet — marketing, content, social | `.agents/agents/bragi-marketer.md` |
| **Huginn** | Huginn | The thought — research, web search, analysis | `.agents/agents/huginn-researcher.md` |
| **Mimir** | Mimir | The planner — memory, recall, planning | `.agents/agents/mimir-planner.md` |
| **Kvasir** | Kvasir | The wisest — scout, reconnaissance | `.agents/agents/kvasir-scout.md` |
| **Forseti** | Forseti | The reconciler — reviewer, compliance | `.agents/agents/forseti-reviewer.md` |
| **Snotra** | Snotra | The modest — documenter, docs, runbooks | `.agents/agents/snotra-documenter.md` |
| **Galdr** | Galdr | The master builder — runtime, CLI, ergonomics | `.agents/agents/galdr.md` |

**Rule:** Every agent carries its rune of introduction (Agent Card). Every
agent reports to Brokk. Brokk reports to the Allfather.

---

## XXIV. The Midgard Commons

**Midgard** is the world of humans — the shared space between realms. It holds
what belongs to all houses, nothing to one.

| Path | What it holds |
|------|---------------|
| `midgard/design-system/` | Theme tokens, icons, rune glyphs, component rules |
| `midgard/github_org_repos/` | GitHub organization repo inventory |
| `midgard/shared-packages/` | Shared npm/Python packages |

Midgard holds **public-by-design** cross-tenant assets only. Company knowledge —
policies, vision, specs, client names — is **tenant data** and lives at
`$YMIR_HOME/hodd/identity/companies/`. A company wiki here would publish that
company's internals in a public repo.
| `midgard/infrastructure/` | DB schemas, Caddyfile, cloudflared, oauth2-proxy |

**Rule:** Midgard is shared. No realm may mutate another realm's Midgard assets.

---

## XXV. The Wyrd Database

**Wyrd** is fate — the inescapable shape of what will be. In Ymir, Wyrd is the
**workspace RAG database** — it indexes every file, every commit, every change,
so that recall is fast and accurate.

- `bin/wyrd-db.sh` — Wyrd database operations
- `bin/workspace-rag.sh` — workspace RAG indexing

**Rule:** Wyrd remembers everything. It does not judge; it retrieves.

---

## XXVI. The Toolchain and the Justfile

**The toolchain** is the unified entry point for all Ymir operations. It wraps
individual scripts, validates arguments, and routes to the right tool.

- `bin/toolchain.sh` — unified toolchain entry point
- `justfile` — task runner (replaces Makefile)

**Rule:** The toolchain is the door. Everything enters through it.

---

## XXVII. The Entity Graph

**The entity graph** is the knowledge graph of every company, project, and
relationship in Svartalfaheim. It maps ownership, dependencies, and delivery
posture.

- `svartalfaheim/way-of/workspace/memory/entity_graph/` — entity graph data

**Rule:** The entity graph is append-only. Changes are new entries, not edits.

---

## XXVIII. The Veil and the Glitnir Gate

Two gates govern what passes and what is reviewed.

### The Veil — the anti-hallucination gate

**The Veil** is the filter between what the well remembers and what is spoken.
Before Kaia dispatches a single smith, she passes every plan through the Veil,
asking: *is this grounded in what the well holds, or is it spun from air?*

**Rule:** Nothing passes the Veil without evidence from Mimirsbrunn.

### Glitnir — the review gate

**Glitnir** is the shining hall where the gods hold their judgments. In Ymir,
Glitnir is the **human review gate** — every PR, every merge, every production
deploy must pass through Glitnir. The Allfather is the judge.

**Rule:** Glitnir never auto-approves. Human approval is always required.

---

## XXIX. The Full Skill Index

The complete index of all Norse-named skills in Ymir:

| Skill | Norse | Purpose |
|-------|-------|---------|
| `galdr` | Galdr | Agent-CLI ergonomics + master builder of the runtime |
| `tyr-check` | Tyr | The judge — 10 Galdr principles + runtime gates |
| `smidja` | Smiðja | The smithy — roster, phases, envelopes, factory |
| `hvild-afk` | Hvíld | Away-mode supervision — routine wakes, batched escalations |
| `saga` | Sága | session bearings: fleet digest (/bearings) + recap (/ahoy) |
| `muninn-stow` | Muninn | Session-knowledge curation, routing, persistence |
| `jord-projects` | Jörð | Project registry + delivery posture |
| `urdh` | Urðr | Allfather-hold lifecycle |
| `frigg-consent` | Frigg | Consent / ask-user authority gate |
| `vor-diagnostics` | Vör | Bootstrap + diagnostic reasoning |
| `nornir` | Nornir | fate & schedule: events + quota |
| `gjallarhorn-relay` | Gjallarhorn | Public relay replies (X/Discord) |
| `eindri-homes` | Eindri | Isolated worker homes (provisioning) |
| `syn-recovery` | Sýn | Stuck-worker recovery playbook |
| `ymir` (update) | Ymir | Self-update the running system + workers |
| `hamr` | Hamr | Per-harness adapter reference |
| `pr-ops` | — | PR lifecycle — create, update, check status, request merge |

**Total: 21 skills.** All Norse-named except where the name was already taken
by a borrowed anvil (pr-ops). Local-model operation is a galdr asset, not a skill:
`assets/local-models.md`.

---

## XXX. The Complete Frame

How to read the full Ymir tree:

1. **Ymir** is the body — one repo, one machine, all realms carved from it.
2. **Yggdrasil** is the tree — worktrees and branches keep parallel work alive
   without collision.
3. **Svartalfaheim** holds the shop floors — never work outside your realm.
4. **Midgard** is the commons — shared assets, nothing to one realm.
5. **Mimirsbrunn** is the well — drink before you act, water it afterwards.
6. **Runes** are the ledger — a rune carved stays carved.
7. **Ratatoskr** is the messenger — every agent carries its rune of introduction.
8. **Kaia** is the eye — she drinks from the well before every dispatch.
9. **Völundr** is the smithy master — Kaia's seat inside Smíðja.
10. **Gleipnir** is the lock — one session, one reins.
11. **Skuld** is the outcome — every branch has a verdict.
12. **Valknut** is the load — config assembled once at boot.
13. **Vor** is the watch — Eindri state checked before dispatch.
14. **Erindi** is the brief — every task enters structured.
15. **Hamr** is the shape — harness adapter, unified interface.
16. **Frigg** is the consent — no irreversible action without her word.
17. **Jörð** is the earth — project registry, living record.
18. **Urðr** is the past — decision-hold, reconciliation.
19. **Sýn** is the seer — stuck-worker recovery.
20. **Hvíld** is the rest — away-mode supervision.
21. **Wyrd** is the fate — workspace RAG database.
22. **The Veil** is the filter — nothing passes without well evidence.
23. **Glitnir** is the gate — human review, always required.
24. **Houses** are the ventures — the fleet forges for them.
25. **The Einherjar** are the agents — eight specialists, one primary.
26. **The toolchain** is the door — everything enters through it.
27. **The entity graph** is the map — ownership, dependencies, posture.
28. **The cloth of the halls** — realm colors, frame holds, hand reaches.
29. **The three seats** — Ledger of Runs, Kaia's Long Table, Prompt Anvil.

*The giant stands, and from it the worlds are carved — light metal first,
Rut steel after. The lock is bound, the bridge is up, the Nornir are at their
loom. The seat is taken. The forge is lit.*

Smíðja's work is only as trustworthy as the sight of it. The observer (**Huginn**)
keeps the ledger; **Smíðja's eye** is the live trace UI — a Vue + Bun app that
polls the smithy's own SQLite trace and draws the run: sessions, phase lanes,
envelopes, gates and their evidence, decisions, stats, and Völundr's memory.

One trace, one face — plus an optional dev face:

| Face | Port | What it is |
|---|---|---|
| API + built UI | `127.0.0.1:8437` | Bun server, read-only over `smidja/smidja_data/smidja.db` (`bun:sqlite`); serves the built Vue `dist/` on the same port |
| Dev UI (optional) | `127.0.0.1:8438` | Vite dev server, only with `SMIDJA_VIZ_DEV=1`; proxies `/api` → `:8437` |

Open the visualizer at **`http://127.0.0.1:8437/`**.

- The trace DB is **repo-local**: `$YMIR_ROOT/smidja/smidja_data/smidja.db`.
  Any Smíðja run writes it; the Hlidskjalf gates (Sessions / Trace / Decisions /
  Stats) and this visualizer both read it.
- Ports are overridable: `SMIDJA_VIZ_API_PORT`, `SMIDJA_VIZ_UI_PORT`. The SPA's
  link uses `VITE_VISUALIZER_URL` (default `http://127.0.0.1:8437`).

### How it is raised

`scripts/start.sh` raises the whole seat in one command, and `scripts/stop.sh`
lowers it:

1. Hlidskjalf SPA — `:3888`
2. Hlidskjalf gate API — `:3889` (`apps/hlidskjalf/server`, reads the runtime)
3. Smíðja visualizer — `:8437` (`CMD_DB=<repo>/smidja/smidja_data/smidja.db`; API + built UI)
4. Nornir cron + Bifrost bridge

```bash
scripts/start.sh      # raise: SPA :3888 · gate API :3889 · visualizer :8437
scripts/stop.sh       # lower them all
```

The **Sessions** gate (Hlidskjalf) carries **Open visualizer**, which opens
`http://127.0.0.1:8437` in a new tab; it also has **Refresh**, and the app polls
`smidja.db` every five seconds so a newly-finished run appears on its own.
Hlidskjalf and the visualizer are two windows on the same smithy: the seat that
sees all of Ymir, and the eye on the work in the fire. Open them side by side.

*The seeress keeps the ledger; the eye keeps the fire in view.*

---

## XVII. The Renewal and the Healing (Gróa, Eir)

The tree does not stay young on its own. Two figures tend it when the work is
not going forward but must still be made right: one who **renews**, and one who
**heals**.

**Gróa** is the *völva* — the shamaness whose name means *to grow*. In the old
tales she comes to mend what battle has left broken. In Ymir she is the
**updater shaman**: she fast-forwards Brokk and every registered Eindri-home to
the latest from origin — never forcing, never stashing, advancing only a clean
fast-forward, and skipping anything dirty, diverged, or offline — then mends the
tree forward through its migrations and fleet preferences. **Brokk** runs her;
**Galdr** owns the assets she must be reflected in the moment the instruction
surface moves (`galdr-reread`); the `groa-update` skill (`/updateBrokk`) is her
door. She lives in `bin/groa-update.sh`; `bin/brokk-update.sh` is her old name,
kept as an alias.

**Eir** is the goddess of healing, counted the best of physicians — she who
mends and spares. In Ymir she is the **doctor**: she composes every surface that
owns its own health (the `*-ensure.sh` tools, the memory well, the MCP wiring,
the session lock, the migrations), tells the Allfather plainly which are whole
and which are broken, and — on `fix` — mends what can be mended safely. Gróa
keeps the tree *current*; Eir makes it *work*. She lives in `bin/eir-doctor.sh`.

Where **Gleipnir** binds one session to the reins and **Sýn** keeps the watch,
Gróa and Eir keep the machine itself alive between those sessions: the one
renewing, the other healing.

*The völva renews the tree; the healer mends what breaks under it.*

## XXXI. The Weaving of the Halls

Three halls stood apart — the high seat, the smithy, the seat by the fire —
each wearing its own cloth, none sharing the stone and the bronze. Then the
weave was thrown across them at once, and the halls became one look: the
panels of the seat, the tokens of the smithy, the cuts of the high seat all
read the same tokens, and the blue that had marked foreign text was struck
from them. The default of the smithy was named **Fensalir**, the weaving
halls themselves, and the old overrides still won when a user willed them.

And because the saga must be seen, not only read, the **Óðrerir** was raised
on the landing — the cauldron of the mead of poetry, poured live: a deck
of dealt slate, a carved ledger of what is underway and what has landed and
what is charted, fed by real state from the machine. Every door in every
hall gained the rune ᛟ, To the Hall, and the landing gained its own.

The smiths themselves became a woven thing: each finished work files its
saga, the bridge wakes the forge-master, and the wake that would echo is
guarded — once drained, it is not re-told. The realm took its name, the
hoard was mapped, and the day's whole weave was folded into main and pushed
to the world's door.

*The halls share one cloth; the mead pours; the rune points home; the saga
files itself.*
