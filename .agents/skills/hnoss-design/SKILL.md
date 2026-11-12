---
name: hnoss
description: >-
  Hnoss — the design smithy. Produce brand-grade design artifacts with the
  OpenDesign engine (nexu-io/open-design): web/desktop/mobile prototypes,
  landing pages, live dashboards, decks, images, and motion video — rendered
  from a DESIGN.md design system and exported to HTML/PDF/PPTX/MP4. Use when the
  task is design: UI/UX, visual assets, decks, dashboards, or motion. Keywords —
  design, prototype, landing page, dashboard, deck, slides, DESIGN.md,
  opendesign, od, figma.
argument-hint: "[prototype | deck | dashboard | image | video | design-system | install]"
---

# hnoss-design — design — artifacts via OpenDesign (prototypes, decks, dashboards, image, video)

> **Norse name:** **Hnoss** (beauty, treasure). The design craft's figure.

Hnoss is how Ymir makes **design artifacts**. The engine is **OpenDesign**
(`github.com/nexu-io/open-design`, Apache-2.0) — the open-source Claude Design
alternative: local-first, agent-native, BYOK. Ymir adopts the engine (open-source
first); this skill is the Norse shell the **design Eindri** works through. The
`DESIGN.md` is the brand contract; the coding agent is the design engine.

## 1. The engine (open-source first)

- **What it is:** a filesystem of functional **skills**, rendering **design
  templates**, and **design systems** — your coding agent reads/writes/remixes
  them. Output is real HTML/CSS, exported to **HTML · PDF · PPTX · MP4**.
- **Install into a harness:**
  ```sh
  od mcp install <agent>        # opencode | pi | hermes | codex | cursor | claude | copilot | …
  curl -fsSL https://open-design.ai/install.sh | sh -s <agent>   # hosted wrapper
  ```
- **MCP + CLI:** OpenDesign exposes a stdio **MCP server**; the `od` CLI reads the
  **live** project files (never a stale export):
  ```sh
  od project list --json
  od files list <project-id> --json
  od files read <project-id> <relative-path>
  od plugin list --json
  od skills list --json
  ```
- **Brand contract:** every render reads the active `DESIGN.md`; 151 design
  systems ship. Drop a `DESIGN.md` in and the picker finds it.

## 2. The craft (the loop)

```
design_loop[6]{step,what}:
  "brief","the ask — artifact type, audience, constraints"
  "direction","lock the visual direction (the brand's DESIGN.md, or pick one)"
  "system","bind the design system — tokens, type, color (DESIGN.md)"
  "artifact","generate the real files — prototype / deck / dashboard / image / video"
  "critique","read it, refine in place; export HTML/PDF/PPTX/MP4"
  "handoff","real HTML/CSS → the builder turns it into components"
```

## 3. Artifact types

web · desktop · mobile **prototypes** · live **dashboards/artifacts** ·
**decks** (HTML/PDF/PPTX) · **images** · **video / HyperFrames** (HTML + CSS +
GSAP → deterministic MP4).

## 4. Rules

1. **Brand first.** A design without a `DESIGN.md` is drift — codify the system
   before generating.
2. **Real files, real export.** Deliver runnable HTML/CSS and the exported asset
   (PDF/PPTX/MP4), never a screenshot.
3. **OSS, BYOK.** Use the OpenDesign engine; keys come from `.env.local`
   (`OD_API_TOKEN` and provider keys) — **never inline**.
4. **Engineering handoff.** Design output is code: the builder (**Sindri**) takes
   it from there; Hnoss does not implement product code.
5. **The design Eindri is domain `utgard`** (creative) or `dvalin` (crafted
   tools), per Rule 01 — and uses this skill.

## 5. Install into Ymir

```sh
od mcp install opencode        # bind the engine to OpenCode
od mcp install pi              # and to Pi
bin/seat/valknut-load.sh --all      # rebind agents/skills after adding this skill
```

**This seat (heimdall, 2026-09-24):** the daemon is a Docker container on
loopback `:7456`, the bridge is `open-design-mcp` wired into pi via
`~/.local/bin/hnoss-mcp-launch.sh`, and design generation proxies through our
own llama-swap rail. **Seating the Allfather:** the daemon is loopback-only
and single-tenant, so `OPEN_DESIGN_DISABLE_API_AUTH=1` in
`~/opendesign/deploy/.env` — no sign-in box; `http://127.0.0.1:7456` opens
straight to the Studio —** and `agentId` must be `pi` (the CLI whose registry is
the Allfather's 54 models at llama-swap), NEVER a cloud model name.
Full runbook: `DESIGN.md` → `RUNTIME ADDENDUM` + `The model truth`. Full runbook: `DESIGN.md` → `RUNTIME`.

## 2026-11-10 — the model door (correcting the seat note in §5)

§5 above says design generation "proxies through our own llama-swap rail". That was the
belief, and it was wrong on this seat: the Allfather's provider is
`opencode-go/deepseek-v4.1-flash`, the launcher could not resolve a provider that is built
into pi rather than named in `models.json`, and it silently fell back to the rail — a door
and a model that cannot answer each other. Every generation died with nothing to show.

**The road, and it is shipped now:**

- **`bin/pi/hnoss-mcp-launch.sh`** is the launcher (no longer a hand-file in
  `~/.local/bin`). It takes the provider, the model and the credential from pi, then
  picks the door: a `models.json` rail directly; a provider built **into** pi through
  **Bifrost** (`bin/bridge/bifrost-bridge.sh`), which adds the `x-opencode-session` header
  the gateway demands and the BYOK client cannot send; anything else → a refusal naming
  the provider, never a quiet substitution.
- **`bin/pi/hnoss-ensure.sh status|ensure`** seats and checks the whole door: the
  launcher, the `hnoss` pi MCP entry, the compatibility shim, and the resolved model.
  Install runs it (`step_hnoss`), every update mends it (Gróa), Eir reports it.
- **`bin/pi/open-design.sh start|stop`** is the Studio (container, loopback `:7456`). It
  now passes the deployment's `.env` to Compose — without that, Compose read the caller's
  directory, ignored the `.env`, and the image's 192 MB Node heap killed every real page
  (`FATAL ERROR: Ineffective mark-compacts near heap limit`, reported to the client as
  "OD daemon unreachable"). This seat's `.env` carries `NODE_OPTIONS=--max-old-space-size=1024`.

**What still holds from §5:** the daemon's `agentId` is `pi` for the *Studio's own*
composer, and that path is separate. The MCP path — `od_generate_design` — is BYOK only
and never touches an agent; it goes daemon-proxy → launcher's door → provider. Two roads,
one brain: pi's provider decides both.

**Proof on this seat, 2026-11-10:** a real generation through the MCP returned HTML
("Blackwater Forge — Hero"), and `state/model-bridge-4613.log` names it —
`model=deepseek-v4.1-flash provider=opencode-go` on a `200`. Runbook and the four things
that can break: `DESIGN.md` → *THE MODEL DOOR (2026-11-10)*.
