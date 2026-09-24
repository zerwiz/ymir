## DESIGN SYSTEM

**Brand:** The house of Ymir — stone and bone, bronze and blood

**Palette:** stone `#0e0c09` · panel `#151209` · bronze `#c9973f` · line `#2b241a` ·
bone text `#cfc3a9` · steel `#96a0a8` · blood-lit `#c2584a` — the canonical
cloth (`midgard/design-system/tokens.css`, docs/design.md §4)

**Typography:** Cormorant (display/headings) · Newsreader (body) · IBM Plex Mono (data)

**Posture:** carved, not skinned — quiet stone, thin steel hairlines, faint
bronze washes, beveled panels, tinted buttons, no glass, no gradients-as-glow

**Rules:** a colour is never written at a call site (consume `--ymir-*` tokens);
selection amber `#57411a` on pale bone `#f0e6cd`; focus = chisel ring

**Export targets:** HTML, PDF, PPTX, MP4

## RUNTIME — the engine (installed 2026-09-24)

| piece | where |
|---|---|
| daemon | Docker `open-design` (ghcr.io/nexu-io/od:latest), loopback `:7456`, token-gated |
| MCP bridge | `open-design-mcp` (npm, global) — 10 `od_*` tools |
| pi register | `~/.pi/agent/mcp.json` → `hnoss-mcp-launch.sh` |
| launcher | `~/.local/bin/hnoss-mcp-launch.sh` — resolves `OD_API_TOKEN` + the model-rail key at launch |
| model rail | BYOK = llama-swap `127.0.0.1:8080/v1` (`qwen3.6-35b-a3b@iq3_s`) |

**Seating the Allfather in the web app:** the daemon is loopback-only and
single-tenant, so auth is **disabled** (`OPEN_DESIGN_DISABLE_API_AUTH=1` in
`~/opendesign/deploy/.env` — the engine's own blessed escape hatch for a
trusted loopback deployment). Open `http://127.0.0.1:7456` and the Studio is
there, no sign-in box. Do NOT re-enable the token gate for a browser login:
the Allfather asked to be carried through untouched, and loopback needs no
document. The `OD_API_TOKEN` still sits in the deploy `.env` (Secrets by
reference, never in a repo) and the MCP bridge still sends it as Bearer —
with auth off the daemon simply does not enforce it.

If a later seat wants the door gated again (public/LAN exposure), flip
`OPEN_DESIGN_DISABLE_API_AUTH=` to empty and the native sign-in returns:
username `open-design`, password `OD_API_TOKEN`.

**Status:** Installed and breathing — daemon `healthy` (no auth on loopback),
10 tools verified on stdio.

## RUNTIME ADDENDUM — 2026-09-24 · the Allfather seated, no login (the two doors)

The web app has TWO gates. Disabling the daemon's Basic token
(`OPEN_DESIGN_DISABLE_API_AUTH=1`) only kills the first. The second is the
frontend's **model-provider chooser** ("Sign in / Sign up · Free Credits · Or
use your own AI · Local AI · API Key"). To seat the Allfather past BOTH with
HIS providers and models:

1. **Mount his agents into the daemon** — the chooser's "Local AI" reads the
   daemon's runtime registry (`/api/agents`); if no CLI is inside the
   container, every agent reports `available:false` and the gate holds. The
   recipe lives in `~/opendesign/deploy/docker-compose.allfather.yml` +
   `Dockerfile.local` (image `od:local` = base + `libc6-compat`):
   - the **opencode** binary mounted as `/home/open-design/.opencode/bin/opencode-cli`
     (the daemon scans for bin `opencode-cli`) with his `~/.config/opencode`
     and `~/.local/share/opencode`, so HIS providers/models ride in
   - **pi**'s node bin + `~/.pi` mounted read-only (his 54-model registry)
   - container PATH must keep its OWN `node` first — mounting the host's
     glibc `node` on PATH crashes the daemon with `libatomic.so.1` /
     `fcntl64: symbol not found`; do NOT mount `/lib/x86_64-linux-gnu` or
     `/lib64` (they break Alpine's musl loader). Stop with
     `docker compose -f docker-compose.yml -f docker-compose.allfather.yml up -d`
2. **Seed the daemon** so the chooser never opens — `PUT /api/app-config`:
   `{"onboardingCompleted":true,"agentId":"opencode","agentModels":{"opencode":{"model":"anthropic/claude-sonnet-4-5"}},"designSystemId":"default","skillId":"design"}`.
   The daemon persists it to `/app/.od/app-config.json`.
3. **Verify live** (not curl — the Next.js app is heavy; read the DOM after
   ~16 s via CDP): the Home paints "Let's create · Prototype", the composer
   shows model `anthropic/claude-sonnet-4-5` in Local mode, and the only
   remaining "Sign in" is the optional Cloud pill — never a door.

The MCP bridge (`hnoss-mcp-launch.sh`) resolves OD/rail keys from the pi
registry at launch; the web app needs none (auth disabled on loopback).

**Status:** Installed and breathing — daemon healthy, 10 MCP tools live, web
Studio in Local mode with opencode, no login.

### The model truth — "why is it claude? where are my models?"

OpenDesign's Settings model gallery (%the daemon's `/api/agents` `models` array)
is a **curated fallback list** (claude/gpt/gemini catalogs). It is NOT the
Allfather's registry. Two traps + the truth:

- **Trap 1 (mine):** seeding `agentModels: {agent: {model: "anthropic/claude-sonnet-4-5"}}`
  made the composer show claude. That was wrong — never seed a cloud model.
- **Trap 2 (OpenDesign):** a local CLI agent's *fallback* model list is its
  built-in catalog, so the gallery shows cloud names even when the CLI would
  use local ones.
- **The truth:** the daemon's agents include **`pi`** (`/api/agents`, id `pi`,
  bin `pi`) — and pi reads `~/.pi/agent/settings.json` + `models.json` at run.
  Its model `default` = *"Default (CLI config)"* = the Allfather's
  `defaultProvider: llama-swap` + `defaultModel: qwen3.6-35b-a3b@q4_k_xl-mtp`.
  pi's registry (54 models) is mounted into the container read-only, so a real
  generation runs on HIS rail at `127.0.0.1:8080/v1` — never claude.

**Seating fix (done 2026-09-24):** `PUT /api/app-config` →
`{"onboardingCompleted":true,"agentId":"pi","agentModels":{"pi":{}},
"designSystemId":"default","skillId":"design"}` — agent pi, model empty
(best value for `default`), so pi's own config decides. `opencode` is also
available (mounted as `opencode-cli`) if a different CLI is wanted; never
seed a named cloud model into `agentModels`.
